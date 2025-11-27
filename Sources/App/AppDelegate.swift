//
//  AppDelegate.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import AppKit
import SwiftUI
import Carbon

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private let clipboardService = ClipboardService.shared
    private let storageService = StorageService.shared
    private let hotKeyService = HotKeyService.shared
    private let menuBarManager = MenuBarManager.shared
    private let permissionsManager = PermissionsManager.shared

    private let defaults = UserDefaults.standard
    private let logger = LoggerService.app
    private var authCheckTask: Task<Void, Never>?
    private var hasShownAuthToast = false

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        registerDefaultSettings()
        menuBarManager.delegate = self
        menuBarManager.setup()

        hotKeyService.onConflict = { [weak self] in
            Task { @MainActor in
                self?.openPreferences()
            }
        }

        attemptAuthorizationFlow()

        logger.success("Zest 已启动")
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardService.stopMonitoring()
        hotKeyService.unregisterAll()
        authCheckTask?.cancel()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        clipboardService.updateAppActive(true)
    }

    func applicationDidResignActive(_ notification: Notification) {
        clipboardService.updateAppActive(false)
    }

    // MARK: - Setup

    private func registerDefaultSettings() {
        defaults.register(defaults: [
            Constants.UserDefaultsKeys.showMenuBarIcon: true,
            Constants.UserDefaultsKeys.maxHistoryCount: Constants.Storage.defaultMaxHistoryCount,
            Constants.UserDefaultsKeys.pollingInterval: Constants.Timing.clipboardPollingInterval,
            Constants.UserDefaultsKeys.onboardingShown: false,
            Constants.UserDefaultsKeys.historyHintDismissed: false
        ])
    }

    private func attemptAuthorizationFlow() {
        let granted = permissionsManager.checkAccessibility(prompt: true)
        clipboardService.setAuthorization(granted: granted)

        if granted {
            startServices()
        } else {
            handleUnauthorizedState(showCTA: true)
        }
    }

    private func handleUnauthorizedState(showCTA: Bool) {
        hotKeyService.unregisterAll()
        hotKeyService.disableDoubleShiftMonitor()
        clipboardService.stopMonitoring()

        // 仅依赖系统的辅助功能弹窗提示，不再额外展示自定义浮层
        if showCTA {
            logger.logWarning("缺少辅助功能权限，已暂停监听")
        }

        authCheckTask?.cancel()
        authCheckTask = Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard let self else { return }

                let granted = await MainActor.run {
                    self.permissionsManager.checkAccessibility(prompt: false)
                }

                if granted {
                    await MainActor.run {
                        self.clipboardService.setAuthorization(granted: true)
                        self.startServices()
                    }
                    return
                }
            }
        }
    }

    private func startServices() {
        setupGlobalHotKeys()
        clipboardService.startMonitoring()
        showWelcomeWindow()
        showOnboardingIfNeeded()
        showAuthorizationSuccessToastIfNeeded()
        observeAuthorizationLoss()
    }

    private func setupGlobalHotKeys() {
        hotKeyService.enableDoubleShiftMonitor {
            Task { @MainActor in
                HistoryWindowController.shared.show()
            }
        }

        hotKeyService.register(
            key: Constants.HotKeys.vKeyCode,
            modifiers: UInt32(cmdKey | shiftKey),
            id: "history"
        ) {
            Task { @MainActor in
                HistoryWindowController.shared.show()
            }
        }

        hotKeyService.register(
            key: Constants.HotKeys.commaKeyCode,
            modifiers: UInt32(cmdKey | shiftKey),
            id: "preferences"
        ) { [weak self] in
            Task { @MainActor in
                self?.openPreferences()
            }
        }
    }

    private func showWelcomeWindow() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Constants.Timing.welcomeWindowDelay)
            HistoryWindowController.shared.show()
        }
    }

    private func showOnboardingIfNeeded() {
        let hasShown = defaults.bool(forKey: Constants.UserDefaultsKeys.onboardingShown)
        guard !hasShown else { return }

        ToastManager.shared.show(
            "提示：双击 Shift 或 ⌘⇧V 唤起历史，已默认忽略密码类应用，可在设置修改",
            icon: "lightbulb.fill",
            duration: 4.0
        )

        defaults.set(true, forKey: Constants.UserDefaultsKeys.onboardingShown)
    }

    private func showAuthorizationSuccessToastIfNeeded() {
        guard !hasShownAuthToast else { return }
        hasShownAuthToast = true
        ToastManager.shared.show(
            "辅助权限已开启，试试双击 Shift 或 ⌘⇧V 唤起历史",
            icon: "checkmark.shield.fill",
            duration: 3.0
        )
    }

    private func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func observeAuthorizationLoss() {
        authCheckTask?.cancel()
        authCheckTask = Task { [weak self] in
            for _ in 0..<60 {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self else { return }

                let granted = await MainActor.run {
                    self.permissionsManager.checkAccessibility(prompt: false)
                }

                if !granted {
                    await MainActor.run {
                        self.clipboardService.setAuthorization(granted: false)
                        self.handleUnauthorizedState(showCTA: true)
                    }
                    return
                }
            }
        }
    }

    // MARK: - Actions

    @objc func openPreferences() {
        PreferencesWindowController.shared.show()
    }
}

// MARK: - MenuBarManagerDelegate

extension AppDelegate: MenuBarManagerDelegate {
    func menuBarManagerDidClickIcon() {
        HistoryWindowController.shared.show()
    }

    func menuBarManagerDidRequestPreferences() {
        openPreferences()
    }

    func menuBarManagerDidToggleMonitoring(isPaused: Bool) {
        if isPaused {
            clipboardService.stopMonitoring()
            logger.info("剪贴板监听已暂停")
            ToastManager.shared.show("剪贴板监听已暂停", icon: "pause.circle.fill")
        } else {
            if permissionsManager.checkAccessibility(prompt: true) {
                clipboardService.setAuthorization(granted: true)
                logger.info("剪贴板监听已恢复")
                ToastManager.shared.show("剪贴板监听已恢复", icon: "play.circle.fill")
            } else {
                handleUnauthorizedState(showCTA: true)
            }
        }
    }
}
