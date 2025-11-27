//
//  ClipboardService.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import AppKit
import Combine
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics
import Foundation

@MainActor
final class ClipboardService: ObservableObject {
    // MARK: - Singleton

    static let shared = ClipboardService()

    // MARK: - Properties

    private var timer: Timer?
    private var isAppActive = true
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    private let clipboardSubject = PassthroughSubject<ClipItem, Never>()
    var clipboardPublisher: AnyPublisher<ClipItem, Never> {
        clipboardSubject.eraseToAnyPublisher()
    }

    @Published var isMonitoring = false
    @Published var isAuthorized = false

    private let storageService = StorageService.shared
    private let errorHandler = ErrorHandler.shared
    private let logger = LoggerService.clipboard
    private let defaults = UserDefaults.standard

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    func startMonitoring() {
        guard !isMonitoring else { return }
        guard isAuthorized else {
            logger.logWarning("权限未授予，暂不启动剪贴板监听")
            return
        }

        isMonitoring = true
        lastChangeCount = NSPasteboard.general.changeCount
        configureTimer()
        logger.success("剪贴板监听已启动")
    }

    func refreshPollingInterval() {
        guard isMonitoring else { return }
        configureTimer()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
        logger.info("剪贴板监听已停止")
    }

    func setAuthorization(granted: Bool) {
        isAuthorized = granted
        if granted {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    func pasteItem(withId id: UUID) async throws {
        guard let item = storageService.getItem(by: id) else {
            throw ZestError.itemNotFound
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var success = false

        if let text = item.textContent {
            success = pasteboard.setString(text, forType: .string)
        } else if let imageData = item.imageData,
                  let image = NSImage(data: imageData) {
            success = pasteboard.writeObjects([image])
        } else if let urls = item.fileURLs {
            success = pasteboard.writeObjects(urls as [NSURL])
        }

        if success {
            lastChangeCount = pasteboard.changeCount
            simulatePaste()
        } else {
            throw ZestError.pasteFailure
        }
    }

    // MARK: - Private Methods

    private var currentPollingInterval: TimeInterval {
        let interval = defaults.double(forKey: Constants.UserDefaultsKeys.pollingInterval)
        return interval > 0 ? interval : Constants.Timing.clipboardPollingInterval
    }

    private func configureTimer() {
        guard isAuthorized else { return }

        timer?.invalidate()

        var interval = max(0.1, currentPollingInterval)

        // 简单自适应：应用非活跃时放缓轮询，降低负载
        if !isAppActive {
            interval = max(interval, 1.0)
        }

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkClipboard()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // 调用于 App 活跃/失活时
    func updateAppActive(_ active: Bool) {
        isAppActive = active
        if isMonitoring && isAuthorized {
            configureTimer()
        }
    }

    private func checkClipboard() async {
        let currentCount = NSPasteboard.general.changeCount

        guard currentCount != lastChangeCount else { return }

        lastChangeCount = currentCount

        // 处理剪贴板内容
        if let clipItem = await processClipboard() {
            // 保存到数据库
            storageService.saveItem(clipItem)

            // 发布通知
            clipboardSubject.send(clipItem)
        }
    }

    private func processClipboard() async -> ClipItem? {
        let pasteboard = NSPasteboard.general

        let fileURLs = extractFileURLs(from: pasteboard) ?? []
        let imageFileURLs = fileURLs.filter { isImageURL($0) }
        let nonImageFileURLs = fileURLs.filter { !isImageURL($0) }

        // 1) 优先处理图片：来自粘贴板数据或图片文件 URL
        var imageData = extractImageData(from: pasteboard)
        if imageData == nil, let url = imageFileURLs.first {
            imageData = try? Data(contentsOf: url)
        }
        if let imageData, let processed = await compressImageData(imageData) {
            return ClipItem(
                preview: "🖼️ 图片",
                dataType: ClipItemType.image.rawValue,
                imageData: processed.full,
                thumbnailData: processed.thumbnail,
                sourceApp: getCurrentAppName()
            )
        }

        // 2) 处理文件（非图片）
        if !nonImageFileURLs.isEmpty {
            let fileNames = nonImageFileURLs.map { $0.lastPathComponent }.joined(separator: ", ")
            return ClipItem(
                preview: "📁 \(fileNames)",
                dataType: ClipItemType.file.rawValue,
                fileURLs: nonImageFileURLs,
                sourceApp: getCurrentAppName()
            )
        }

        // 3) 处理文本
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            let preview = String(string.prefix(Constants.UI.previewTextLimit))
            return ClipItem(
                preview: preview,
                dataType: ClipItemType.text.rawValue,
                textContent: string,
                sourceApp: getCurrentAppName()
            )
        }

        return nil
    }

    private func extractFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        // 优先使用系统文件 URL 读取
        if pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]),
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            let fileURLs = urls.filter { $0.isFileURL }
            if !fileURLs.isEmpty {
                return fileURLs
            }
        }

