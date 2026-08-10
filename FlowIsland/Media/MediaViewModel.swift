//
//  MediaViewModel.swift
//  FlowIsland
//

import Combine
import Foundation

// 把媒体 Controller 的事件转换为 SwiftUI 可观察状态，并转发用户操作。
@MainActor
final class MediaViewModel: ObservableObject {
    @Published private(set) var currentMedia: MediaInfo? = nil

    private let controller: any MediaControllerProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        controller: (any MediaControllerProtocol)? = nil
    ) {
        // 默认 Controller 在 MainActor 隔离的 init 内创建，避免跨线程初始化。
        let selectedController = controller ?? NowPlayingController()
        self.controller = selectedController

        selectedController.mediaInfoPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mediaInfo in
                self?.currentMedia = mediaInfo
            }
            .store(in: &cancellables)
    }

    func startMonitoring() {
        controller.startMonitoring()
    }

    func stopMonitoring() {
        controller.stopMonitoring()
    }

    func togglePlayback() {
        controller.togglePlayback()
    }

    func previousTrack() {
        controller.previousTrack()
    }

    func nextTrack() {
        controller.nextTrack()
    }

    func seek(to time: TimeInterval) {
        controller.seek(to: time)
    }
}
