import SwiftUI

struct ContentView: View {
    let closedSize: CGSize

    // 展开交互和媒体数据分别管理，避免一个 ViewModel 承担两种职责。
    @StateObject private var notchViewModel = NotchViewModel()
    @StateObject private var mediaViewModel = MediaViewModel()

    private var isExpanded: Bool {
        notchViewModel.notchState == .expanded
    }
    
    private let topCornerRadius: CGFloat = 6

    private var bottomCornerRadius: CGFloat {
        switch notchViewModel.notchState {
        case .closed:
            14
        case .expanded:
            26
        }
    }

    // 收起时贴合物理刘海，展开时切换到媒体面板尺寸。
    private var currentNotchSize: CGSize {
        switch notchViewModel.notchState {
        case .closed:
            CGSize(
                width: closedSize.width + topCornerRadius * 2,
                height: closedSize.height
            )
        case .expanded:
            CGSize(
                width: 580,
                height: 200
            )
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            VStack(spacing: 0) {
                if isExpanded {
                    ExpandedContentView(
                        mediaInfo: mediaViewModel.currentMedia,
                        onPreviousTrack: {
                            mediaViewModel.previousTrack()
                        },
                        onTogglePlayback: {
                            mediaViewModel.togglePlayback()
                        },
                        onNextTrack: {
                            mediaViewModel.nextTrack()
                        },
                        onSeek: { time in
                            mediaViewModel.seek(to: time)
                        }
                    )
                }
            }
            .foregroundStyle(.white)
            .frame(
                width: currentNotchSize.width,
                height: currentNotchSize.height
            )
            .background(.black)
            .clipShape(
                NotchShape(
                    topCornerRadius: topCornerRadius,
                    bottomCornerRadius: bottomCornerRadius
                )
            )
            .shadow(
                color: notchViewModel.isHovering
                    ? Color.black.opacity(0.55)
                    : Color.clear,
                radius: notchViewModel.isHovering ? 12 : 0
            )
            .onHover { pointerIsInside in
                notchViewModel.handleHover(pointerIsInside)
            }
            .onAppear {
                mediaViewModel.startMonitoring()
            }
            .onDisappear {
                notchViewModel.cancelPendingExpansion()
                mediaViewModel.stopMonitoring()
            }
        }
        .frame(width: 640, height: 240)
    }
}

#Preview {
    ContentView(
        closedSize: CGSize(
            width: 179,
            height: 32
        )
    )
}
