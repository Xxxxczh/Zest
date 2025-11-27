//
//  PermissionsManager.swift
//  Zest
//
//  Created by Claude on 2025-11-26.
//

import AppKit
import ApplicationServices

@MainActor
final class PermissionsManager {
    // MARK: - Singleton

    static let shared = PermissionsManager()

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    func checkAccessibility(prompt: Bool = true) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            return AXIsProcessTrustedWithOptions(options as CFDictionary)
        } else {
            return AXIsProcessTrusted()
        }
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
