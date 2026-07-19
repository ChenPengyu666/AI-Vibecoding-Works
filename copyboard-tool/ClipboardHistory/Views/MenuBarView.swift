import SwiftUI

/// 菜单栏 Popover 容器 — 包裹 ContentView 作为弹出面板
struct MenuBarView: View {
    @State private var viewModel = ClipboardViewModel()

    var body: some View {
        ContentView()
            .frame(width: 380, height: 480)
            .onAppear {
                viewModel.refresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .clipboardDataChanged)) { _ in
                viewModel.refresh()
            }
    }
}
