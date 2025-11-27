//
//  LoggerService.swift
//  Zest
//
//  Created by Claude on 2025-11-27.
//

import Foundation
import os.log

/// 统一的日志服务
final class LoggerService {
    // MARK: - Subsystem

    private static let subsystem = "com.orange.zest"

    // MARK: - Loggers

    static let clipboard = Logger(subsystem: subsystem, category: "Clipboard")
    static let storage = Logger(subsystem: subsystem, category: "Storage")
    static let hotkey = Logger(subsystem: subsystem, category: "HotKey")
    static let app = Logger(subsystem: subsystem, category: "App")
    static let general = Logger(subsystem: subsystem, category: "General")
}

// MARK: - Convenience Extensions

extension Logger {
    /// 记录成功操作
    func success(_ message: String) {
        self.info("✅ \(message)")
    }

    /// 记录警告
    func logWarning(_ message: String) {
        self.warning("⚠️ \(message)")
    }

    /// 记录错误
    func failure(_ message: String) {
        self.error("❌ \(message)")
    }

    /// 记录调试信息
    func logDebug(_ message: String) {
        self.debug("🔍 \(message)")
    }
}
