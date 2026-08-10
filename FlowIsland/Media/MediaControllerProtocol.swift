//
//  MediaControllerProtocol.swift
//  FlowIsland
//

import Combine
import Foundation

// 抽象媒体来源，使 ViewModel 不依赖 MediaRemote 或某个具体播放器。
protocol MediaControllerProtocol: AnyObject {
    // 类型擦除后，调用方无需知道 Controller 内部使用哪种 Publisher。
    var mediaInfoPublisher: AnyPublisher<MediaInfo?, Never> {
        get
    }

    func startMonitoring()
    func stopMonitoring()

    func previousTrack()
    func togglePlayback()
    func nextTrack()

    func seek(to time: TimeInterval)
}
