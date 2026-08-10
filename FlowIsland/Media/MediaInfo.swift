//
//  MediaInfo.swift
//  FlowIsland
//

import Foundation

// Controller 与 View 之间传递的只读媒体快照。
struct MediaInfo {
    let title: String
    let artist: String
    let isPlaying: Bool
    let artworkData: Data?
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let playbackRate: Double
    let lastUpdated: Date

    init(
        title: String,
        artist: String,
        isPlaying: Bool,
        artworkData: Data? = nil,
        duration: TimeInterval = 0,
        elapsedTime: TimeInterval = 0,
        playbackRate: Double = 0,
        lastUpdated: Date = Date()
    ) {
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
        self.artworkData = artworkData
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.playbackRate = playbackRate
        self.lastUpdated = lastUpdated
    }

    // elapsedTime 与 lastUpdated 构成时间锚点；播放期间据此估算实时位置。
    func elapsedTime(at date: Date) -> TimeInterval {
        let timeSinceUpdate = max(0, date.timeIntervalSince(lastUpdated))
        let estimatedTime = isPlaying
            ? elapsedTime + timeSinceUpdate * max(0, playbackRate)
            : elapsedTime

        let nonnegativeTime = max(0, estimatedTime)

        guard duration > 0 else {
            return nonnegativeTime
        }

        return min(nonnegativeTime, duration)
    }
}
