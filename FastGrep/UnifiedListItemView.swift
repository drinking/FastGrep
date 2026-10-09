//
//  UnifiedListItemView.swift
//  FastGrep 快摘
//
//  Created by Drinking on 10/24/25.
//  Copyright © 2024 Drinking. All rights reserved.
//

import SwiftUI

// 统一的列表项数据协议
protocol ListItemData: Identifiable, Hashable {
    var id: UUID { get }
    var title: String { get }
    var subtitle: String { get }
    var systemIcon: String { get }
    var itemTimestamp: Date? { get }
    var metadata: String? { get }
    var isFavorite: Bool { get }
    var useCount: Int { get }
    var iconColor: Color { get }
}

// 为 PromptItem 实现协议
extension PromptItem: ListItemData {
    var title: String { name }
    var subtitle: String { content }
    var systemIcon: String { "command" }
    var itemTimestamp: Date? { nil }
    var metadata: String? { nil }
    var isFavorite: Bool { false }
    var useCount: Int { 0 }
    var iconColor: Color { .blue }
}

// 扩展 ClipboardItem 以符合 ListItemData 协议
extension ClipboardItem: ListItemData {
    var title: String { content.prefix(50) + (content.count > 50 ? "..." : "") }
    var subtitle: String { content }
    var systemIcon: String { "doc.text" }
    var itemTimestamp: Date? { timestamp }
    var metadata: String? { nil }
    var iconColor: Color { .green }
    
    // 注意：ClipboardItem 已经有 isFavorite: Bool, useCount: Int 属性
    // 这些会自动满足协议要求
}

// 统一的列表项视图
struct UnifiedListItemView<Item: ListItemData>: View {
    let item: Item
    let searchQuery: String
    let onAction: () -> Void
    let onSecondaryAction: (() -> Void)?
    
    @State private var isHovering = false
    
    init(
        item: Item,
        searchQuery: String = "",
        onAction: @escaping () -> Void,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        self.item = item
        self.searchQuery = searchQuery
        self.onAction = onAction
        self.onSecondaryAction = onSecondaryAction
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: item.systemIcon)
                .font(.title3)
                .foregroundColor(item.iconColor)
                .frame(width: 24)
            
