import AppKit
import SwiftUI

@main
struct FlowIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate
    
    var body: some Scene {
        MenuBarExtra(
            "FlowIsland",
            systemImage: "sparkles"
        ) {
            Text("FlowIsland 正在运行")

            Divider()

            // NSApplication.terminate 会结束应用，而不只是关闭某个窗口。
            Button("退出 FlowIsland", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        // 使用系统原生下拉菜单，而不是自定义弹出窗口。
        .menuBarExtraStyle(.menu)
    }
}
