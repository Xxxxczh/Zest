//
//  MenuBarManager.swift
//  Zest
//
//  Created by Claude on 2025-11-26.
//

import AppKit
import SwiftUI

@MainActor
final class MenuBarManager {
    // MARK: - Singleton

    static let shared = MenuBarManager()

    // MARK: - Properties

    private(set) var statusItem: NSStatusItem?
    private let defaults = UserDefaults.standard
    private var isMonitoringPaused = false

    weak var delegate: MenuBarManagerDelegate?

    // MARK: - Init

    private init() {
        setupObservers()
    }

    // MARK: - Public Methods

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else {
            print("❌ 无法创建菜单栏按钮")
            return
        }

        button.image = createZestIcon()
        button.action = #selector(statusBarClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        updateVisibility()
        print("✅ 菜单栏设置完成")
    }

    func updateVisibility() {
        let shouldShow = defaults.bool(forKey: Constants.UserDefaultsKeys.showMenuBarIcon)

        if shouldShow {
            if statusItem == nil {
                setup()
            }
            statusItem?.isVisible = true
        } else {
            statusItem?.isVisible = false
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateVisibility()
            }
        }
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            delegate?.menuBarManagerDidClickIcon()
            return
        }

        // Option+点击：显示简化菜单
        if event.modifierFlags.contains(.option) {
            showContextMenu()
            return
        }

        // 右键：直接打开偏好设置
        if event.type == .rightMouseUp {
            delegate?.menuBarManagerDidRequestPreferences()
            return
        }

        // 左键：显示历史记录
        delegate?.menuBarManagerDidClickIcon()
    }

    private func showContextMenu() {
        let menu = createContextMenu()
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // 暂停/恢复监听
        let pauseTitle = isMonitoringPaused ? "恢复监听" : "暂停监听"
        let pauseItem = NSMenuItem(
            title: pauseTitle,
            action: #selector(toggleMonitoring),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        // 退出
        let quitItem = NSMenuItem(
            title: "退出 Zest",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func createZestIcon() -> NSImage {
        let image = NSImage(size: Constants.UI.menuBarIconSize)

        image.lockFocus()

        let bodyRect = NSRect(x: 4, y: 2, width: 14, height: 14)
        let bodyPath = NSBezierPath(ovalIn: bodyRect)
        NSColor.black.setFill()
        bodyPath.fill()

        let leafPath = NSBezierPath()
        leafPath.move(to: NSPoint(x: 11, y: 15))
        leafPath.curve(to: NSPoint(x: 16, y: 18), controlPoint1: NSPoint(x: 11, y: 18), controlPoint2: NSPoint(x: 14, y: 19))
        leafPath.curve(to: NSPoint(x: 11, y: 15), controlPoint1: NSPoint(x: 16, y: 16), controlPoint2: NSPoint(x: 13, y: 15))
        leafPath.fill()

        image.unlockFocus()
        image.isTemplate = true

        return image
    }

    @objc private func toggleMonitoring() {
        isMonitoringPaused.toggle()
        delegate?.menuBarManagerDidToggleMonitoring(isPaused: isMonitoringPaused)

        // 更新图标状态（暂停时图标变灰）
        if let button = statusItem?.button {
            button.appearsDisabled = isMonitoringPaused
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Delegate

@MainActor
protocol MenuBarManagerDelegate: AnyObject {
    func menuBarManagerDidClickIcon()
    func menuBarManagerDidRequestPreferences()
    func menuBarManagerDidToggleMonitoring(isPaused: Bool)
}