            // 内容区域
            VStack(alignment: .leading, spacing: 4) {
                // 标题（带搜索高亮）
                highlightedText(text: item.title, searchText: searchQuery)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
                
                // 副标题
                if !item.subtitle.isEmpty && item.subtitle != item.title {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // 元信息行
                HStack(spacing: 8) {
                    // 时间戳
                    if let timestamp = item.itemTimestamp {
                        Text(timeAgoString(from: timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // 额外元数据
                    if let metadata = item.metadata, !metadata.isEmpty {
                        Text("• \(metadata)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 收藏图标
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                    
                    // 使用次数
                    if item.useCount > 0 {
                        Text("\(item.useCount)×")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮（hover时显示）
            if isHovering {
                HStack(spacing: 8) {
                    // 主要操作按钮
                    Button(action: onAction) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("复制")
                    
                    // 次要操作按钮（如果提供）
                    if let secondaryAction = onSecondaryAction {
                        Button(action: secondaryAction) {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("更多选项")
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onAction()
        }
    }
    
    // MARK: - 辅助方法
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func highlightedText(text: String, searchText: String) -> Text {
        guard !searchText.isEmpty else {
            return Text(text)
        }
        
        // 尝试完全匹配优先
        if let range = text.range(of: searchText, options: [.caseInsensitive]) {
            let beforeRange = String(text[..<range.lowerBound])
            let matchRange = String(text[range])
            let afterRange = String(text[range.upperBound...])
            
            return Text(beforeRange) +
                   Text(matchRange).foregroundColor(.yellow).fontWeight(.bold) +
                   Text(afterRange)
        }
        
        // 字符级匹配（为 PromptItem 保留原有行为）
        var textList: [Text] = []
        var nameCopy = text
        
        for char in searchText {
            if let index = nameCopy.firstIndex(of: char) {
                let front = nameCopy[..<index]
                if !front.isEmpty {
                    textList.append(Text(String(front)))
                }
                textList.append(Text(String(char)).foregroundColor(.yellow).fontWeight(.bold))
                
                let nextIndex = nameCopy.index(after: index)
                nameCopy = String(nameCopy[nextIndex...])
            }
        }
        
        if !nameCopy.isEmpty {
            textList.append(Text(nameCopy))
        }
        
        return textList.reduce(Text("")) { $0 + $1 }
    }
}

// 统一的列表容器视图
struct UnifiedListView<Item: ListItemData>: View {
    let items: [Item]
    let searchQuery: String
    let emptyStateTitle: String
    let emptyStateSubtitle: String
    let emptyStateIcon: String
    let onItemAction: (Item) -> Void
    let onItemSecondaryAction: ((Item) -> Void)?
    
    @Binding var focusedItem: Item?
    @FocusState private var isListFocused: Bool
    @State private var currentFocusIndex: Int = 0
    
    var body: some View {
        Group {
            if !items.isEmpty {
                ScrollViewReader { proxy in
                    List(items, id: \.id, selection: $focusedItem) { item in
                        UnifiedListItemView(
                            item: item,
                            searchQuery: searchQuery,
                            onAction: { onItemAction(item) },
                            onSecondaryAction: onItemSecondaryAction != nil ? { onItemSecondaryAction!(item) } : nil
                        )
                        .padding(.vertical, 2)
                        .id(item.id)
                    }
                    .listStyle(.plain)
                    .focused($isListFocused)
                    .onKeyPress(keys: [.return, .tab]) { pressed in
                        if pressed.key == .tab {
                            updateFocusedItem()
                            return .handled
                        }
                        
                        if let focused = focusedItem {
                            onItemAction(focused)
                        }
                        return .handled
                    }
                    .onChange(of: focusedItem) { _, newValue in
                        if let item = newValue {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                }
            } else {
                // 空状态
                VStack(spacing: 16) {
                    Image(systemName: emptyStateIcon)
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text(emptyStateTitle)
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    Text(emptyStateSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }
    
    private func updateFocusedItem() {
        guard !items.isEmpty else { return }
        
        focusedItem = items[currentFocusIndex]
        currentFocusIndex = (currentFocusIndex + 1) % items.count
        
        if currentFocusIndex == 0 {
            isListFocused = false
        }
    }
    
    func setFocus(to index: Int) {
        guard !items.isEmpty, index < items.count else { return }
        currentFocusIndex = index
        focusedItem = items[index]
        isListFocused = true
    }
}

// MARK: - 现代毛玻璃效果支持
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - 统一列表展示项模型
enum UnifiedItemSource: Hashable {
    case prompt(PromptItem)
    case clipboard(ClipboardItem)
}

struct UnifiedDisplayItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let fullContent: String
    let systemIcon: String
    let iconColor: Color
    let categoryName: String
    let timestamp: Date?
    let sourceApp: String?
    let fileURL: URL?
    let matchedLine: String?
    let matchedLineNumber: Int?
    let matchedSnippets: [MatchedSnippet]
    let isFavorite: Bool
    let useCount: Int
    let underlyingSource: UnifiedItemSource
    
    init(
        id: UUID,
        title: String,
        subtitle: String,
        fullContent: String,
        systemIcon: String,
        iconColor: Color,
        categoryName: String,
        timestamp: Date?,
        sourceApp: String?,
        fileURL: URL?,
        matchedLine: String?,
        matchedLineNumber: Int?,
        matchedSnippets: [MatchedSnippet] = [],
        isFavorite: Bool,
        useCount: Int,
        underlyingSource: UnifiedItemSource
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.fullContent = fullContent
        self.systemIcon = systemIcon
        self.iconColor = iconColor
        self.categoryName = categoryName
        self.timestamp = timestamp
        self.sourceApp = sourceApp
        self.fileURL = fileURL
        self.matchedLine = matchedLine
        self.matchedLineNumber = matchedLineNumber
        self.matchedSnippets = matchedSnippets
        self.isFavorite = isFavorite
        self.useCount = useCount
        self.underlyingSource = underlyingSource
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(fileURL)
    }
    
    static func == (lhs: UnifiedDisplayItem, rhs: UnifiedDisplayItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension PromptItem {
    func toUnifiedDisplayItem() -> UnifiedDisplayItem {
        let isCmd = name.hasPrefix(":")
        let isTpl = name.hasPrefix("/")
        
        let icon: String
        let color: Color
        let cat: String
        
        if isFile {
            let ext = (fileURL?.pathExtension ?? "").lowercased()
            switch ext {
            case "md", "markdown":
                icon = "doc.richtext"
                color = .purple
                cat = "Markdown"
            case "swift":
                icon = "swift"
                color = .orange
                cat = "Swift"
            case "py":
                icon = "chevron.left.forwardslash.chevron.right"
                color = .blue
                cat = "Python"
            case "js", "ts", "jsx", "tsx":
                icon = "chevron.left.forwardslash.chevron.right"
                color = .yellow
                cat = "Code"
            case "json", "yaml", "yml", "xml", "toml":
                icon = "curlybraces"
                color = .teal
                cat = "Config"
            case "sh", "bash", "zsh":
                icon = "terminal.fill"
                color = .green
                cat = "Shell"
            default:
                icon = "doc.text.fill"
                color = .indigo
                cat = ext.isEmpty ? "文本" : ext.uppercased()
            }
        } else if isCmd {
            icon = "terminal.fill"
            color = .purple
            cat = "指令"
        } else if isTpl {
            icon = "text.badge.plus"
            color = .orange
            cat = "模板"
        } else {
            icon = "text.bubble.fill"
            color = .blue
            cat = "提示词"
        }
        
        let subtitleText: String
        if let line = matchedLine, let lineNum = matchedLineNumber {
            subtitleText = "第 \(lineNum) 行: \(line)"
        } else if isFile {
            subtitleText = content.prefix(100).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
        } else {
            subtitleText = content
        }
        
        var resolvedFileURL = fileURL
        if resolvedFileURL == nil {
            if isFile, let p = DataStore.shared.prompts.first(where: { $0.name == name })?.fileURL {
                resolvedFileURL = p
            } else {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                let firstLine = trimmed.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if firstLine.hasPrefix("file://"), let u = URL(string: firstLine) {
                    resolvedFileURL = u
                } else if (firstLine.hasPrefix("/") || firstLine.hasPrefix("~")) && !firstLine.contains("\n") && (firstLine.hasPrefix("/Users/") || firstLine.hasPrefix("/Applications/") || firstLine.contains("/")) {
                    resolvedFileURL = URL(fileURLWithPath: (firstLine as NSString).expandingTildeInPath)
                }
            }
        }
        
        return UnifiedDisplayItem(
            id: id,
            title: name,
            subtitle: subtitleText,
            fullContent: content.isEmpty ? name : content,
            systemIcon: icon,
            iconColor: color,
            categoryName: cat,
            timestamp: modifiedDate,
            sourceApp: isFile ? (resolvedFileURL?.deletingLastPathComponent().lastPathComponent ?? "文件") : nil,
            fileURL: resolvedFileURL,
            matchedLine: matchedLine,
            matchedLineNumber: matchedLineNumber,
            matchedSnippets: matchedSnippets,
            isFavorite: false,
            useCount: 0,
            underlyingSource: .prompt(self)
        )
    }
}

extension ClipboardItem {
    func toUnifiedDisplayItem(searchQuery: String = "") -> UnifiedDisplayItem {
        let color: Color
        switch type {
        case .text: color = .primary
        case .url: color = .blue
        case .file: color = .orange
        case .image: color = .purple
        case .color: color = .pink
        }
        
        var fileURL: URL? = nil
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmedContent.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        if type == .file {
            if firstLine.hasPrefix("file://"), let url = URL(string: firstLine) {
                fileURL = url
            } else if firstLine.hasPrefix("/") {
                fileURL = URL(fileURLWithPath: firstLine)
            } else if firstLine.hasPrefix("~") {
                let expanded = (firstLine as NSString).expandingTildeInPath
                fileURL = URL(fileURLWithPath: expanded)
            }
        } else if firstLine.hasPrefix("file://"), let url = URL(string: firstLine) {
            fileURL = url
        } else if (firstLine.hasPrefix("/") || firstLine.hasPrefix("~")) && !firstLine.contains("\n") && (firstLine.hasPrefix("/Users/") || firstLine.hasPrefix("/Applications/") || firstLine.hasPrefix("/System/") || firstLine.hasPrefix("/Volumes/") || firstLine.contains("/")) {
            let expanded = (firstLine as NSString).expandingTildeInPath
            fileURL = URL(fileURLWithPath: expanded)
        }
        
        let snippets = !searchQuery.isEmpty ? DataStore.extractMatchedSnippets(in: content, query: searchQuery, maxCount: 6) : []
        
        return UnifiedDisplayItem(
            id: id,
            title: preview,
            subtitle: content,
            fullContent: content,
            systemIcon: type.systemIcon,
            iconColor: color,
            categoryName: type.displayName,
            timestamp: timestamp,
            sourceApp: source,
            fileURL: fileURL,
            matchedLine: snippets.first?.text,
            matchedLineNumber: snippets.first?.lineNumber,
            matchedSnippets: snippets,
            isFavorite: isFavorite,
            useCount: useCount,
            underlyingSource: .clipboard(self)
        )
    }
}

// MARK: - 左侧列表行组件 (Master Row)
struct MasterRowView: View {
    let item: UnifiedDisplayItem
    let isSelected: Bool
    let searchQuery: String
    let onSelect: () -> Void
    let onAction: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 10) {
            // 类型图标容器
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(item.iconColor.opacity(isSelected ? 0.25 : 0.12))
                    .frame(width: 28, height: 28)
                
                Image(systemName: item.systemIcon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(item.iconColor)
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    highlightedText(text: item.title, searchText: searchQuery)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if item.useCount > 0 {
                        Text("\(item.useCount)×")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                }
                
                // 行匹配 (Grep) 或副标题预览
                if let line = item.matchedLine, let lineNum = item.matchedLineNumber {
                    HStack(spacing: 4) {
                        Text("L\(lineNum):")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                        highlightedText(text: line, searchText: searchQuery)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        if item.matchedSnippets.count > 1 {
                            Spacer(minLength: 2)
                            Text("+\(item.matchedSnippets.count - 1)")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.yellow.opacity(0.18))
                                .foregroundColor(.yellow)
                                .cornerRadius(3)
                        }
                    }
                } else if !item.subtitle.isEmpty && item.subtitle != item.title {
                    Text(item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " "))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // 底部标签与元数据
                HStack(spacing: 6) {
                    Text(item.categoryName)
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(item.iconColor.opacity(0.12))
                        .foregroundColor(item.iconColor)
                        .cornerRadius(3)
                    
                    if let ts = item.timestamp {
                        Text(formatTimeAgo(ts))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    
                    if let source = item.sourceApp {
                        Text("• \(source)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : (isHovering ? Color.gray.opacity(0.08) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            onAction()
        })
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func highlightedText(text: String, searchText: String) -> Text {
        guard !searchText.isEmpty else {
            return Text(text)
        }
        
        if let range = text.range(of: searchText, options: [.caseInsensitive]) {
            let before = String(text[..<range.lowerBound])
            let match = String(text[range])
            let after = String(text[range.upperBound...])
            
            return Text(before) +
                   Text(match).foregroundColor(.yellow).bold() +
                   Text(after)
        }
        
        return Text(text)
    }
}

// MARK: - 右侧详情预览组件 (Detail Preview)
struct DetailPreviewView: View {
    let item: UnifiedDisplayItem?
    var searchQuery: String = ""
    let onCopy: () -> Void
    var onCopySnippet: ((String, Int) -> Void)? = nil
    var onCopySegment: ((String) -> Void)? = nil
    var onRevealInFinder: ((URL) -> Void)? = nil
    var onOpenFile: ((URL) -> Void)? = nil
    
    private var effectiveFileURL: URL? {
        if let url = item?.fileURL {
            return url
        }
        guard let item = item else { return nil }
        
        // 1. 底层 PromptItem 文件路径
        if case .prompt(let p) = item.underlyingSource, let url = p.fileURL {
            return url
        }
        
        // 2. 尝试从已建立索引的监控目录中根据文件名匹配
        if let matched = DataStore.shared.prompts.first(where: { $0.name == item.title }), let url = matched.fileURL {
            return url
        }
        
        // 3. 从 content 或 fullContent 提取本地路径或 file:// URL
        let trimmed = item.fullContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = trimmed.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if firstLine.hasPrefix("file://"), let url = URL(string: firstLine) {
            return url
        }
        if (firstLine.hasPrefix("/") || firstLine.hasPrefix("~")) && !firstLine.contains("\n") {
            let expanded = (firstLine as NSString).expandingTildeInPath
            if expanded.hasPrefix("/Users/") || expanded.hasPrefix("/Applications/") || expanded.contains("/") {
                return URL(fileURLWithPath: expanded)
            }
        }
        
        return nil
    }
    
    var body: some View {
        if let item = item {
            VStack(alignment: .leading, spacing: 8) {
                // 头部卡片
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.iconColor.opacity(0.18))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: item.systemIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(item.iconColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        
                        HStack(spacing: 6) {
                            Text(item.categoryName)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.iconColor.opacity(0.15))
                                .foregroundColor(item.iconColor)
                                .cornerRadius(4)
                            
                            if let ts = item.timestamp {
                                Text(formattedFullDate(ts))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            if let source = item.sourceApp {
                                Text("📁 \(source)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 操作按钮组
                    HStack(spacing: 6) {
                        if let fileURL = effectiveFileURL {
                            
                            // 打开文件目录按钮（位于复制按钮左侧）
                            Button(action: {
                                onRevealInFinder?(fileURL) ?? {
                                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                                }()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 10))
                                    Text("打开文件目录")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.bordered)
                            .help("在访达中定位并打开该文件所在目录 (⌘Return)")
                        }
                        
                        // 翻译按钮
                        Button(action: {
                            TranslationWindowController.shared.showTranslation(initialText: item.fullContent)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "character.bubble")
                                    .font(.system(size: 10))
                                Text("翻译")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .help("使用本地 Ollama 模型翻译此内容")
                        
                        // 复制按钮
                        Button(action: onCopy) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 10))
                                Text("复制")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .help("复制内容到剪贴板")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                
                // 如果是文件，显示清晰可点击的文件路径条
                if let fileURL = effectiveFileURL {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue.opacity(0.8))
                        
                        Text(fileURL.path)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button("在访达中显示 ↗") {
                            onRevealInFinder?(fileURL) ?? {
                                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                            }()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(6)
                    .padding(.horizontal, 14)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onRevealInFinder?(fileURL) ?? {
                            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                        }()
                    }
                }
                
                Divider()
                
                // 检索命中段落集合展示（支持各行独立点击复制及行内分段提取）
                if !item.matchedSnippets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.magnifyingglass")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow)
                            Text("检索命中段落 (\(item.matchedSnippets.count) 处)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary)
                            Text("• 点击整行或单独点击分段(如账号/密码)复制")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 2)
                        
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 6) {
                                ForEach(item.matchedSnippets) { snippet in
                                    SnippetRowView(
                                        snippet: snippet,
                                        searchQuery: searchQuery,
                                        onCopy: { text, lineNum in
                                            onCopySnippet?(text, lineNum)
                                        },
                                        onCopySegment: { segText in
                                            onCopySegment?(segText)
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: item.matchedSnippets.count > 2 ? 160 : CGFloat(item.matchedSnippets.count * 52))
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.yellow.opacity(0.25), lineWidth: 1)
                    )
                    .padding(.horizontal, 14)
                } else if let line = item.matchedLine, let lineNum = item.matchedLineNumber {
                    let fallbackSnippet = MatchedSnippet(lineNumber: lineNum, text: line)
                    SnippetRowView(
                        snippet: fallbackSnippet,
                        searchQuery: searchQuery,
                        onCopy: { text, lineNum in
                            onCopySnippet?(text, lineNum)
                        },
                        onCopySegment: { segText in
                            onCopySegment?(segText)
                        }
                    )
                    .padding(.horizontal, 14)
                } else {
                    // 没有检索词时，如果正文包含可提取的账号密码等分段
                    let quickSegments = DataStore.extractSegments(from: String(item.fullContent.prefix(500)))
                    if !quickSegments.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.split.2x1")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.yellow)
                            Text("快速提取分段:")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.primary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 5) {
                                    ForEach(quickSegments, id: \.self) { seg in
                                        SegmentChipView(
                                            text: seg,
                                            onCopy: { text in
                                                onCopySegment?(text)
                                            }
                                        )
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.yellow.opacity(0.12))
                        .cornerRadius(6)
                        .padding(.horizontal, 14)
                    }
                }
                
                // 元信息统计栏
                HStack(spacing: 12) {
                    Text("\(item.fullContent.count) 字符")
                    Text("•")
                    Text("\(item.fullContent.components(separatedBy: "\n").count) 行")
                    if item.fullContent.utf8.count > 0 {
                        Text("•")
                        Text(ByteCountFormatter.string(fromByteCount: Int64(item.fullContent.utf8.count), countStyle: .memory))
                    }
                    Spacer()
                    
                    if item.systemIcon == "link", let url = URL(string: item.fullContent.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        Button(action: {
                            NSWorkspace.shared.open(url)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "safari")
                                Text("在浏览器打开")
                            }
                            .font(.system(size: 10))
                        }
                        .buttonStyle(.link)
                    }
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                
                // 正文内容查看区域（支持行号展示与行高亮）
                contentViewer(for: item)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // 空状态预览
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundColor(.secondary.opacity(0.5))
                
                Text("暂无选中内容")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("从左侧选择文件或条目查看详细内容，或输入关键词进行全局搜索")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
    
    @ViewBuilder
    private func contentViewer(for item: UnifiedDisplayItem) -> some View {
        ScrollView {
            Text(item.fullContent)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(10)
        }
        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
    
    private func formattedFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 独立分段复制芯片组件 (账号、密码、Token等)
struct SegmentChipView: View {
    let text: String
    let onCopy: (String) -> Void
    
    @State private var isHovering = false
    @State private var isCopied = false
    
    var body: some View {
        Button(action: copySegment) {
            HStack(spacing: 3) {
                if isCopied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green)
                    Text("已复制")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 8))
                        .foregroundColor(isHovering ? .accentColor : .secondary)
                    Text(text)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isHovering ? .accentColor : .primary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isCopied ? Color.green.opacity(0.18) : (isHovering ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.1)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isCopied ? Color.green.opacity(0.5) : (isHovering ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.2)), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("点击单独复制该段: \"\(text)\"")
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func copySegment() {
        onCopy(text)
        withAnimation(.easeInOut(duration: 0.15)) {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCopied = false
            }
        }
    }
}

// MARK: - 检索命中单行独立复制组件
struct SnippetRowView: View {
    let snippet: MatchedSnippet
    let searchQuery: String
    let onCopy: (String, Int) -> Void
    var onCopySegment: ((String) -> Void)? = nil
    
    @State private var isHovering = false
    @State private var isLineCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 主行：行号 + 命中文本 + 复制整行按钮
            HStack(alignment: .center, spacing: 8) {
                // 行号指示器
                Text("L\(snippet.lineNumber)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isHovering ? .yellow : .yellow.opacity(0.85))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(4)
                
                // 文本内容（搜索关键词高亮，支持鼠标自由选词划词）
                highlightedSnippetText(snippet.text, searchQuery: searchQuery)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                
                // 复制整行按钮
                Button(action: copyWholeLine) {
                    HStack(spacing: 3) {
                        if isLineCopied {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                            Text("已复制")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundColor(isHovering ? .accentColor : .secondary)
                            Text("复制整行")
                                .font(.system(size: 9))
                                .foregroundColor(isHovering ? .accentColor : .secondary)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isLineCopied ? Color.green.opacity(0.15) : (isHovering ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.1)))
                    )
                }
                .buttonStyle(.plain)
                .help("点击复制第 \(snippet.lineNumber) 行完整内容")
            }
            
            // 次行：行内分段提取（如果包含逗号、空格、冒号分隔的账号/密码等段落）
            if !snippet.segments.isEmpty {
                HStack(spacing: 5) {
                    HStack(spacing: 2) {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.system(size: 8))
                        Text("分段:")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(snippet.segments, id: \.self) { seg in
                                SegmentChipView(
                                    text: seg,
                                    onCopy: { text in
                                        onCopySegment?(text)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isLineCopied ? Color.green.opacity(0.08) : (isHovering ? Color.yellow.opacity(0.08) : Color.gray.opacity(0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isLineCopied ? Color.green.opacity(0.4) : (isHovering ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.12)), lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func copyWholeLine() {
        onCopy(snippet.text, snippet.lineNumber)
        withAnimation(.easeInOut(duration: 0.15)) {
            isLineCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isLineCopied = false
            }
        }
    }
    
    private func highlightedSnippetText(_ text: String, searchQuery: String) -> Text {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return Text(text) }
        
        if let range = text.range(of: query, options: [.caseInsensitive]) {
            let before = String(text[..<range.lowerBound])
            let match = String(text[range])
            let after = String(text[range.upperBound...])
            
            return Text(before) +
                   Text(match).foregroundColor(.yellow).bold() +
                   Text(after)
        }
        return Text(text)
    }
}

// MARK: - 快捷键标签组件
struct ShortcutBadgeView: View {
    let key: String
    let label: String
    
    var body: some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(3)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}
