//
//  Constants.swift
//  Zest
//
//  Created by Claude on 2025-11-26.
//

import Foundation

enum Constants {
    enum App {
        static let name = "Zest"
        static let bundleIdentifier = "com.orange.zest"
    }

    enum Timing {
        static let clipboardPollingInterval: TimeInterval = 0.5
        static let welcomeWindowDelay: UInt64 = 300_000_000
        static let pasteDelay: UInt64 = 50_000_000
        static let doubleShiftThreshold: TimeInterval = 0.3
    }

    enum Storage {
        static let appDirectory = "Zest"
        static let legacyAppDirectory = "ClipyModern"
        static let storeName = "Zest.store"
        static let legacyStoreName = "Clipy.store"
        static let defaultMaxHistoryCount = 30
        static let deduplicationCheckLimit = 30
    }

    enum UI {
        static let menuBarIconSize = NSSize(width: 22, height: 22)
        static let historyWindowSize = NSSize(width: 450, height: 600)
        static let previewTextLimit = 100
    }

    enum UserDefaultsKeys {
        static let showMenuBarIcon = "showMenuBarIcon"
        static let maxHistoryCount = "maxHistoryCount"
        static let pollingInterval = "pollingInterval"
        static let onboardingShown = "onboardingShown"
        static let historyHintDismissed = "historyHintDismissed"
    }

    enum HotKeys {
        static let vKeyCode: UInt32 = 0x09
        static let commaKeyCode: UInt32 = 0x2B
        static let escKeyCode: UInt16 = 53
        static let enterKeyCode: UInt16 = 36
        static let upKeyCode: UInt16 = 126
        static let downKeyCode: UInt16 = 125
        static let backspaceKeyCode: UInt16 = 51
    }
}
