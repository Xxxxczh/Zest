//
//  ClipItem.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - ClipItemType Enum

enum ClipItemType: String, Codable {
    case text
    case image
    case file

    var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
}

// MARK: - ClipItem Model

@Model
final class ClipItem {
    // MARK: - Properties

    var id: UUID
    var createdAt: Date
    var preview: String  // 文本预览
    var dataType: String  // 数据类型 (text, image, file, etc.)

    // 数据存储
    var textContent: String?
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var fileURLs: [URL]?

    // 元数据
    var sourceApp: String?  // 来源应用
    var isPinned: Bool  // 是否固定

    // MARK: - Init

    init(
        preview: String,
        dataType: String,
        textContent: String? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        fileURLs: [URL]? = nil,
        sourceApp: String? = nil
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.preview = preview

        // 验证 dataType 是否有效
        if ClipItemType(rawValue: dataType) == nil {
            print("⚠️ 无效的 dataType: \(dataType)，使用默认值 'text'")
            self.dataType = ClipItemType.text.rawValue
        } else {
            self.dataType = dataType
        }

        self.textContent = textContent
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.fileURLs = fileURLs
        self.sourceApp = sourceApp
        self.isPinned = false
    }

    // MARK: - Helpers

    var isText: Bool {
        dataType == ClipItemType.text.rawValue
    }

    var isImage: Bool {
        dataType == ClipItemType.image.rawValue
    }

    var isFile: Bool {
        dataType == ClipItemType.file.rawValue
    }

    var iconName: String {
        ClipItemType(rawValue: dataType)?.iconName ?? "questionmark"
    }
}
