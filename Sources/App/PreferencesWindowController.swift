//
//  PreferencesWindowController.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import AppKit
import SwiftUI

@MainActor
class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "偏好设置"
        window.center()
        window.setFrameAutosaveName("PreferencesWindow")
        window.isReleasedWhenClosed = false

        // 创建 SwiftUI 视图
        let contentView = NSHostingView(rootView: PreferencesView())
        window.contentView = contentView

        super.init(window: window)

        print("✅ PreferencesWindowController 已初始化")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        print("📌 尝试显示偏好设置窗口...")

        guard let window = window else {
            print("❌ 窗口为 nil")
            return
        }

        // 激活应用
        NSApp.activate(ignoringOtherApps: true)

        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        print("✅ 偏好设置窗口已显示")
    }
}
