//
//  NotchMetrics.swift
//  FlowIsland
//
//  Created by Awstme on 2026/8/9.
//

import AppKit

struct NotchMetrics {
    // 收起状态严格使用屏幕报告的物理刘海尺寸。
    let closedSize: CGSize

    // 无刘海屏幕不会提供左右辅助区域，因此初始化可能失败。
    init?(screen: NSScreen) {
        guard
            let leftArea = screen.auxiliaryTopLeftArea,
            let rightArea = screen.auxiliaryTopRightArea
        else {
            return nil
        }

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
        
        let width =
            rightArea.minX - leftArea.maxX

        let height =
            screen.safeAreaInsets.top

        guard width > 0, height > 0 else {
            return nil
        }

        closedSize = CGSize(
            width: width,
            height: height
        )
    }
}
