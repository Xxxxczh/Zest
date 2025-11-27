//
//  StorageService.swift
//  Zest
//
//  Created by Claude on 2025-11-25.
//

import Foundation
import SwiftData

@MainActor
final class StorageService: ObservableObject {
    // MARK: - Singleton

    static let shared = StorageService()

    // MARK: - Properties

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    @Published var recentItems: [ClipItem] = []

    private let logger = LoggerService.storage

    // MARK: - Init

    private init() {
        setupContainer()
    }

    // MARK: - Setup

    private func setupContainer() {
        do {
            let schema = Schema([
                ClipItem.self,
                Snippet.self,
                Folder.self
            ])

            guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                logger.failure("致命错误: 无法访问应用支持目录")
                return
            }

            migrateLegacyDataIfNeeded(appSupport: appSupport)

            let appDir = appSupport.appendingPathComponent(Constants.Storage.appDirectory)
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

            renameLegacyStoreIfNeeded(in: appDir)

            let storeURL = appDir.appendingPathComponent(Constants.Storage.storeName)
            logger.info("数据库路径: \(storeURL.path)")

            let modelConfiguration = ModelConfiguration(url: storeURL)

            do {
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
            } catch {
                logger.failure("SwiftData 初始化失败: \(error.localizedDescription)")
                logger.logWarning("尝试重建数据库...")

                // 备份现有数据库
                let backupURL = storeURL.appendingPathExtension("backup.\(Date().timeIntervalSince1970)")
                try? FileManager.default.copyItem(at: storeURL, to: backupURL)
                if FileManager.default.fileExists(atPath: backupURL.path) {
                    logger.info("数据库备份已保存: \(backupURL.path)")
                }

                // 删除损坏的数据库
                try FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: appDir.appendingPathComponent("\(Constants.Storage.storeName)-shm"))
                try? FileManager.default.removeItem(at: appDir.appendingPathComponent("\(Constants.Storage.storeName)-wal"))

                // 重建数据库
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
                logger.success("数据库重建成功")
            }

            guard let container = modelContainer else {
                logger.failure("致命错误: ModelContainer 未初始化")
                return
            }

            modelContext = ModelContext(container)
            logger.success("SwiftData 已初始化")

