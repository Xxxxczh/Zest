//
//  ToastView.swift
//  Zest
//
//  Created by Claude on 2025-11-26.
//

import SwiftUI
import AppKit

// MARK: - Toast Manager

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published private(set) var currentToast: ToastMessage?
    private var toastWindow: NSWindow?

    private init() {}

    func show(_ message: String, icon: String = "checkmark.circle.fill", duration: TimeInterval = 2.0) {
        let toast = ToastMessage(message: message, icon: icon, action: nil)
        currentToast = toast

        // 创建或更新窗口
        if toastWindow == nil {
            createToastWindow()
        }

        toastWindow?.orderFrontRegardless()

        // 自动隐藏
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if currentToast?.id == toast.id {
                hideToast()
            }
        }
    }

    func show(_ message: String, icon: String = "checkmark.circle.fill", duration: TimeInterval = 2.0, action: (() -> Void)?) {
        let toast = ToastMessage(message: message, icon: icon, action: action)
        currentToast = toast

        if toastWindow == nil {
            createToastWindow()
        }

        toastWindow?.orderFrontRegardless()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if currentToast?.id == toast.id {
                hideToast()
            }
        }
    }

    private func createToastWindow() {
        let contentView = ToastContainerView()
            .environmentObject(self)

        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = hostingController
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.level = .statusBar // 显示在最顶层
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = false
        window.hidesOnDeactivate = false

        // 居中显示在屏幕顶部
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - window.frame.width / 2
            let y = screenFrame.maxY - window.frame.height - 60 // 距离顶部60pt
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        self.toastWindow = window
    }

    private func hideToast() {
        withAnimation(.easeOut(duration: 0.2)) {
            currentToast = nil
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            toastWindow?.orderOut(nil)
        }
    }
}

// MARK: - Toast Message Model

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let icon: String
    let action: (() -> Void)?
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Container View

struct ToastContainerView: View {
    @EnvironmentObject var manager: ToastManager

    var body: some View {
        ZStack {
            if let toast = manager.currentToast {
                ToastView(message: toast.message, icon: toast.icon)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.currentToast)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String
    let icon: String
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            Spacer()

            if let action {
                Button {
                    action()
                } label: {
                    Text("操作")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 20)
        .frame(height: 80)
    }
}

#Preview {
    ToastView(message: "剪贴板监听已暂停", icon: "pause.circle.fill", action: {})
}
