import SwiftUI


struct ContentView: View {
    // 从外部传入的物理刘海尺寸。
    let closedSize: CGSize
    
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var pendingExpansion: Task<Void, Never>?
    
    private let topCornerRadius: CGFloat = 6
    private var bottomCornerRadius: CGFloat {
        isExpanded ? 26 : 14
    }
    private var currentNotchWidth: CGFloat {
        isExpanded
            ? 580
            : closedSize.width + topCornerRadius * 2
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // 固定大小的浅灰色练习画布。
            Color.clear

            VStack(spacing: 12) {
                Text("FlowIsland")
                    .font(.headline)

                if isExpanded {
                    Text("这里是展开后的内容")
                }

            }
            .foregroundStyle(.white)
            .frame(
                width: currentNotchWidth,
                height: isExpanded
                    ? 200
                    : closedSize.height
            )
            .background(.black)
            .clipShape(
                NotchShape(
                        topCornerRadius: topCornerRadius,
                        bottomCornerRadius: bottomCornerRadius
                )
            )            .shadow(
                color: isHovering
                    ? Color.black.opacity(0.55)
                    : Color.clear,
                radius: isHovering ? 12 : 0
            )
            .onHover { pointerIsInside in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovering = pointerIsInside
                }
                
                // 每次收到新的 hover 状态，先取消旧任务。
                pendingExpansion?.cancel()
                pendingExpansion = nil

                if pointerIsInside {
                    // 鼠标进入后，创建一个等待展开的任务。
                    pendingExpansion = Task { @MainActor in
                        do {
                            try await Task.sleep(
                                for: .milliseconds(500)
                            )
                        } catch {
                            // 等待期间任务被取消，不再展开。
                            return
                        }

                        withAnimation(
                            .spring(
                                response: 0.45,
                                dampingFraction: 0.72
                            )
                        ) {
                            isExpanded = true
                        }
                    }
                } else {
                    // 鼠标离开时立即收起。
                    withAnimation(
                        .spring(
                            response: 0.45,
                            dampingFraction: 0.72
                        )
                    ) {
                        isExpanded = false
                    }
                }
            }
            .onDisappear {
                pendingExpansion?.cancel()
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
