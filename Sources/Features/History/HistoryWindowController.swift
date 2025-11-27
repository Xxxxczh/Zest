//
//  HistoryWindowController.swift
//  Zest
//
//  Created by Claude on 2025-11-26.
//

import AppKit
import SwiftUI

// 定义 InputState
class InputState: ObservableObject {
    @Published var searchText = ""
    @Published var command: InputCommand?
    
    enum InputCommand: Equatable {
        case moveUp
        case moveDown
        case moveLeft
        case moveRight
        case confirm
        case cancel
        case pasteIndex(Int)
        case resetSelection // 新增：重置选中项指令
    }
}

// 定义 HistoryPanel - 支持输入法的非抢焦点浮动面板
class HistoryPanel: NSPanel {
    // 核心：动态控制是否能成为 Key Window
    // 允许短暂成为 Key（用于输入法），但立即释放
    private var allowBecomingKey = false

    override var canBecomeKey: Bool {
        // 当需要使用输入法时，临时允许成为 Key
        return allowBecomingKey
    }

    override var canBecomeMain: Bool { false }

    // 允许窗口临时成为 Key（用于输入法）
    func enableKeyStatus() {
        allowBecomingKey = true
    }

    // 恢复非 Key 状态
    func disableKeyStatus() {
        allowBecomingKey = false
    }

    override var acceptsFirstResponder: Bool { true }
}

// 自定义 HostingController，拦截键盘事件
final class HistoryHostingController: NSHostingController<HistoryListView> {
    var keyHandler: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if keyHandler?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class HistoryWindowController: NSObject, NSWindowDelegate {
    static let shared = HistoryWindowController()
    
    private var window: HistoryPanel?
    private var globalClickMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localClickMonitor: Any?
    private var localKeyMonitor: Any?
    
    // 共享输入状态，连接 Controller (按键捕获) 和 View (显示/逻辑)
    let inputState = InputState()
    
    private override init() {
        super.init()
    }
    
    func show() {
        if let w = window, w.isVisible {
            close()
            return
        }

        createWindowIfNeeded()

        guard let window = window else { return }

        // 优化位置计算：跟随鼠标所在的屏幕
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main

        if let screen = activeScreen {
            let screenFrame = screen.visibleFrame
            let contentSize = Constants.UI.historyWindowSize
            let targetSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
            window.setContentSize(contentSize)

            var origin = NSPoint(
                x: screenFrame.midX - targetSize.width / 2,
                y: screenFrame.midY - targetSize.height / 2 + 100
            )

            // 避免首开时窗口被挤出屏幕边界
            origin.x = min(max(origin.x, screenFrame.minX + 20), screenFrame.maxX - targetSize.width - 20)
            origin.y = min(max(origin.y, screenFrame.minY + 20), screenFrame.maxY - targetSize.height - 20)

            window.setFrame(NSRect(origin: origin, size: targetSize), display: false)
        }

        // 重置状态
        inputState.searchText = ""
        inputState.command = .resetSelection

        // 核心：启用输入法支持
        // 1. 允许窗口成为 Key（输入法需要）
        window.enableKeyStatus()

        // 2. 让窗口成为 Key Window（但因为有 .transient + .popUpMenu，不会触发 blur）
        window.makeKeyAndOrderFront(nil)

        // 3. 延迟极短时间后，如果没有输入活动，降低优先级
        // 这样既支持输入法，又最小化对原应用的影响
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            // 如果用户还没开始输入，可以考虑释放 Key（但保持窗口可见）
            // 注意：不要真的释放，否则输入法会失效
        }

        setupEventMonitors()
    }
    
    func close() {
        // 恢复非 Key 状态
        window?.disableKeyStatus()
        window?.close()
        removeEventMonitors()
        inputState.searchText = ""
    }
    
    private func createWindowIfNeeded() {
        if window != nil { return }
        
        // 注入 inputState 和回调
        let contentView = HistoryListView(
            inputState: inputState,
            onSelect: { [weak self] item in
                self?.handleSelection(item)
            },
            onClose: { [weak self] in
                self?.close()
            }
        )
        
        let hostingController = HistoryHostingController(rootView: contentView)
        hostingController.keyHandler = { [weak self] event in
            return self?.handleKey(event) ?? false
        }
        
        let panelSize = Constants.UI.historyWindowSize
        let panelRect = NSRect(origin: .zero, size: panelSize)
        // 关键修改：添加 .nonactivatingPanel
        let newWindow = HistoryPanel(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        newWindow.contentViewController = hostingController
        newWindow.setContentSize(panelSize)
        newWindow.backgroundColor = NSColor.clear
        newWindow.isOpaque = false
        newWindow.hasShadow = true

        // 核心1: 使用 popUpMenu 级别（比 floating 更高，类似下拉菜单）
        // 这个级别的窗口不会触发其他应用的 blur 事件
        newWindow.level = .popUpMenu

        // 核心2: 设置为 transient（临时窗口）和 ignoresCycle（不参与窗口循环）
        // transient 告诉系统这是辅助窗口，不应影响其他窗口的焦点状态
        newWindow.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,           // 关键！标记为临时窗口
            .ignoresCycle         // 不出现在 Cmd+Tab 中
        ]

        // 核心3: 即使应用失去激活状态，窗口也不隐藏
        newWindow.hidesOnDeactivate = false
        
        self.window = newWindow
        newWindow.delegate = self
    }
    
    private func handleSelection(_ item: ClipItem) {
        close()
        // NSApp.hide(nil) // 移除主动隐藏，依靠系统自然焦点回落
        
        // 异步粘贴，确保窗口关闭动画完成后执行
        Task {
            // 稍微等待 (0.05s)
            try? await Task.sleep(nanoseconds: 50_000_000)
            try? await ClipboardService.shared.pasteItem(withId: item.id)
        }
    }
    
    // MARK: - Event Monitoring (The Magic)
    
    private func setupEventMonitors() {
        // 1. 全局点击监听 (App 在后台时，点击外部关闭)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.close()
        }
        
        // 2. 全局键盘监听 (App 在后台时，捕获键盘)
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                _ = self?.handleKey(event)
            }
        }
        
        // 3. 本地点击监听 (App 在前台时，比如打开了偏好设置，点击其他窗口关闭历史记录)
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let window = self?.window, event.window != window {
                self?.close()
            }
            return event
        }

        // 4. 本地键盘监听（窗口为前台时也能响应方向键）
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let handled = self.handleKey(event)
            return handled ? nil : event
        }
    }
    
    @discardableResult
    private func handleKey(_ event: NSEvent) -> Bool {
        guard let window = self.window, window.isVisible else { return false }

        // 只处理控制键和快捷键，不处理文本输入
        // 文本输入由 TextField 自然处理（支持输入法）

        switch event.keyCode {
        case 53: // Esc
            self.close()
            return true
        case 36: // Enter
            self.inputState.command = .confirm
            return true
        case 126: // Up
            self.inputState.command = .moveUp
            return true
        case 125: // Down
            self.inputState.command = .moveDown
            return true
        case 123: // Left
            self.inputState.command = .moveLeft
            return true
        case 124: // Right
            self.inputState.command = .moveRight
            return true
        default:
            break
        }

        // 快捷键 (Cmd + 1~9) - 快速粘贴
        if event.modifierFlags.contains(.command),
           let chars = event.characters,
           let num = Int(chars), num >= 1 && num <= 9 {
            self.inputState.command = .pasteIndex(num - 1)
            return true
        }

        // 不处理文本输入
        return false
    }
    
    private func removeEventMonitors() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = globalKeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalKeyMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}
