//
//  AppDelegate.swift
//  FlowIsland
//
//  Created by Awstme on 2026/8/9.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        let panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 640,
                height: 240
            ),
            styleMask: [
                .borderless,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )

        guard let screen = NSScreen.main
            ?? NSScreen.screens.first
        else {
            return
        }
        guard let metrics = NotchMetrics(
            screen: screen
        ) else {
            print("当前屏幕没有可用的物理刘海")
            return
        }

        print(
            "检测到的物理刘海尺寸：",
            metrics.closedSize
        )
        
        let hostingView = NSHostingView(
            rootView: ContentView(
                closedSize: metrics.closedSize
            )
        )

        panel.contentView = hostingView
        // 窗口本身允许透明。
        panel.isOpaque = false
        panel.backgroundColor = .clear

        // 关闭 AppKit 针对整个矩形窗口绘制的系统阴影。
        panel.hasShadow = false

        // 切换到其他应用时仍然显示。
        panel.hidesOnDeactivate = false

        // 显示在普通应用窗口之上。
        panel.level = .statusBar

        let screenFrame = screen.frame
        let panelSize = panel.frame.size

        let panelOrigin = NSPoint(
            x: screenFrame.midX - panelSize.width / 2,
            y: screenFrame.maxY - panelSize.height
        )

        panel.setFrameOrigin(panelOrigin)
        panel.orderFrontRegardless()

        self.panel = panel
    }
}
