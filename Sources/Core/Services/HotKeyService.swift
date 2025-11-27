//
//  HotKeyService.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import AppKit
import Carbon

@MainActor
final class HotKeyService: ObservableObject {
    // MARK: - Singleton

    static let shared = HotKeyService()

    // MARK: - Properties

    private var eventHandler: EventHandlerRef?
    private var hotKeys: [HotKey] = []

    @Published var isEnabled = true

    private var modifierMonitor: Any?
    private var lastShiftDownTime: TimeInterval = 0
    private var doubleTapAction: (() -> Void)?
    var onConflict: (() -> Void)?

    private let logger = LoggerService.hotkey

    // MARK: - Init

    private init() {
        setupEventHandler()
    }

    // deinit 不能调用 @MainActor 方法，清理会在应用退出时由 applicationWillTerminate 处理

    // MARK: - Public Methods

    func enableDoubleShiftMonitor(action: @escaping () -> Void) {
        self.doubleTapAction = action

        if modifierMonitor != nil { return }

        modifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        logger.success("双击 Shift 监听已启动")
    }

    func disableDoubleShiftMonitor() {
        if let monitor = modifierMonitor {
            NSEvent.removeMonitor(monitor)
            modifierMonitor = nil
            logger.info("双击 Shift 监听已停止")
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        var flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags.contains(.capsLock) {
            flags.remove(.capsLock)
        }

        let isShiftOnly = flags == .shift

        if isShiftOnly {
            let now = Date().timeIntervalSince1970
            if now - lastShiftDownTime < Constants.Timing.doubleShiftThreshold {
                logger.logDebug("双击 Shift 触发！")
                DispatchQueue.main.async {
                    self.doubleTapAction?()
                }
                lastShiftDownTime = 0
            } else {
                lastShiftDownTime = now
            }
        }
    }

    func register(
        key: UInt32,
        modifiers: UInt32,
        id: String,
        handler: @escaping () -> Void
    ) {
        let hotKey = HotKey(
            id: id,
            key: key,
            modifiers: modifiers,
            handler: handler
        )

        // 移除已存在的同 ID 快捷键
        unregister(id: id)

        // 注册系统快捷键
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType("CLIP".fourCharCodeValue), id: UInt32(hotKeys.count))

        let status = RegisterEventHotKey(
            key,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKey.eventRef = ref
            hotKeys.append(hotKey)
            logger.success("快捷键已注册: \(id)")
        } else {
            logger.failure("快捷键注册失败: \(id), status: \(status)")
            // 通知用户快捷键冲突
            Task { @MainActor in
                ToastManager.shared.show(
                    "快捷键 \(id) 注册失败，可能与其他应用冲突",
                    icon: "exclamationmark.triangle.fill"
                )
                onConflict?()
            }
        }
    }

    func unregister(id: String) {
        if let index = hotKeys.firstIndex(where: { $0.id == id }) {
            let hotKey = hotKeys[index]

            if let ref = hotKey.eventRef {
                UnregisterEventHotKey(ref)
            }

            hotKeys.remove(at: index)
            logger.success("快捷键已注销: \(id)")
        }
    }

    func unregisterAll() {
        for hotKey in hotKeys {
            if let ref = hotKey.eventRef {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeys.removeAll()
        logger.success("所有快捷键已注销")
    }

    // MARK: - Setup

    private func setupEventHandler() {
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                let hotKeyService = Unmanaged<HotKeyService>.fromOpaque(userData!).takeUnretainedValue()
                return hotKeyService.handleHotKeyEvent(event!)
            },
            1,
            eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        guard isEnabled else { return noErr }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        if status == noErr {
            let index = Int(hotKeyID.id)
            if index < hotKeys.count {
                // 🔧 修复死锁：使用 DispatchQueue.main.async 避免阻塞事件循环
                let handler = hotKeys[index].handler
                DispatchQueue.main.async {
                    handler()
                }
            }
        }

        return noErr
    }
}

// MARK: - HotKey Model

class HotKey {
    let id: String
    let key: UInt32
    let modifiers: UInt32
    let handler: () -> Void
    var eventRef: EventHotKeyRef?

    init(id: String, key: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.id = id
        self.key = key
        self.modifiers = modifiers
        self.handler = handler
    }
}

// MARK: - Helpers

extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        for char in utf8.prefix(4) {
            result = result << 8 + UInt32(char)
        }
        return result
    }
}
