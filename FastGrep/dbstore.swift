//
//  dbstore.swift
//  FastGrep 快摘
//
//  Created by Drinking on 09/24/24.
//  Copyright © 2024 Drinking. All rights reserved.
//

import SQLite
import AppKit
import Foundation
import UniformTypeIdentifiers

typealias Expression = SQLite.Expression

public struct MatchedSnippet: Hashable, Identifiable {
    public var id: UUID
    public let lineNumber: Int
    public let text: String
    public let segments: [String]
    
    public init(id: UUID = UUID(), lineNumber: Int, text: String, segments: [String] = []) {
        self.id = id
        self.lineNumber = lineNumber
        self.text = text
        self.segments = segments.isEmpty ? DataStore.extractSegments(from: text) : segments
    }
}

public struct PromptItem: Hashable, Identifiable {
    public var id: UUID = UUID()
    public var name: String             // 文件名、指令名或数据库Key
    public var content: String          // 完整正文内容
    public var prompt: String           // 匹配别名或搜索词
    public var fileURL: URL?            // 如果是真实文件，关联本地URL
    public var matchedLine: String?     // 全文搜索命中的首个具体行
    public var matchedLineNumber: Int?  // 全文搜索命中的首个行号 (1-indexed)
    public var matchedSnippets: [MatchedSnippet] // 所有命中的文本段/行集合 (供单独复制)
    public var modifiedDate: Date?      // 最后修改时间
    public var isFile: Bool             // 是否为文件实体
    
    public init(
        name: String,
        content: String,
        prompt: String = "",
        fileURL: URL? = nil,
        matchedLine: String? = nil,
        matchedLineNumber: Int? = nil,
        matchedSnippets: [MatchedSnippet] = [],
        modifiedDate: Date? = nil,
        isFile: Bool = false
    ) {
        self.name = name
        self.content = content
        self.prompt = prompt
        self.fileURL = fileURL
        self.matchedLine = matchedLine
        self.matchedLineNumber = matchedLineNumber
        self.matchedSnippets = matchedSnippets
        self.modifiedDate = modifiedDate
        self.isFile = isFile
    }
}

extension PromptItem {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(id)
        hasher.combine(content)
        hasher.combine(fileURL)
    }
    
    public static func == (lhs: PromptItem, rhs: PromptItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func caption() -> String {
        if content.count <= 20 {
            return content
        }
        let index = content.index(content.startIndex, offsetBy: 20)
        return String(content[..<index])
    }
}

// MARK: - 自定义常用语/提示词数据模型 (用于设置界面可视化增删查改)
public struct CustomSnippet: Identifiable, Hashable {
    public let id: Int64
    public var prompt: String
    public var content: String
    public var date: Date
    
    public init(id: Int64, prompt: String, content: String, date: Date) {
        self.id = id
        self.prompt = prompt
        self.content = content
        self.date = date
    }
}

// MARK: - 监控目录数据模型 (支持同时管理与检索多个本地文件夹)
public struct MonitoredDirectory: Identifiable, Codable, Hashable {
    public var id: UUID
    public var path: String
    public var bookmarkData: Data
    public var name: String
    public var addedDate: Date
    public var fileCount: Int
    public var isAvailable: Bool
    
    public init(
        id: UUID = UUID(),
        path: String,
        bookmarkData: Data,
        name: String? = nil,
        addedDate: Date = Date(),
        fileCount: Int = 0,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.path = path
        self.bookmarkData = bookmarkData
        self.name = name ?? (path as NSString).lastPathComponent
        self.addedDate = addedDate
        self.fileCount = fileCount
        self.isAvailable = isAvailable
    }
}


class DataStore {
    static let DIR_TASK_DB = "PromptDB"
    static let STORE_NAME = "prompt.sqlite3"
    
    private let promptsTable = Table("prompts")
    
    private let id = Expression<Int64>("id")
    private let promptName = Expression<String>("prompt")
    private let content = Expression<String>("content")
    private let type = Expression<Int64>("type")
    private let date = Expression<Date>("date")
    
    static let shared = DataStore()
    
    private var db: Connection? = nil
    private(set) var prompts: [PromptItem] = []
    
    // 忽略目录与支持文件扩展名
    private let excludedDirNames: Set<String> = [
        ".git", ".svn", ".hg", "node_modules", "Pods", "DerivedData",
        ".build", "build", "dist", ".idea", ".vscode", ".next",
        "__pycache__", ".Trash", "xcuserdata"
    ]
    
