//
//  HistoryView.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @ObservedObject var storageService = StorageService.shared

    @State private var searchText = ""
    @State private var selectedItem: ClipItem?

    var body: some View {
        NavigationSplitView {
            // 列表
            List(selection: $selectedItem) {
                ForEach(filteredItems) { item in
                    HistoryItemRow(item: item)
                        .tag(item)
                        .contextMenu {
                            Button("复制") {
                                copyItem(item)
                            }

                            Button("删除") {
                                storageService.deleteItem(item)
                            }

                            Divider()

                            Button(item.isPinned ? "取消固定" : "固定") {
                                togglePin(item)
                            }
                        }
                }
            }
            .searchable(text: $searchText, prompt: "搜索历史记录")
            .navigationTitle("剪贴板历史")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: clearAll) {
                        Label("清空", systemImage: "trash")
                    }
                }
            }
        } detail: {
            // 详情
            if let item = selectedItem {
                ItemDetailView(item: item)
            } else {
                ContentUnavailableView(
                    "选择一个项目",
                    systemImage: "doc.on.clipboard"
                )
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    // MARK: - Computed

    var filteredItems: [ClipItem] {
        if searchText.isEmpty {
            return storageService.recentItems
        } else {
            return storageService.recentItems.filter { item in
                item.preview.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Actions

    private func copyItem(_ item: ClipItem) {
        Task {
            do {
                try await ClipboardService.shared.pasteItem(withId: item.id)
            } catch {
                print("复制失败: \(error)")
            }
        }
    }

    private func togglePin(_ item: ClipItem) {
        storageService.togglePin(item)
    }

    private func clearAll() {
        storageService.clearAll()
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let item: ClipItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.iconName)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.preview)
                    .lineLimit(2)
                    .font(.body)

                HStack(spacing: 8) {
                    if let app = item.sourceApp {
                        Text(app)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.createdAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if item.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(.blue)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Item Detail View

struct ItemDetailView: View {
    let item: ClipItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: item.iconName)
                        .font(.title)
                        .foregroundStyle(.blue)

                    Text(item.dataType.capitalized)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Button("复制", systemImage: "doc.on.doc") {
                        copyToClipboard()
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                if let text = item.textContent {
                    TextEditor(text: .constant(text))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                        .border(Color.secondary.opacity(0.2))
                } else if let imageData = item.imageData,
                          let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                } else if let urls = item.fileURLs {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(urls, id: \.self) { url in
                            Label(url.lastPathComponent, systemImage: "doc")
                        }
                    }
                }

                GroupBox("信息") {
                    VStack(alignment: .leading, spacing: 8) {
                        InfoRow(title: "创建时间", value: item.createdAt.formatted())
                        if let app = item.sourceApp {
                            InfoRow(title: "来源应用", value: app)
                        }
                        InfoRow(title: "ID", value: item.id.uuidString)
                    }
                    .padding(8)
                }
            }
            .padding()
        }
    }

    private func copyToClipboard() {
        Task {
            try? await ClipboardService.shared.pasteItem(withId: item.id)
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    HistoryView()
}
