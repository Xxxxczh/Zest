//
//  ZestApp.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import SwiftUI
import AppKit

@main
struct ZestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 空 Scene - 菜单栏应用不需要主窗口
        Settings {
            PreferencesView()
        }
    }
}
