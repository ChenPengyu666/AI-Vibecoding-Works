import SwiftUI

/// 主界面 — 搜索栏 + 卡片列表 + 底部工具栏
struct ContentView: View {
    @State private var viewModel = ClipboardViewModel()
    @State private var scrollTarget: String?
    @State private var showSettings = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBarView(text: $viewModel.searchText)

                // 列表
                if viewModel.filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(viewModel.filteredItems) { item in
                                ClipboardCardView(
                                    item: item,
                                    isHighlighted: viewModel.highlightedId == item.id,
                                    onCopy: { viewModel.copyToClipboard(item) },
                                    onTogglePin: { viewModel.togglePin(item) },
                                    onDelete: { viewModel.delete(item) },
                                    onPreviewImage: { viewModel.previewImage(item) },
                                    onOpenInFinder: { viewModel.openInFinder(item) }
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .id(item.id)
                            }
                        }
                        .listStyle(.plain)
                        .onChange(of: scrollTarget) { _, id in
                            if let id = id {
                                withAnimation { proxy.scrollTo(id, anchor: .top) }
                                scrollTarget = nil
                            }
                        }
                    }
                }

                // 底部工具栏
                bottomBar
            }

            // 图片预览覆盖层
            if let imageData = viewModel.previewImageData {
                ImagePreviewView(imageData: imageData) {
                    viewModel.dismissPreview()
                }
            }
        }
        .frame(minWidth: 360, idealWidth: 380,
               minHeight: 400, idealHeight: 480)
        .onAppear {
            viewModel.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardDataChanged)) { _ in
            viewModel.refresh()
            // 新复制项到达时，自动滚动到列表最顶端
            if let newestId = viewModel.filteredItems.first?.id {
                scrollTarget = newestId
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: viewModel.searchText.isEmpty ? "clipboard" : "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.accent)

            Text(viewModel.searchText.isEmpty ? "暂无剪贴板历史" : "没有找到匹配的记录")
                .font(.title3)
                .foregroundColor(.primary)

            Text(viewModel.searchText.isEmpty ? "试试复制一些内容吧 ⌘+C" : "尝试其他关键词")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 底部工具栏

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("设置")

                Text("共 \(viewModel.itemCount) 条历史")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption2)
                    .foregroundColor(.green)
                Text("监听中")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.97))
        }
    }
}

#Preview {
    ContentView()
}
