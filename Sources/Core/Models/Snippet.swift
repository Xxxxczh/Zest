//
//  Snippet.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import Foundation
import SwiftData

@Model
final class Snippet {
    // MARK: - Properties

    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    // 组织
    @Relationship(deleteRule: .nullify, inverse: \Folder.snippets)
    var folder: Folder?

    var tags: [String]

    // 快捷键
    var shortcutKey: String?

    var isEnabled: Bool

    // MARK: - Init

    init(
        title: String,
        content: String,
        folder: Folder? = nil,
        tags: [String] = [],
        shortcutKey: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
        self.folder = folder
        self.tags = tags
        self.shortcutKey = shortcutKey
        self.isEnabled = true
    }

    // MARK: - Methods

    func updateContent(_ newContent: String) {
        content = newContent
        updatedAt = Date()
    }
}
