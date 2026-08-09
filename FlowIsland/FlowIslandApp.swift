import AppKit
import SwiftUI

// @main 表示程序从这里启动。
@main
struct FlowIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
    
    // App 的 body 描述这个应用包含哪些场景（Scene）。
    var body: some Scene {
        MenuBarExtra(
            "FlowIsland",
            systemImage: "sparkles"
        ) {
            // 菜单顶部的状态提示。
            Text("FlowIsland 正在运行")

            Divider()

            // terminate 会结束整个应用，而不只是关闭某个窗口。
            Button("退出 FlowIsland", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        // 使用传统的下拉菜单，而不是自定义弹出窗口。
        .menuBarExtraStyle(.menu)
    }
}
