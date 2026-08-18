//
//  NowPlayingController.swift
//  FlowIsland
//

import Combine
import Foundation
import OSLog

private let nowPlayingLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "FlowIsland",
    category: "NowPlaying"
)

// 通过 MediaRemote 读取系统级 Now Playing；只能观察主动上报状态的播放器。
final class NowPlayingController: MediaControllerProtocol {
    // 状态保持私有，只通过类型擦除后的 Publisher 对外发布。
    @Published private var mediaInfo: MediaInfo? = nil

    var mediaInfoPublisher: AnyPublisher<MediaInfo?, Never> {
        $mediaInfo.eraseToAnyPublisher()
    }

    private var process: Process?
    private var pipeHandler: JSONLinesPipeHandler?
    private var streamTask: Task<Void, Never>?

    private typealias SendCommandFunction = @convention(c) (Int, AnyObject?) -> Void
    private typealias SetElapsedTimeFunction = @convention(c) (Double) -> Void

    private enum MediaRemoteCommand: Int {
        case togglePlayback = 2
        case nextTrack = 4
        case previousTrack = 5
    }

    private var mediaRemoteBundle: CFBundle?
    private var sendCommand: SendCommandFunction?
    private var setElapsedTime: SetElapsedTimeFunction?
    private let timestampFormatter = ISO8601DateFormatter()
    private var pendingSeek: PendingSeek?

    init() {
        loadPlaybackControl()
    }

    func startMonitoring() {
        // View 可能反复出现；同一时间只允许一个监听进程。
        guard streamTask == nil else {
            return
        }

        streamTask = Task { [weak self] in
            await self?.runAdapterStream()
        }
    }

    func stopMonitoring() {
        streamTask?.cancel()
        streamTask = nil

        // 子进程结束后管道收到 EOF，读取任务会自然退出。
        if process?.isRunning == true {
            process?.terminate()
        }

        process = nil
        pipeHandler = nil
        pendingSeek = nil
        mediaInfo = nil
    }

    func togglePlayback() {
        send(.togglePlayback)
    }

    func previousTrack() {
        send(.previousTrack)
    }

    func nextTrack() {
        send(.nextTrack)
    }

    private func send(_ command: MediaRemoteCommand) {
        sendCommand?(command.rawValue, nil)
    }

    func seek(to time: TimeInterval) {
        guard let setElapsedTime else {
            return
        }

        let targetTime: TimeInterval

        if let mediaInfo, mediaInfo.duration > 0 {
            targetTime = min(max(time, 0), mediaInfo.duration)
        } else {
            targetTime = max(time, 0)
        }

        let requestedAt = Date()

        if let mediaInfo {
            // 乐观更新 UI，并等待能确认 seek 已生效的新系统状态。
            // 这样可避免 MediaRemote 迟到的旧进度让滑块短暂闪回。
            pendingSeek = PendingSeek(
                targetTime: targetTime,
                requestedAt: requestedAt,
                title: mediaInfo.title,
                wasPlaying: mediaInfo.isPlaying,
                playbackRate: mediaInfo.playbackRate
            )

            self.mediaInfo = MediaInfo(
                title: mediaInfo.title,
                artist: mediaInfo.artist,
                isPlaying: mediaInfo.isPlaying,
                artworkData: mediaInfo.artworkData,
                duration: mediaInfo.duration,
                elapsedTime: targetTime,
                playbackRate: mediaInfo.playbackRate,
                lastUpdated: requestedAt
            )
        }

        setElapsedTime(targetTime)
    }

    private func loadPlaybackControl() {
        let frameworkURL = NSURL(
            fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"
        )

        guard let bundle = CFBundleCreate(kCFAllocatorDefault, frameworkURL) else {
            nowPlayingLogger.error("无法加载系统 MediaRemote.framework")
            return
        }

        mediaRemoteBundle = bundle

        if let functionPointer = CFBundleGetFunctionPointerForName(
            bundle,
            "MRMediaRemoteSendCommand" as CFString
        ) {
            sendCommand = unsafeBitCast(
                functionPointer,
                to: SendCommandFunction.self
            )
        } else {
            nowPlayingLogger.error("找不到播放控制函数")
        }

        if let functionPointer = CFBundleGetFunctionPointerForName(
            bundle,
            "MRMediaRemoteSetElapsedTime" as CFString
        ) {
            setElapsedTime = unsafeBitCast(
                functionPointer,
                to: SetElapsedTimeFunction.self
            )
        } else {
            nowPlayingLogger.error("找不到进度跳转函数")
        }
    }