        // 兜底：直接解析 PasteboardItems 中的 fileURL 字符串
        if let items = pasteboard.pasteboardItems {
            let urls = items.compactMap { $0.string(forType: .fileURL) }.compactMap { URL(string: $0) }
            let fileURLs = urls.filter { $0.isFileURL }
            if !fileURLs.isEmpty {
                return fileURLs
            }
        }

        return nil
    }

    private func extractImageData(from pasteboard: NSPasteboard) -> Data? {
        // 先尝试标准方式
        if pasteboard.canReadObject(forClasses: [NSImage.self], options: nil),
           let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation {
            return tiff
        }

        // 兜底读取原始数据
        if let tiff = pasteboard.data(forType: .tiff) {
            return tiff
        }
        if let png = pasteboard.data(forType: .png) {
            return png
        }
        if let fileContents = pasteboard.data(forType: .fileContents) { // 某些应用会以文件内容形式提供图片
            return fileContents
        }
        return nil
    }

    private func isImageURL(_ url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .image)
        }

        if let ext = url.pathExtension.lowercased() as String?,
           let type = UTType(filenameExtension: ext) {
            return type.conforms(to: .image)
        }

        return false
    }

    private func compressImageData(_ tiffData: Data) async -> (full: Data, thumbnail: Data)? {
        await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(tiffData as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                return nil
            }

            let fullMax: CGFloat = 1440
            let thumbMax: CGFloat = 256

            guard let fullImage = cgImage.scaled(toMax: fullMax),
                  let thumbImage = cgImage.scaled(toMax: thumbMax),
                  let fullData = fullImage.jpegData(quality: 0.85),
                  let thumbData = thumbImage.jpegData(quality: 0.7) else {
                return nil
            }

            return (fullData, thumbData)
        }.value
    }

    private func getCurrentAppName() -> String? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return frontmostApp.localizedName
    }

    private func simulatePaste() {
        if !AXIsProcessTrusted() {
            logger.logWarning("缺少辅助功能权限，无法模拟粘贴")
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
            return
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        vKeyDown?.flags = .maskCommand
        vKeyUp?.flags = .maskCommand

        vKeyDown?.post(tap: .cghidEventTap)
        vKeyUp?.post(tap: .cghidEventTap)
    }
}

// MARK: - CGImage Helpers

private extension CGImage {
    func scaled(toMax maxLength: CGFloat) -> CGImage? {
        let width = CGFloat(self.width)
        let height = CGFloat(self.height)
        let maxSide = max(width, height)
        let scale = maxSide > maxLength ? maxLength / maxSide : 1.0
        let targetSize = CGSize(width: width * scale, height: height * scale)

        guard let colorSpace = self.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: Int(targetSize.width),
                height: Int(targetSize.height),
                bitsPerComponent: self.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: self.bitmapInfo.rawValue
              ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(self, in: CGRect(origin: .zero, size: targetSize))
        return context.makeImage()
    }

    func jpegData(quality: CGFloat) -> Data? {
        guard let data = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                data,
                UTType.jpeg.identifier as CFString,
                1,
                nil
              ) else {
            return nil
        }

        let options = [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        CGImageDestinationAddImage(destination, self, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
