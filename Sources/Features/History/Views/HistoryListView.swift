//
//  HistoryListView.swift
//  Zest
//
//  Created by Claude on 2025-11-26.
//

import SwiftUI
import SwiftData

struct HistoryListView: View {
    @ObservedObject var storageService = StorageService.shared
    @ObservedObject var inputState: InputState

    @State private var selectedItemID: UUID?
    @State private var filterType: FilterType = .all
    @State private var suppressHoverSelection = false
    @State private var hoverResumeTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

    var onSelect: (ClipItem) -> Void
    var onClose: () -> Void

    enum FilterType: String, CaseIterable, Identifiable {
        case all = "全部"
        case text = "文本"
        case image = "图片"
        case file = "文件"
        
        var id: String { self.rawValue }
        
        var icon: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .text: return "text.alignleft"
            case .image: return "photo"
            case .file: return "folder"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. 头部区域 (固定高度)
            VStack(spacing: 12) {
                // 搜索框
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    // 可编辑的搜索框，支持输入法
                    TextField("搜索剪贴板历史...", text: $inputState.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .light))
                        .focused($isSearchFocused)
                        .onSubmit {
                            // 按 Enter 时粘贴当前选中或第一个结果
                            if let item = selectedItem ?? filteredItems.first {
                                selectedItemID = item.id
                                onSelect(item)
                            }
                        }
                        // 关键：拦截上下键，不让 TextField 消费
                        .onMoveCommand { direction in
                            switch direction {
                            case .up:
                                inputState.command = .moveUp
                            case .down:
                                inputState.command = .moveDown
                            default:
                                break
                            }
                        }
                }
                .frame(height: 40)

                // 筛选标签
                HStack(spacing: 8) {
                    ForEach(FilterType.allCases) { type in
                        FilterButton(type: type, isSelected: filterType == type) {
                            withAnimation(.snappy(duration: 0.2)) {
                                filterType = type
                                selectedItemID = filteredItems.first?.id
                            }
                        }
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // 分割线
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 1)

            // MARK: - 2. 列表区域
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filteredItems.isEmpty {
                            ContentUnavailableView {
                                Label("No Results", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try searching for something else")
                            }
                            .foregroundStyle(.secondary)
                            .padding(.top, 60)
                        } else {
                            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                                HistoryRowView(
                                    item: item,
                                    index: index,
                                    isSelected: item.id == selectedItemID
                                )
                                .id(item.id)
                                .onTapGesture {
                                    selectedItemID = item.id
                                    onSelect(item)
                                }
                                .onHover { isHovering in
                                    guard isHovering, !suppressHoverSelection else { return }
                                    selectedItemID = item.id
                                }
                            }
                        }

                        // 底部留白，为快捷键 HUD 留出空间
                        Color.clear.frame(height: 50)
                    }
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .onChange(of: inputState.command) { _, command in
                    handleCommand(command, proxy: proxy)
                }
                .onChange(of: inputState.searchText) { _, _ in
                    selectedItemID = filteredItems.first?.id
                }
            }

            // MARK: - 3. 底部快捷键 HUD
            KeyboardShortcutsHUD()
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .frame(
            width: Constants.UI.historyWindowSize.width,
            height: Constants.UI.historyWindowSize.height
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            // 窗口显示时自动聚焦搜索框，支持立即输入（包括中文）
            isSearchFocused = true
            ensureValidSelection()
        }
        .onChange(of: filteredItems.map(\.id)) { _, _ in
            ensureValidSelection()
        }
        .onDisappear {
            hoverResumeTask?.cancel()
        }
    }

    var filteredItems: [ClipItem] {
        let items = storageService.recentItems.filter { item in
            switch filterType {
            case .all: return true
            case .text: return item.isText
            case .image: return item.isImage
            case .file: return item.isFile
            }
        }
        
        if inputState.searchText.isEmpty {
            return items
        } else {
            return items.filter { item in
                item.preview.localizedCaseInsensitiveContains(inputState.searchText)
            }
        }
    }

    private var selectedItem: ClipItem? {
        guard let id = selectedItemID else {
            return filteredItems.first
        }
        return filteredItems.first(where: { $0.id == id }) ?? filteredItems.first
    }

    private var currentSelectionIndex: Int? {
        guard let item = selectedItem else { return nil }
        return filteredItems.firstIndex(where: { $0.id == item.id })
    }
    
    private func handleCommand(_ command: InputState.InputCommand?, proxy: ScrollViewProxy) {
        guard let command = command else { return }
        switch command {
        case .moveUp:
            guard !filteredItems.isEmpty else { break }
            pauseHoverSelection()
            moveSelection(by: -1)
            scrollToSelection(proxy: proxy)
        case .moveDown:
            guard !filteredItems.isEmpty else { break }
            pauseHoverSelection()
            moveSelection(by: 1)
            scrollToSelection(proxy: proxy)
        case .moveLeft:
            // 切换到上一个分类
            let allCases = FilterType.allCases
            if let currentIndex = allCases.firstIndex(of: filterType) {
                let newIndex = (currentIndex - 1 + allCases.count) % allCases.count
                withAnimation(.snappy(duration: 0.2)) {
                    filterType = allCases[newIndex]
                    selectedItemID = filteredItems.first?.id
                }
            }
        case .moveRight:
            // 切换到下一个分类
            let allCases = FilterType.allCases
            if let currentIndex = allCases.firstIndex(of: filterType) {
                let newIndex = (currentIndex + 1) % allCases.count
                withAnimation(.snappy(duration: 0.2)) {
                    filterType = allCases[newIndex]
                    selectedItemID = filteredItems.first?.id
                }
            }
        case .confirm:
            if let item = selectedItem ?? filteredItems.first {
                selectedItemID = item.id
                onSelect(item)
            }
        case .cancel:
            onClose()
        case .pasteIndex(let index):
            if filteredItems.indices.contains(index) {
                selectedItemID = filteredItems[index].id
                onSelect(filteredItems[index])
            }
        case .resetSelection:
            resetSelection(proxy: proxy)
        }
        DispatchQueue.main.async { inputState.command = nil }
    }
    
    private func moveSelection(by offset: Int) {
        guard !filteredItems.isEmpty else { return }
        let currentIndex = currentSelectionIndex ?? 0
        let newIndex = (currentIndex + offset + filteredItems.count) % filteredItems.count
        selectedItemID = filteredItems[newIndex].id
    }

    private func resetSelection(proxy: ScrollViewProxy) {
        guard let firstID = filteredItems.first?.id else {
            selectedItemID = nil
            return
        }

        selectedItemID = firstID
        withAnimation {
            proxy.scrollTo(firstID, anchor: .top)
        }
    }

    private func scrollToSelection(proxy: ScrollViewProxy) {
        guard let id = selectedItemID,
              filteredItems.contains(where: { $0.id == id }) else { return }
        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
            proxy.scrollTo(id, anchor: .center)
        }
    }

    private func pauseHoverSelection() {
        suppressHoverSelection = true
        hoverResumeTask?.cancel()
        hoverResumeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            suppressHoverSelection = false
        }
    }

    private func ensureValidSelection() {
        let ids = filteredItems.map(\.id)
        guard !ids.isEmpty else {
            selectedItemID = nil
            return
        }

        if let selectedItemID, ids.contains(selectedItemID) {
            return
        }

        selectedItemID = ids.first
    }
}