    private func runAdapterStream() async {
        guard let resources = adapterResources else {
            nowPlayingLogger.error("App Bundle 中缺少适配器脚本或框架")
            streamTask = nil
            return
        }

        let process = Process()
        let pipeHandler = JSONLinesPipeHandler()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            resources.scriptURL.path,
            resources.frameworkURL.path,
            "stream"
        ]
        process.standardOutput = await pipeHandler.getPipe()

        self.process = process
        self.pipeHandler = pipeHandler

        do {
            try process.run()
        } catch {
            nowPlayingLogger.error(
                "无法启动媒体监听：\(error.localizedDescription, privacy: .public)"
            )
            self.process = nil
            self.pipeHandler = nil
            streamTask = nil
            return
        }

        // stream 首次输出完整状态，后续只输出发生变化的字段。
        await pipeHandler.readJSONLines(as: NowPlayingUpdate.self) { [weak self] update in
            self?.apply(update)
        }

        await pipeHandler.close()

        // 防止旧读取任务结束时清理掉已经重启的新监听。
        guard self.pipeHandler === pipeHandler else {
            return
        }

        self.process = nil
        self.pipeHandler = nil
        streamTask = nil
    }

    private func apply(_ update: NowPlayingUpdate) {
        let payload = update.payload
        let isDiff = update.diff ?? false
        let previousMedia = mediaInfo
        let receivedAt = Date()

        // diff 只包含变化字段，缺失值必须从上一份快照继承。
        guard
            let title = normalized(payload.title)
                ?? (isDiff ? previousMedia?.title : nil)
        else {
            mediaInfo = nil
            return
        }

        let artist = normalized(payload.artist)
            ?? (isDiff ? previousMedia?.artist : nil)
            ?? normalized(payload.album)
            ?? "未知艺术家"

        let duration = max(
            0,
            payload.duration
                ?? (isDiff ? previousMedia?.duration ?? 0 : 0)
        )

        let isPlaying = payload.playing
            ?? (isDiff ? previousMedia?.isPlaying ?? false : false)
        let playbackRate = max(
            0,
            payload.playbackRate
                ?? (isDiff ? previousMedia?.playbackRate ?? 1 : 1)
        )

        var lastUpdated: Date

        if let timestamp = payload.timestamp,
           let date = timestampFormatter.date(from: timestamp) {
            lastUpdated = date
        } else if isDiff {
            lastUpdated = previousMedia?.lastUpdated ?? receivedAt
        } else {
            lastUpdated = receivedAt
        }

        var rawElapsedTime: TimeInterval

        if let elapsedTime = payload.elapsedTime {
            rawElapsedTime = max(0, elapsedTime)
        } else if isDiff, payload.playing == false, let previousMedia {
            // 部分暂停事件没有 elapsedTime，只能从旧时间锚点估算暂停位置。
            rawElapsedTime = previousMedia.elapsedTime(at: receivedAt)
        } else if isDiff {
            rawElapsedTime = previousMedia?.elapsedTime ?? 0
        } else {
            rawElapsedTime = 0
        }

        if let pendingSeek {
            if pendingSeek.title != title {
                // 曲目切换后，上一首的待确认 seek 已失效。
                self.pendingSeek = nil
            } else {
                let age = receivedAt.timeIntervalSince(pendingSeek.requestedAt)
                let expectedTime = pendingSeek.targetTime
                    + (pendingSeek.wasPlaying
                        ? max(0, age) * max(0, pendingSeek.playbackRate)
                        : 0)
                let timestampIsNew = lastUpdated.timeIntervalSince(
                    pendingSeek.requestedAt
                ) >= -0.25
                let elapsedMatchesSeek = payload.elapsedTime.map {
                    abs($0 - expectedTime) < 1
                } ?? false

                if age < 2, !(timestampIsNew && elapsedMatchesSeek) {
                    // 保护期内忽略无法确认的新进度，继续使用本地时间锚点。
                    rawElapsedTime = expectedTime
                    lastUpdated = receivedAt
                } else {
                    self.pendingSeek = nil
                }
            }
        }

        if
            isPlaying == false,
            previousMedia?.isPlaying == true,
            let previousMedia
        {
            // 暂停时保留本地估算位置，避免播放器上报的滞后值造成小幅回退。
            rawElapsedTime = max(
                rawElapsedTime,
                previousMedia.elapsedTime(at: receivedAt)
            )
            lastUpdated = receivedAt
        }

        let elapsedTime = duration > 0
            ? min(rawElapsedTime, duration)
            : rawElapsedTime

        let artworkData: Data?

        if let encodedArtwork = payload.artworkData {
            artworkData = decodedArtwork(from: encodedArtwork)
        } else if isDiff {
            artworkData = previousMedia?.artworkData
        } else {
            artworkData = nil
        }

        mediaInfo = MediaInfo(
            title: title,
            artist: artist,
            isPlaying: isPlaying,
            artworkData: artworkData,
            duration: duration,
            elapsedTime: elapsedTime,
            playbackRate: playbackRate,
            lastUpdated: lastUpdated
        )
    }

    private func decodedArtwork(from encodedArtwork: String) -> Data? {
        Data(
            base64Encoded: encodedArtwork.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        )
    }

    private func normalized(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? nil : trimmedText
    }

    private var adapterResources: AdapterResources? {
        guard
            let scriptURL = Bundle.main.url(
                forResource: "mediaremote-adapter",
                withExtension: "pl"
            ),
            let frameworksPath = Bundle.main.privateFrameworksPath
        else {
            return nil
        }

        let frameworkURL = URL(fileURLWithPath: frameworksPath)
            .appendingPathComponent("MediaRemoteAdapter.framework")

        guard FileManager.default.fileExists(atPath: frameworkURL.path) else {
            return nil
        }

        return AdapterResources(
            scriptURL: scriptURL,
            frameworkURL: frameworkURL
        )
    }
}

