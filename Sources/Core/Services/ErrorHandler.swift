//
//  ErrorHandler.swift
//  Zest
//
//  Created by Claude on 2025-11-26.
//

import Foundation
import os.log

enum ZestError: Error, LocalizedError {
    case clipboardAccessDenied
    case itemNotFound
    case pasteFailure
    case storageError(String)
    case hotKeyRegistrationFailed
    case imageProcessingFailed
    case fileSystemError(String)
    case jsonEncodingError
    case jsonDecodingError

    var errorDescription: String? {
        switch self {
        case .clipboardAccessDenied:
            return "剪贴板访问被拒绝"
        case .itemNotFound:
            return "未找到指定项目"
        case .pasteFailure:
            return "粘贴失败"
        case .storageError(let message):
            return "存储错误: \(message)"
        case .hotKeyRegistrationFailed:
            return "快捷键注册失败"
        case .imageProcessingFailed:
            return "图片处理失败"
        case .fileSystemError(let message):
            return "文件系统错误: \(message)"
        case .jsonEncodingError:
            return "数据编码错误"
        case .jsonDecodingError:
            return "数据解码错误"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .clipboardAccessDenied:
            return "请在系统偏好设置中授予应用辅助功能权限"
        case .pasteFailure:
            return "请检查剪贴板内容是否有效"
        case .hotKeyRegistrationFailed:
            return "请重启应用或检查系统快捷键设置"
        default:
            return "请重试或联系技术支持"
        }
    }
}

@MainActor
final class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()

    private let logger = Logger(subsystem: "com.orange.zest", category: "ErrorHandler")

    @Published var lastError: ZestError?
    @Published var showError = false

    private init() {}

    func handle(_ error: ZestError, showToast: Bool = false) {
        logger.error("Error occurred: \(error.localizedDescription)")

        lastError = error
        showError = showToast

        if !showToast {
            // 在控制台显示详细错误
            print("❌ [Zest] \(error.localizedDescription)")
            if let suggestion = error.recoverySuggestion {
                print("💡 建议: \(suggestion)")
            }
        }
    }

    func clearError() {
        lastError = nil
        showError = false
    }

    func reportAsyncError(_ error: Error, context: String) {
        let zestError: ZestError

        if let zError = error as? ZestError {
            zestError = zError
        } else {
            zestError = .storageError("\(context): \(error.localizedDescription)")
        }

        Task { @MainActor in
            self.handle(zestError)
        }
    }
}

// 错误包装器扩展
extension Result where Failure == Error {
    var zestError: ZestError {
        switch self {
        case .success:
            fatalError("Cannot convert success case to error")
        case .failure(let error):
            if let zestError = error as? ZestError {
                return zestError
            } else {
                return ZestError.storageError(error.localizedDescription)
            }
        }
    }
}
