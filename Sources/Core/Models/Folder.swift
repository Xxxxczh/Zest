//
//  Folder.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import Foundation
import SwiftData

@Model
final class Folder {
    // MARK: - Properties

    var id: UUID
    var name: String
    var createdAt: Date

    // 关联的代码片段
    @Relationship(deleteRule: .cascade)
    var snippets: [Snippet]

    var sortOrder: Int

    // MARK: - Init

    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.snippets = []
        self.sortOrder = sortOrder
    }

    // MARK: - Computed

    var snippetCount: Int {
        snippets.count
    }

    var enabledSnippets: [Snippet] {
        snippets.filter { $0.isEnabled }
    }
}