            loadRecentItems()
        } catch {
            logger.failure("致命错误: 无法创建数据库: \(error.localizedDescription)")
        }
    }

    private func migrateLegacyDataIfNeeded(appSupport: URL) {
        let legacyDir = appSupport.appendingPathComponent(Constants.Storage.legacyAppDirectory)
        let newDir = appSupport.appendingPathComponent(Constants.Storage.appDirectory)

        guard FileManager.default.fileExists(atPath: legacyDir.path),
              !FileManager.default.fileExists(atPath: newDir.path) else {
            return
        }

        logger.info("检测到旧版数据，开始迁移...")

        do {
            try FileManager.default.moveItem(at: legacyDir, to: newDir)
            logger.success("数据迁移成功")
        } catch {
            logger.failure("数据迁移失败: \(error.localizedDescription)")
        }
    }

    private func renameLegacyStoreIfNeeded(in appDir: URL) {
        let newURL = appDir.appendingPathComponent(Constants.Storage.storeName)
        let legacyURL = appDir.appendingPathComponent(Constants.Storage.legacyStoreName)

        guard !FileManager.default.fileExists(atPath: newURL.path),
              FileManager.default.fileExists(atPath: legacyURL.path) else {
            return
        }

        do {
            try FileManager.default.moveItem(at: legacyURL, to: newURL)
            logger.success("已迁移旧版数据库文件为 \(Constants.Storage.storeName)")
        } catch {
            logger.failure("数据库文件迁移失败: \(error.localizedDescription)")
        }
    }

    // MARK: - ClipItem CRUD

    func saveItem(_ item: ClipItem) {
        guard let context = modelContext else { return }

        if let existingItem = findDuplicate(of: item) {
            logger.logDebug("发现重复项，移动到顶部: \(item.preview.prefix(20))...")

            existingItem.createdAt = Date()

            if let newApp = item.sourceApp {
                existingItem.sourceApp = newApp
            }

            do {
                try context.save()
                loadRecentItems()
            } catch {
                logger.failure("更新重复项失败: \(error.localizedDescription)")
            }
            return
        }

        context.insert(item)

        do {
            try context.save()
            loadRecentItems()
            logger.logDebug("已保存新项: \(item.preview.prefix(20))... (总数: \(recentItems.count))")
            cleanupOldItems()
        } catch {
            logger.failure("保存失败: \(error.localizedDescription)")
        }
    }

    private func findDuplicate(of newItem: ClipItem) -> ClipItem? {
        return recentItems.prefix(Constants.Storage.deduplicationCheckLimit).first { existing in
            if newItem.isText && existing.isText {
                return newItem.textContent == existing.textContent
            } else if newItem.isImage && existing.isImage {
                return newItem.imageData == existing.imageData
            } else if newItem.isFile && existing.isFile {
                return newItem.fileURLs == existing.fileURLs
            }
            return false
        }
    }

    func getItem(by id: UUID) -> ClipItem? {
        guard let context = modelContext else { return nil }

        let descriptor = FetchDescriptor<ClipItem>(
            predicate: #Predicate { $0.id == id }
        )

        return try? context.fetch(descriptor).first
    }

    func getRecentItems(limit: Int = 10) -> [ClipItem] {
        Array(recentItems.prefix(limit))
    }

    func deleteItem(_ item: ClipItem) {
        guard let context = modelContext else { return }

        context.delete(item)

        do {
            try context.save()
            loadRecentItems()
        } catch {
            logger.failure("删除失败: \(error.localizedDescription)")
        }
    }

    func togglePin(_ item: ClipItem) {
        guard let context = modelContext else { return }

        item.isPinned.toggle()

        do {
            try context.save()
            loadRecentItems()
        } catch {
            logger.failure("更新固定状态失败: \(error.localizedDescription)")
        }
    }

    func clearAll() {
        guard let context = modelContext else { return }

        do {
            try context.delete(model: ClipItem.self)
            try context.save()
            recentItems = []
            logger.success("历史已清除")
        } catch {
            logger.failure("清除失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Snippet CRUD

    func saveSnippet(_ snippet: Snippet) {
        guard let context = modelContext else { return }

        context.insert(snippet)

        do {
            try context.save()
        } catch {
            logger.failure("保存代码片段失败: \(error.localizedDescription)")
        }
    }

    func getSnippets() -> [Snippet] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<Snippet>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    func deleteSnippet(_ snippet: Snippet) {
        guard let context = modelContext else { return }

        context.delete(snippet)

        do {
            try context.save()
        } catch {
            logger.failure("删除代码片段失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Folder CRUD

    func saveFolder(_ folder: Folder) {
        guard let context = modelContext else { return }

        context.insert(folder)

        do {
            try context.save()
        } catch {
            logger.failure("保存文件夹失败: \(error.localizedDescription)")
        }
    }

    func getFolders() -> [Folder] {
        guard let context = modelContext else { return [] }

        let descriptor = FetchDescriptor<Folder>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Private Methods

    private func loadRecentItems() {
        guard let context = modelContext else { return }

        var descriptor = FetchDescriptor<ClipItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = Constants.Storage.defaultMaxHistoryCount

        recentItems = (try? context.fetch(descriptor)) ?? []
    }

    private func cleanupOldItems() {
        let limit = UserDefaults.standard.integer(forKey: Constants.UserDefaultsKeys.maxHistoryCount)
        let maxCount = limit > 0 ? limit : Constants.Storage.defaultMaxHistoryCount

        guard let context = modelContext else { return }

        // 分别统计固定项和非固定项
        let unpinnedItems = recentItems.filter { !$0.isPinned }

        // 只有非固定项超过限制时才清理
        guard unpinnedItems.count > maxCount else { return }

        logger.logDebug("清理旧数据 (非固定项: \(unpinnedItems.count), 限制: \(maxCount))")

        // 删除最旧的非固定项
        let itemsToDelete = unpinnedItems.suffix(unpinnedItems.count - maxCount)

        for item in itemsToDelete {
            context.delete(item)
        }

        do {
            try context.save()
            loadRecentItems()
            logger.success("已清理 \(itemsToDelete.count) 个旧项")
        } catch {
            logger.failure("清理旧数据失败: \(error.localizedDescription)")
        }
    }
}
