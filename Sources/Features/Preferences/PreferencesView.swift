//
//  PreferencesView.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import AppKit
import SwiftUI

struct PreferencesView: View {
    @State private var selectedTab: SettingsTab = .general

    @AppStorage(Constants.UserDefaultsKeys.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Constants.UserDefaultsKeys.maxHistoryCount) private var maxHistoryCount = 30.0
    @AppStorage(Constants.UserDefaultsKeys.pollingInterval) private var pollingInterval = 0.5
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "通用"
        case clipboard = "剪贴板"
        case shortcuts = "快捷键"
        case about = "关于"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .clipboard: return "doc.on.clipboard.fill"
            case .shortcuts: return "command"
            case .about: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - 顶部标签栏
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // 分割线
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)

            // MARK: - 内容区域
            ScrollView {
                VStack(spacing: 0) {
                    switch selectedTab {
                    case .general:
                        GeneralPreferencesView(
                            launchAtLogin: $launchAtLogin,
                            maxHistoryCount: $maxHistoryCount,
                            showMenuBarIcon: $showMenuBarIcon
                        )
                    case .clipboard:
                        ClipboardPreferencesView(pollingInterval: $pollingInterval)
                    case .shortcuts:
                        ShortcutsPreferencesView()
                    case .about:
                        AboutView()
                    }
                }
                .padding(24)
            }
            .scrollContentBackground(.hidden)
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .frame(width: 700, height: 550)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: PreferencesView.SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                // 指示器
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 40, height: 3)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Color.clear
                        .frame(width: 40, height: 3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - General Preferences

struct GeneralPreferencesView: View {
    @ObservedObject var storageService = StorageService.shared
    @Binding var launchAtLogin: Bool
    @Binding var maxHistoryCount: Double
    @Binding var showMenuBarIcon: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 启动与外观
            SettingsCard(title: "启动与外观", icon: "sparkles") {
                VStack(spacing: 16) {
                    SettingsToggle(
                        icon: "arrow.right.circle.fill",
                        title: "登录时启动",
                        subtitle: "应用将在登录时自动启动",
                        isOn: $launchAtLogin
                    )
                    .onChange(of: launchAtLogin) { _, newValue in
                        LaunchService.shared.toggleLaunchAtLogin(newValue)
                    }

                    Divider()

                    SettingsToggle(
                        icon: "menubar.rectangle",
                        title: "显示菜单栏图标",
                        subtitle: "如果隐藏，可使用 Cmd+Shift+, 打开设置",
                        isOn: $showMenuBarIcon
                    )
                }
            }

            // 历史记录存储
            SettingsCard(title: "历史记录存储", icon: "clock.fill") {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最大历史数量")
                                .font(.system(size: 14, weight: .medium))
                            Text("当前已存储 \(storageService.recentItems.count) 条记录")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(maxHistoryCount)) 条")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $maxHistoryCount, in: 5...30, step: 5) {
                        EmptyView()
                    }
                    .tint(.accentColor)

                    Divider()

                    Button(role: .destructive) {
                        clearHistory()
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("清除所有历史记录")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

            // 应用控制
            SettingsCard(title: "应用控制", icon: "power.circle.fill") {
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                        Text("退出 Zest")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .onAppear {
            if maxHistoryCount > 30 {
                maxHistoryCount = 30
            }
        }
    }

    private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "清除所有历史记录"
        alert.informativeText = "确定要清除所有剪贴板历史吗？此操作不可撤销。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清除")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            StorageService.shared.clearAll()
        }
    }
}

// MARK: - Clipboard Preferences

struct ClipboardPreferencesView: View {
    @Binding var pollingInterval: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 监听性能
            SettingsCard(title: "监听性能", icon: "gauge.with.dots.needle.bottom.50percent") {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("轮询间隔")
                                .font(.system(size: 14, weight: .medium))
                            Text("较小的值响应更快，但会消耗更多资源")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.1f 秒", pollingInterval))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $pollingInterval, in: 0.1...2.0, step: 0.1) {
                        EmptyView()
                    }
                    .tint(.accentColor)
                    .onChange(of: pollingInterval) { _, _ in
                        Task { @MainActor in
                            ClipboardService.shared.refreshPollingInterval()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Shortcuts Preferences

struct ShortcutsPreferencesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard(title: "全局快捷键", icon: "command.circle.fill") {
                VStack(spacing: 14) {
                    ShortcutRow(
                        icon: "clock.arrow.circlepath",
                        title: "显示历史记录",
                        shortcuts: [
                            ["⇧", "⇧"],
                            ["⌘", "⇧", "V"]
                        ]
                    )

                    Divider()

                    ShortcutRow(
                        icon: "gearshape.fill",
                        title: "偏好设置",
                        shortcuts: [["⌘", "⇧", ","]]
                    )
                }
            }

            // 提示信息
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("快速连按两次 Shift 键即可唤起历史记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }
}

struct ShortcutRow: View {
    let icon: String
    let title: String
    let shortcuts: [[String]]

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 14))

            Spacer()

            HStack(spacing: 8) {
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { index, keys in
                    if index > 0 {
                        Text("或")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    KeyboardShortcutView(keys: keys)
                }
            }
        }
    }
}

struct KeyboardShortcutView: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                    )
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // 图标
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)

                VStack(spacing: 12) {
                    Text("Zest")
                        .font(.system(size: 36, weight: .bold))

                    HStack(spacing: 6) {
                        Text("Version 2.0.0")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange.opacity(0.1)))
                    .foregroundStyle(.orange)
                }

                VStack(spacing: 16) {
                    Text("Add some Zest to your workflow.\n让每一次复制粘贴都充满活力。")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))

                    Text("Crafted with 🍊 by Orange")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    // 反馈按钮
                    Link(destination: URL(string: "mailto:feedback@zest.app?subject=Zest%20Feedback")!) {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                            Text("发送反馈")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: .orange.opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Text("Copyright © 2025 Orange Studio. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 20)
        }
    }
}

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.bottom, 4)

            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Settings Toggle

struct SettingsToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

#Preview {
    PreferencesView()
}
