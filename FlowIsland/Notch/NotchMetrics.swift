//
//  NotchMetrics.swift
//  FlowIsland
//
//  Created by Awstme on 2026/8/9.
//

import AppKit

enum NotchMetricsError: LocalizedError {
    case auxiliaryAreasUnavailable
    case invalidSize(width: CGFloat, height: CGFloat)

    var errorDescription: String? {
        switch self {
        case .auxiliaryAreasUnavailable:
            "屏幕没有提供刘海两侧的辅助区域"
        case let .invalidSize(width, height):
            "计算出的刘海尺寸无效（width: \(width), height: \(height)）"
        }
    }
}

struct NotchMetrics {
    // 收起状态严格使用屏幕报告的物理刘海尺寸。
    let closedSize: CGSize

    init(screen: NSScreen) throws {
        guard
            let leftArea = screen.auxiliaryTopLeftArea,
            let rightArea = screen.auxiliaryTopRightArea
        else {
            throw NotchMetricsError.auxiliaryAreasUnavailable
        }

        let width =
            rightArea.minX - leftArea.maxX

        let height =
            screen.safeAreaInsets.top

        guard width > 0, height > 0 else {
            throw NotchMetricsError.invalidSize(
                width: width,
                height: height
            )
        }

        closedSize = CGSize(
            width: width,
            height: height
        )

        #if DEBUG
        Self.printDebugInfo(
            for: screen,
            closedSize: closedSize
        )
        #endif
    }
}

#if DEBUG
private extension NotchMetrics {
    static func printDebugInfo(
        for screen: NSScreen,
        closedSize: CGSize
    ) {
        print("========== 屏幕信息 ==========")
        print("名称：", screen.localizedName)
        print("完整区域 frame：", screen.frame)
        print("可见区域 visibleFrame：", screen.visibleFrame)
        print("安全区 safeAreaInsets：", screen.safeAreaInsets)
        print(
            "左侧辅助区域：",
            String(describing: screen.auxiliaryTopLeftArea)
        )
        print(
            "右侧辅助区域：",
            String(describing: screen.auxiliaryTopRightArea)
        )
        print("检测到的物理刘海尺寸：", closedSize)
    }
}
#endif