// MARK: - Subviews

struct FilterButton: View {
    let type: HistoryListView.FilterType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 11))
                Text(type.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                isSelected ? Color.primary.opacity(0.1) : Color.clear
            )
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct HistoryRowView: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 1. 序号/图标列
            ZStack {
                if index < 9 {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 20)
            
            // 2. 内容列
            VStack(alignment: .leading, spacing: 4) {
                if item.isImage {
                    if let data = item.thumbnailData ?? item.imageData,
                       let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Label("Image Error", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(item.preview)
                        .font(.system(size: 14))
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                
                // Metadata
                HStack(spacing: 6) {
                    if let app = item.sourceApp {
                        Text(app)
                            .font(.system(size: 10, weight: .medium))
                    }
                    Text("•")
                    Text(item.createdAt, style: .time)
                        .font(.system(size: 10))
                }
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary.opacity(0.7))
            }
            
            Spacer()
            
            // 3. 类型图标 (右侧)
            Image(systemName: iconName)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .white.opacity(0.6) : .secondary.opacity(0.3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor : Color.clear) // Raycast 风格：选中时用强调色高亮
                .padding(.horizontal, 8)
        )
        .contentShape(Rectangle())
    }
    
    private var iconName: String {
        if item.isText { return "text.alignleft" }
        if item.isImage { return "photo" }
        if item.isFile { return "doc" }
        return "questionmark"
    }
}

// MARK: - Keyboard Shortcuts HUD

struct KeyboardShortcutsHUD: View {
    var body: some View {
        HStack(spacing: 16) {
            ShortcutHint(icon: "↑↓", label: "浏览")
            ShortcutHint(icon: "←→", label: "分类")
            ShortcutHint(icon: "⏎", label: "粘贴")
            ShortcutHint(icon: "⌘1-9", label: "快选")
            ShortcutHint(icon: "Esc", label: "关闭")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(Color.primary.opacity(0.03))
        )
    }
}

struct ShortcutHint: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