private nonisolated struct AdapterResources {
    let scriptURL: URL
    let frameworkURL: URL
}

private struct PendingSeek {
    let targetTime: TimeInterval
    let requestedAt: Date
    let title: String
    let wasPlaying: Bool
    let playbackRate: Double
}

// 适配器用 diff 标记增量状态，payload 中的字段因此都可能缺失。
private nonisolated struct NowPlayingUpdate: Decodable, Sendable {
    let payload: NowPlayingPayload
    let diff: Bool?
}

private nonisolated struct NowPlayingPayload: Decodable, Sendable {
    let title: String?
    let artist: String?
    let album: String?
    let playing: Bool?
    let artworkData: String?
    let duration: Double?
    let elapsedTime: Double?
    let playbackRate: Double?
    let timestamp: String?
}

// actor 串行处理子进程的 JSON Lines 输出，避免并发修改 buffer。
private actor JSONLinesPipeHandler {
    private let pipe = Pipe()
    private var buffer = ""

    func getPipe() -> Pipe {
        pipe
    }

    func readJSONLines<T: Decodable & Sendable>(
        as type: T.Type,
        onLine: @Sendable @escaping (T) async -> Void
    ) async {
        let fileHandle = pipe.fileHandleForReading

        while !Task.isCancelled {
            let data = await readData(from: fileHandle)

            guard !data.isEmpty else {
                break
            }

            guard let chunk = String(data: data, encoding: .utf8) else {
                continue
            }

            buffer.append(chunk)

            while let newlineRange = buffer.range(of: "\n") {
                let line = String(buffer[..<newlineRange.lowerBound])
                buffer = String(buffer[newlineRange.upperBound...])

                guard
                    !line.isEmpty,
                    let lineData = line.data(using: .utf8),
                    let decodedValue = try? JSONDecoder().decode(type, from: lineData)
                else {
                    continue
                }

                await onLine(decodedValue)
            }
        }
    }

    private func readData(from fileHandle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            fileHandle.readabilityHandler = { handle in
                let data = handle.availableData
                handle.readabilityHandler = nil
                continuation.resume(returning: data)
            }
        }
    }

    func close() async {
        pipe.fileHandleForReading.readabilityHandler = nil

        do {
            try pipe.fileHandleForReading.close()
            try pipe.fileHandleForWriting.close()
        } catch {
            nowPlayingLogger.error(
                "关闭媒体管道失败：\(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
