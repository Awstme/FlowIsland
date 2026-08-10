//
//  ExpandedContentView.swift
//  FlowIsland
//

import AppKit
import SwiftUI

// 展开态只负责展示媒体数据，并通过闭包把用户操作交给外部处理。
struct ExpandedContentView: View {
    let mediaInfo: MediaInfo?

    let onPreviousTrack: () -> Void
    let onTogglePlayback: () -> Void
    let onNextTrack: () -> Void
    let onSeek: (TimeInterval) -> Void

    // 系统不会连续推送播放进度，因此滑块需要保存并更新本地显示值。
    @State private var sliderValue: TimeInterval = 0
    @State private var isDraggingProgress = false
    @State private var lastDragged = Date.distantPast

    var body: some View {
        HStack(spacing: 20) {
            albumArtwork

            VStack(alignment: .leading, spacing: 10) {
                if let mediaInfo {
                    Text(mediaInfo.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(mediaInfo.artist)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                } else {
                    Text("暂无播放内容")
                        .font(.headline)

                    Text("请先在播放器中播放一首歌曲")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer(minLength: 0)

                progressArea

                HStack(spacing: 22) {
                    controlButton(
                        systemName: "backward.fill",
                        diameter: 30,
                        action: onPreviousTrack
                    )

                    controlButton(
                        systemName: mediaInfo?.isPlaying == true
                            ? "pause.fill"
                            : "play.fill",
                        diameter: 40,
                        action: onTogglePlayback
                    )

                    controlButton(
                        systemName: "forward.fill",
                        diameter: 30,
                        action: onNextTrack
                    )
                }
                .frame(maxWidth: .infinity)
                .disabled(mediaInfo == nil)
                .opacity(mediaInfo == nil ? 0.4 : 1)
            }
        }
        .padding(30)
    }

    private var albumArtwork: some View {
        Group {
            if
                let artworkData = mediaInfo?.artworkData,
                let image = NSImage(data: artworkData)
            {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                albumArtworkPlaceholder
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }

    private var albumArtworkPlaceholder: some View {
        RoundedRectangle(
            cornerRadius: 14,
            style: .continuous
        )
        .fill(.white.opacity(0.12))
        .overlay {
            Image(systemName: "music.note")
                .font(.title)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    @ViewBuilder
    private var progressArea: some View {
        if let mediaInfo, mediaInfo.duration > 0 {
            TimelineView(
                .animation(
                    minimumInterval: mediaInfo.playbackRate > 0 ? 0.1 : nil
                )
            ) { context in
                MediaSliderView(
                    sliderValue: $sliderValue,
                    duration: mediaInfo.duration,
                    lastDragged: $lastDragged,
                    isDragging: $isDraggingProgress,
                    currentDate: context.date,
                    timestampDate: mediaInfo.lastUpdated,
                    elapsedTime: mediaInfo.elapsedTime,
                    playbackRate: mediaInfo.playbackRate,
                    isPlaying: mediaInfo.isPlaying,
                    onValueChange: onSeek
                )
            }
        } else {
            VStack(spacing: 3) {
                ProgressView(value: 0, total: 1)
                    .progressViewStyle(.linear)
                    .tint(.white.opacity(0.3))

                HStack {
                    Text("--:--")
                    Spacer()
                    Text("--:--")
                }
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private func controlButton(
        systemName: String,
        diameter: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(diameter > 32 ? .title3 : .body)
                .frame(width: diameter, height: diameter)
                .background(.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
    }

}

#Preview {
    ExpandedContentView(
        mediaInfo: MediaInfo(
            title: "示例歌曲",
            artist: "示例歌手",
            isPlaying: true,
            duration: 245,
            elapsedTime: 82,
            playbackRate: 1
        ),
        onPreviousTrack: {},
        onTogglePlayback: {},
        onNextTrack: {},
        onSeek: { _ in }
    )
        .frame(width: 580, height: 200)
        .background(.black)
        .foregroundStyle(.white)
}

// 根据系统提供的时间锚点估算当前播放位置，拖动时则保留用户输入。
private struct MediaSliderView: View {
    @Binding var sliderValue: TimeInterval
    let duration: TimeInterval
    @Binding var lastDragged: Date
    @Binding var isDragging: Bool
    let currentDate: Date
    let timestampDate: Date
    let elapsedTime: TimeInterval
    let playbackRate: Double
    let isPlaying: Bool
    let onValueChange: (TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 3) {
            MediaProgressSlider(
                value: $sliderValue,
                duration: duration,
                lastDragged: $lastDragged,
                isDragging: $isDragging,
                onValueChange: onValueChange
            )

            HStack {
                Text(formattedTime(sliderValue))
                Spacer()
                Text(formattedTime(duration))
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.5))
        }
        .onAppear {
            synchronizeSlider(at: currentDate)
        }
        .onChange(of: currentDate) { _, newDate in
            synchronizeSlider(at: newDate)
        }
    }

    private func synchronizeSlider(at date: Date) {
        // 拒绝拖动中的同步，也拒绝时间戳明显早于最近一次拖动的数据。
        guard
            !isDragging,
            timestampDate.timeIntervalSince(lastDragged) > -1
        else {
            return
        }

        let estimatedTime: TimeInterval

        if isPlaying {
            let timeSinceUpdate = max(
                0,
                date.timeIntervalSince(timestampDate)
            )
            estimatedTime = elapsedTime
                + timeSinceUpdate * max(0, playbackRate)
        } else {
            estimatedTime = elapsedTime
        }

        sliderValue = min(max(estimatedTime, 0), duration)
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        guard time.isFinite else {
            return "0:00"
        }

        let totalSeconds = max(0, Int(time))
        let hours = totalSeconds / 3600
        let minutes = totalSeconds % 3600 / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

// 拖动过程只更新本地外观，松手后才向播放器发送一次 seek。
private struct MediaProgressSlider: View {
    @Binding var value: TimeInterval
    let duration: TimeInterval
    @Binding var lastDragged: Date
    @Binding var isDragging: Bool
    let onValueChange: (TimeInterval) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let progress = duration > 0
                ? min(max(value / duration, 0), 1)
                : 0
            let trackHeight: CGFloat = isDragging ? 8 : 5

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.2))
                    .frame(height: trackHeight)

                Rectangle()
                    .fill(.white)
                    .frame(
                        width: width * progress,
                        height: trackHeight
                    )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: trackHeight / 2,
                    style: .continuous
                )
            )
            .frame(height: 10)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            withAnimation(
                                .spring(
                                    response: 0.35,
                                    dampingFraction: 0.7
                                )
                            ) {
                                isDragging = true
                            }
                        }

                        let ratio = min(
                            max(gesture.location.x / width, 0),
                            1
                        )
                        value = duration * ratio
                    }
                    .onEnded { _ in
                        // value 已在拖动过程中更新，松手时无需再次计算坐标。
                        onValueChange(value)
                        withAnimation(
                            .spring(
                                response: 0.35,
                                dampingFraction: 0.7
                            )
                        ) {
                            isDragging = false
                        }
                        lastDragged = Date()
                    }
            )
        }
        .frame(height: 10)
    }
}