    private let supportedExtensions: Set<String> = [
        "txt", "md", "markdown", "swift", "json", "yaml", "yml", "sh", "bash",
        "zsh", "py", "js", "ts", "jsx", "tsx", "html", "css", "sql", "xml",
        "csv", "log", "conf", "ini", "env", "toml", "c", "cpp", "h", "hpp",
        "rs", "go", "java", "kt", "rb", "php"
    ]
    
    private let maxFileSizeBytes: Int64 = 3 * 1024 * 1024 // 单文件最大 3MB
    
    private init() {
        if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let dirPath = docDir.appendingPathComponent(Self.DIR_TASK_DB)
            
            do {
                try FileManager.default.createDirectory(atPath: dirPath.path, withIntermediateDirectories: true, attributes: nil)
                let dbPath = dirPath.appendingPathComponent(Self.STORE_NAME).path
                db = try Connection(dbPath)
                createTable()
                print("SQLiteDataStore 初始化成功: \(dbPath)")
            } catch {
                db = nil
                print("SQLiteDataStore 初始化失败: \(error)")
            }
        } else {
            db = nil
        }
        
        // 异步加载已保存的目录，不阻塞主线程
        accessFolderAsync()
    }
    
    // MARK: - 文件扫描与读取
    
    private func readFiles(urls: [URL]) {
        var allPrompts: [PromptItem] = []
        for url in urls {
            if let item = readFile(url: url) {
                allPrompts.append(item)
            }
        }
        
        DispatchQueue.main.async {
            self.prompts = allPrompts
            print("📁 已建立 \(allPrompts.count) 个文本/代码文件的搜索索引")
        }
    }
    
    private func readFile(url: URL) -> PromptItem? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        // 文件大小保护
        let attrs = try? fileManager.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        if fileSize > maxFileSizeBytes {
            return nil
        }
        
        let modDate = attrs?[.modificationDate] as? Date ?? Date()
        
        // 读取完整文本
        var fullText: String? = nil
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            fullText = text
        } else if let text = try? String(contentsOf: url, encoding: .ascii) {
            fullText = text
        } else if let text = try? String(contentsOf: url, encoding: .isoLatin1) {
            fullText = text
        }
        
        guard let content = fullText, !content.isEmpty else {
            return nil
        }
        
        let fileName = url.lastPathComponent
        let baseName = url.deletingPathExtension().lastPathComponent
        
        return PromptItem(
            name: fileName,
            content: content,
            prompt: baseName,
            fileURL: url,
            matchedLine: nil,
            matchedLineNumber: nil,
            modifiedDate: modDate,
            isFile: true
        )
    }
    
    // MARK: - 多目录监控与存储管理
    
    private let monitoredDirsKey = "monitoredDirectories_v1"
    
    public func getMonitoredDirectories() -> [MonitoredDirectory] {
        var dirs: [MonitoredDirectory] = []
        if let data = UserDefaults.standard.data(forKey: monitoredDirsKey),
           let savedDirs = try? JSONDecoder().decode([MonitoredDirectory].self, from: data) {
            dirs = savedDirs
        }
        
        // 自动兼容恢复老版本单目录书签（直接解析 folderBookmark 二进制，不依赖已废弃的 folderPath 字符串）
        if let legacyBookmark = UserDefaults.standard.data(forKey: "folderBookmark") {
            var isStale = false
            var resolvedURL: URL? = nil
            do {
                resolvedURL = try URL(resolvingBookmarkData: legacyBookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            } catch {
                resolvedURL = try? URL(resolvingBookmarkData: legacyBookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            }
            
            let path = resolvedURL?.path ?? UserDefaults.standard.string(forKey: "folderPath")
            if let validPath = path, !validPath.isEmpty {
                // 如果当前列表中尚未包含该路径，则自动合并恢复
                if !dirs.contains(where: { $0.path == validPath }) {
                    let name = resolvedURL?.lastPathComponent ?? (validPath as NSString).lastPathComponent
                    let legacyDir = MonitoredDirectory(
                        path: validPath,
                        bookmarkData: legacyBookmark,
                        name: name,
                        fileCount: self.prompts.count,
                        isAvailable: true
                    )
                    dirs.append(legacyDir)
                    saveMonitoredDirectories(dirs)
                    print("已成功从老版本书签恢复监控目录: \(validPath)")
                }
            }
        }
        
        return dirs
    }
    
    private func saveMonitoredDirectories(_ dirs: [MonitoredDirectory]) {
        if let data = try? JSONEncoder().encode(dirs) {
            UserDefaults.standard.set(data, forKey: monitoredDirsKey)
        }
    }
    
    public var currentFolderPath: String? {
        getMonitoredDirectories().first?.path
    }
    
    public var indexedFilesCount: Int {
        prompts.count
    }
    
    // 打开面板添加一个或多个目录
    public func addDirectoriesViaPanel(completion: (() -> Void)? = nil) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = true
        openPanel.prompt = "添加"
        openPanel.message = "选择一个或多个要监控的本地文件夹"
        
        let response = openPanel.runModal()
        if response == .OK {
            var currentDirs = getMonitoredDirectories()
            var addedAny = false
            
            for url in openPanel.urls {
                // 如果已存在该路径则跳过
                if currentDirs.contains(where: { $0.path == url.path }) {
                    continue
                }
                
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    let newDir = MonitoredDirectory(
                        path: url.path,
                        bookmarkData: bookmarkData,
                        name: url.lastPathComponent
                    )
                    currentDirs.append(newDir)
                    addedAny = true
                    print("已成功添加监控目录: \(url.path)")
                } catch {
                    print("创建目录安全书签失败: \(error)")
                }
            }
            
            if addedAny {
                saveMonitoredDirectories(currentDirs)
                rescanAllMonitoredDirectories(completion: completion)
            } else {
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    // 移除单个监控目录
    public func removeMonitoredDirectory(id: UUID, completion: (() -> Void)? = nil) {
        var currentDirs = getMonitoredDirectories()
        if let removed = currentDirs.first(where: { $0.id == id }) {
            // 如果移除的目录正好是旧 folderBookmark 的路径，同时清理老 key 防止被重新自动恢复
            if let legacyData = UserDefaults.standard.data(forKey: "folderBookmark") {
                var isStale = false
                let u = (try? URL(resolvingBookmarkData: legacyData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale))
                    ?? (try? URL(resolvingBookmarkData: legacyData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale))
                if u?.path == removed.path {
                    UserDefaults.standard.removeObject(forKey: "folderBookmark")
                    UserDefaults.standard.removeObject(forKey: "folderPath")
                }
            }
        }
        currentDirs.removeAll(where: { $0.id == id })
        saveMonitoredDirectories(currentDirs)
        
        if currentDirs.isEmpty {
            UserDefaults.standard.removeObject(forKey: "folderBookmark")
            UserDefaults.standard.removeObject(forKey: "folderPath")
            DispatchQueue.main.async {
                self.prompts = []
                NotificationCenter.default.post(name: NSNotification.Name("MonitoredDirectoriesDidUpdate"), object: nil)
                completion?()
            }
        } else {
            rescanAllMonitoredDirectories(completion: completion)
        }
    }
    
    // 重新扫描所有监控目录
    public func rescanAllMonitoredDirectories(completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .userInitiated).async {
            var dirs = self.getMonitoredDirectories()
            var allPromptItems: [PromptItem] = []
            var seenFilePaths = Set<String>()
            
            for i in 0..<dirs.count {
                var isStale = false
                var dirFileCount = 0
                do {
                    let folderURL = try URL(
                        resolvingBookmarkData: dirs[i].bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    
                    if folderURL.startAccessingSecurityScopedResource() {
                        if isStale {
                            if let newBookmark = try? folderURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                                dirs[i].bookmarkData = newBookmark
                            }
                        }
                        let textFiles = self.getAllTextFiles(in: folderURL)
                        dirs[i].isAvailable = true
                        for fileURL in textFiles {
                            let standardPath = fileURL.standardizedFileURL.path
                            if !seenFilePaths.contains(standardPath) {
                                seenFilePaths.insert(standardPath)
                                // 在安全作用域存活期内读取正文并构建 PromptItem，避免沙盒权限收回导致读取失败
                                if let promptItem = self.readFile(url: fileURL) {
                                    allPromptItems.append(promptItem)
                                    dirFileCount += 1
                                }
                            }
                        }
                        folderURL.stopAccessingSecurityScopedResource()
                        dirs[i].fileCount = dirFileCount
                    } else {
                        dirs[i].isAvailable = false
                        dirs[i].fileCount = 0
                    }
                } catch {
                    print("解析目录书签失败 (\(dirs[i].path)): \(error)")
                    dirs[i].isAvailable = false
                    dirs[i].fileCount = 0
                }
            }
            
            self.saveMonitoredDirectories(dirs)
            
            DispatchQueue.main.async {
                self.prompts = allPromptItems
                print("📁 成功建立 \(allPromptItems.count) 个文本/代码文件的搜索索引")
                NotificationCenter.default.post(name: NSNotification.Name("MonitoredDirectoriesDidUpdate"), object: nil)
                completion?()
            }
        }
    }
    
    // 清除所有监控目录
    public func clearAllMonitoredDirectories(completion: (() -> Void)? = nil) {
        saveMonitoredDirectories([])
        UserDefaults.standard.removeObject(forKey: "folderBookmark")
        UserDefaults.standard.removeObject(forKey: "folderPath")
        DispatchQueue.main.async {
            self.prompts = []
            NotificationCenter.default.post(name: NSNotification.Name("MonitoredDirectoriesDidUpdate"), object: nil)
            completion?()
        }
    }
    
    // 兼容旧接口
    public func pickFile() {
        addDirectoriesViaPanel()
    }
    
    public func chooseFolder(completion: (() -> Void)? = nil) {
        addDirectoriesViaPanel(completion: completion)
    }
    
    public func clearFolder(completion: (() -> Void)? = nil) {
        clearAllMonitoredDirectories(completion: completion)
    }
    
    public func rescanFolder(completion: (() -> Void)? = nil) {
        rescanAllMonitoredDirectories(completion: completion)
    }
    
    func accessFolderAsync() {
        let dirs = getMonitoredDirectories()
        guard !dirs.isEmpty else {
            print("尚未配置任何监控目录")
            return
        }
        rescanAllMonitoredDirectories()
    }
    
    private func getAllTextFiles(in directory: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }
        
        var textFiles: [URL] = []
        
        for case let fileURL as URL in enumerator {
            let fileName = fileURL.lastPathComponent
            
            // 忽略隐藏文件与开发中间目录
            if excludedDirNames.contains(fileName) {
                enumerator.skipDescendants()
                continue
            }
            
            if fileName.hasPrefix(".") && !fileName.hasPrefix(".env") {
                continue
            }
            
            let ext = fileURL.pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                textFiles.append(fileURL)
            }
        }
        
        return textFiles
    }
    
    // MARK: - 数据库持久化
    
    private func createTable() {
        guard let database = db else { return }
        do {
            try database.run(promptsTable.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(promptName)
                table.column(content)
                table.column(type)
                table.column(date)
            })
        } catch {
            print("创建prompts数据表失败: \(error)")
        }
    }
    
    // MARK: - 全文检索与智能排序
    
    public func fetchFromDB(prompt: String) -> [PromptItem] {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 空搜索词状态：展示最近修改的文件 + 数据库高频提示词
        if trimmed.isEmpty {
            let sortedFiles = prompts.sorted { ($0.modifiedDate ?? .distantPast) > ($1.modifiedDate ?? .distantPast) }
            let dbPrompts = loadTopPromptsFromDB(limit: 20)
            return Array(sortedFiles.prefix(25)) + dbPrompts
        }
        
        let query = trimmed.lowercased()
        var fileNameMatches: [PromptItem] = []
        var contentMatches: [PromptItem] = []
        
        // 2. 遍历已加载的文件集合（优化：零内存分配的原生多段落检索）
        for item in prompts {
            let nameLower = item.name.lowercased()
            
            if nameLower.contains(query) {
                // 文件名命中
                var matchedItem = item
                matchedItem.prompt = trimmed
                
                // 如果正文也有搜索词，提取所有命中行供单行独立复制
                let snippets = Self.extractMatchedSnippets(in: item.content, query: trimmed, maxCount: 8)
                matchedItem.matchedSnippets = snippets
                if let first = snippets.first {
                    matchedItem.matchedLine = first.text
                    matchedItem.matchedLineNumber = first.lineNumber
                }
                fileNameMatches.append(matchedItem)
            } else if item.content.range(of: trimmed, options: [.caseInsensitive]) != nil {
                // 正文全文检索命中：提取所有匹配段落集合
                var matchedItem = item
                matchedItem.prompt = trimmed
                let snippets = Self.extractMatchedSnippets(in: item.content, query: trimmed, maxCount: 8)
                matchedItem.matchedSnippets = snippets
                if let first = snippets.first {
                    matchedItem.matchedLine = first.text
                    matchedItem.matchedLineNumber = first.lineNumber
                }
                contentMatches.append(matchedItem)
            }
        }
        
        // 正文命中项按最后修改时间排序（限制最多取前 40 项，避免渲染过量）
        contentMatches.sort { ($0.modifiedDate ?? .distantPast) > ($1.modifiedDate ?? .distantPast) }
        let limitedContentMatches = Array(contentMatches.prefix(40))
        
        // 3. SQLite 数据库提示词搜索
        let dbMatches = searchSQLite(query: trimmed)
        
        // 4. 优先级合并：文件名完全/部分匹配 > 数据库提示词 > 正文行检索
        return fileNameMatches + dbMatches + limitedContentMatches
    }
    
    // 高性能多命中行与段落提取 (供单独点击复制)
    public static func extractMatchedSnippets(in text: String, query: String, maxCount: Int = 8) -> [MatchedSnippet] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        var snippets: [MatchedSnippet] = []
        var searchStart = text.startIndex
        var currentLineNumber = 1
        var lastScannedIndex = text.startIndex
        
        while searchStart < text.endIndex && snippets.count < maxCount {
            guard let range = text.range(of: trimmed, options: [.caseInsensitive], range: searchStart..<text.endIndex) else {
                break
            }
            
            // 统计中间换行符得到当前准确行号
            for char in text[lastScannedIndex..<range.lowerBound] {
                if char == "\n" {
                    currentLineNumber += 1
                }
            }
            lastScannedIndex = range.lowerBound
            
            // 查找行起点与终点
            let lineStart = text[..<range.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
            let lineEnd = text[range.upperBound...].firstIndex(of: "\n") ?? text.endIndex
            
            let line = String(text[lineStart..<lineEnd].prefix(250)).trimmingCharacters(in: .whitespaces)
            
            if !line.isEmpty && snippets.last?.lineNumber != currentLineNumber {
                snippets.append(MatchedSnippet(lineNumber: currentLineNumber, text: line))
            }
            
            if lineEnd < text.endIndex {
                searchStart = text.index(after: lineEnd)
                currentLineNumber += 1
                lastScannedIndex = searchStart
            } else {
                break
            }
        }
        
        return snippets
    }
    
    // 智能行内分段提取（用于将账号/密码、Key/Value、逗号/空格分隔项独立拆分为可复制片段）
    public static func extractSegments(from line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        // 1. 如果整行是一个长URL且没有其他内容，不进行切分
        if (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")) && !trimmed.contains(" ") && !trimmed.contains(",") {
            return []
        }
        
        // 2. 检查是否有主要结构化分隔符：逗号、分号、竖线、制表符、换行符
        let primaryDelimiters = CharacterSet(charactersIn: ",\t\n\r;，；|")
        var rawTokens: [String] = []
        
        if trimmed.rangeOfCharacter(from: primaryDelimiters) != nil {
            let chunks = trimmed.components(separatedBy: primaryDelimiters)
            for chunk in chunks {
                let cleanChunk = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanChunk.isEmpty else { continue }
                
                // 如果块内还包含空格或冒号/等号 (例如 "user: admin" 或 "admin 123456")
                if cleanChunk.contains(" ") || cleanChunk.contains(":") || cleanChunk.contains("：") || cleanChunk.contains("=") {
                    rawTokens.append(contentsOf: splitBySpaceAndColon(cleanChunk))
                } else {
                    rawTokens.append(cleanChunk)
                }
            }
        } else {
            // 3. 仅空格、等号或冒号分隔
            rawTokens = splitBySpaceAndColon(trimmed)
            
            // 启发式过滤：如果仅靠空格拆分，且单词数较多（> 6）且均为普通纯字母单词，通常是普通英文句子而非账号密码
            if rawTokens.count > 6 && !trimmed.contains(":") && !trimmed.contains("=") && !trimmed.contains("@") {
                let hasDigitsOrSymbols = trimmed.contains { $0.isNumber || "!@#$%^&*()_+-=[]{}|<>?".contains($0) }
                if !hasDigitsOrSymbols {
                    return []
                }
            }
        }
        
        // 4. 清理与规范化 Token
        var cleaned: [String] = []
        let quoteAndPunct = CharacterSet(charactersIn: "\"'`()[]{}<>:：,，;；")
        
        for token in rawTokens {
            let t = token.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: quoteAndPunct)
            guard !t.isEmpty else { continue }
            // 过滤纯标点
            if t.allSatisfy({ ",;:=|-/\\_.~".contains($0) }) {
                continue
            }
            cleaned.append(t)
        }
        
        // 只有当至少拆分为 2 个及以上有效分段时才返回
        return cleaned.count >= 2 ? cleaned : []
    }
    
    private static func splitBySpaceAndColon(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        let chars = Array(text)
        var i = 0
        
        while i < chars.count {
            let c = chars[i]
            if c == " " || c == "\t" || c == "\n" || c == "\r" || c == "=" || c == "," || c == "，" || c == ";" || c == "；" || c == "|" {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
            } else if c == ":" || c == "：" {
                let isHttp = current.lowercased() == "http" || current.lowercased() == "https"
                if isHttp {
                    current.append(c)
                } else {
                    if !current.isEmpty {
                        tokens.append(current)
                        current = ""
                    }
                }
            } else {
                current.append(c)
            }
            i += 1
        }
        if !current.isEmpty {
            tokens.append(current)
        }
        return tokens
    }
    
    private func loadTopPromptsFromDB(limit: Int = 20) -> [PromptItem] {
        guard let database = db else { return [] }
        let sql = "SELECT * FROM prompts ORDER BY id DESC LIMIT \(limit)"
        guard let rows = try? database.prepare(sql) else { return [] }
        
        return rows.map { row in
            let name = row[1] as! String
            let text = row[2] as! String
            return PromptItem(name: name, content: text, prompt: "", isFile: false)
        }
    }
    
    private func searchSQLite(query: String) -> [PromptItem] {
        guard let database = db else { return [] }
        let escaped = query.replacingOccurrences(of: "'", with: "''")
        let sql = "SELECT * FROM prompts WHERE prompt LIKE '%\(escaped)%' OR content LIKE '%\(escaped)%' ORDER BY id DESC LIMIT 50"
        guard let rows = try? database.prepare(sql) else { return [] }
        
        return rows.map { row in
            let name = row[1] as! String
            let text = row[2] as! String
            let snippets = Self.extractMatchedSnippets(in: text, query: query, maxCount: 4)
            var item = PromptItem(name: name, content: text, prompt: query, isFile: false)
            item.matchedSnippets = snippets
            if let first = snippets.first {
                item.matchedLine = first.text
                item.matchedLineNumber = first.lineNumber
            }
            return item
        }
    }
    
    func insert(prompt: String, content: String) -> Int64? {
        guard let database = db else { return nil }
        let sql = "INSERT INTO prompts (prompt, content, type, date) VALUES (?, ?, ?, ?)"
        do {
            let statement = try database.prepare(sql)
            try statement.run(prompt, content, 1, Date().timeIntervalSince1970)
            print("数据库插入成功: \(prompt)")
            return database.lastInsertRowid
        } catch {
            print("数据库插入失败: \(error)")
            return nil
        }
    }
    
    func delete(key: String) {
        guard let database = db else { return }
        let sql = "DELETE FROM prompts WHERE prompt = ?"
        do {
            let statement = try database.prepare(sql)
            try statement.run(key)
            print("数据库删除成功: \(key)")
        } catch {
            print("数据库删除失败: \(error)")
        }
    }
    
    // MARK: - 可视化设置常用语支持
    public func loadAllPromptsFromDB() -> [CustomSnippet] {
        guard let database = db else { return [] }
        let sql = "SELECT id, prompt, content, date FROM prompts ORDER BY id DESC"
        guard let rows = try? database.prepare(sql) else { return [] }
        
        return rows.compactMap { row in
            guard let rowId = row[0] as? Int64,
                  let name = row[1] as? String,
                  let text = row[2] as? String else { return nil }
            let timestamp = (row[3] as? Double) ?? Date().timeIntervalSince1970
            return CustomSnippet(id: rowId, prompt: name, content: text, date: Date(timeIntervalSince1970: timestamp))
        }
    }
    
    @discardableResult
    public func addPrompt(key: String, value: String) -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty && !trimmedValue.isEmpty else { return false }
        return insert(prompt: trimmedKey, content: trimmedValue) != nil
    }
    
    public func deletePrompt(id: Int64) {
        guard let database = db else { return }
        let sql = "DELETE FROM prompts WHERE id = ?"
        if let statement = try? database.prepare(sql) {
            _ = try? statement.run(id)
            print("数据库根据ID删除成功: \(id)")
        }
    }
}
