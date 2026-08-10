//
//  NotchViewModel.swift
//  FlowIsland
//

import Combine
import SwiftUI

enum NotchState: Equatable {
    case closed
    case expanded
}

// 集中管理悬停反馈、延迟展开和任务取消，View 只负责展示状态。
@MainActor
final class NotchViewModel: ObservableObject {
    @Published private(set) var isHovering = false
    @Published private(set) var notchState: NotchState = .closed

    private var pendingExpansion: Task<Void, Never>?

    func handleHover(_ pointerIsInside: Bool) {
        withAnimation(.easeOut(duration: 0.15)) {
            isHovering = pointerIsInside
        }

        // 光标状态改变后，旧的延迟任务已经失效。
        cancelPendingExpansion()

        if pointerIsInside {
            pendingExpansion = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(
                        for: .milliseconds(500)
                    )
                } catch {
                    // 光标提前移出会取消 Task；取消不是需要上报的错误。
                    return
                }

                guard let self else {
                    return
                }

                withAnimation(
                    .spring(
                        response: 0.45,
                        dampingFraction: 0.72
                    )
                ) {
                    self.notchState = .expanded
                }

                self.pendingExpansion = nil
            }
        } else {
            withAnimation(
                .spring(
                    response: 0.45,
                    dampingFraction: 0.72
                )
            ) {
                notchState = .closed
            }
        }
    }

    func cancelPendingExpansion() {
        pendingExpansion?.cancel()
        pendingExpansion = nil
    }
}
