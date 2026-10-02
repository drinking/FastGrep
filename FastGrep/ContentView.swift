//
//  ContentView.swift
//  FastGrep 快摘
//
//  Created by Drinking on 09/24/24.
//  Copyright © 2024 Drinking. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State private var prompt: String = ""
    @State private var selectedItem: UnifiedDisplayItem? = nil
    @State private var selectedIndex: Int = 0
    @State private var displayItems: [UnifiedDisplayItem] = []
    @State private var statusFeedback: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil
    
    @ObservedObject private var clipboardManager = ClipboardManager.shared
    
    @FocusState private var isSearchFocused: Bool
    
    var closePopover: () -> Void = {}
    var openSettings: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 0) {
            // 左栏：搜索输入 + 结果列表 + 底部状态导航 (宽度 300)
            VStack(spacing: 0) {
                leftSearchBar
                
                Divider()
                    .opacity(0.5)
                
                masterListView
                
                Divider()
                    .opacity(0.5)
                
                leftBottomBar
            }
            .frame(width: 300)
            
            Divider()
                .opacity(0.5)
            
            // 右栏：整个右侧由详情面板完整占据
            DetailPreviewView(
                item: selectedItem,
                searchQuery: prompt,
                onCopy: {
                    if let selected = selectedItem {
                        executeItemAction(selected)
                    }
                },
                onCopySnippet: { text, lineNum in
                    copySnippetToClipboard(text: text, lineNum: lineNum)
                },
                onCopySegment: { segText in
                    copyIndividualSegment(segText)
                },
                onRevealInFinder: { url in
                    revealInFinder(url: url)
                },
                onOpenFile: { url in
                    openWithDefaultApp(url: url)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 720, height: 480)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .onAppear {
            if !clipboardManager.isMonitoring {
                clipboardManager.startMonitoring()
            }
            scheduleSearch(query: prompt)
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MonitoredDirectoriesDidUpdate"))) { _ in
            scheduleSearch(query: prompt)
        }
    }
    
    private var currentEffectiveFileURL: URL? {
        resolveFileURL(from: selectedItem)
    }
    
    private func resolveFileURL(from item: UnifiedDisplayItem?) -> URL? {
        guard let item = item else { return nil }
        if let url = item.fileURL { return url }
        if case .prompt(let p) = item.underlyingSource, let url = p.fileURL {
            return url
        }
        if let matched = DataStore.shared.prompts.first(where: { $0.name == item.title }), let url = matched.fileURL {
            return url
        }
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
    
    // MARK: - 左侧顶部搜索栏
    
    private var leftSearchBar: some View {
        HStack(spacing: 8) {
            // 搜索图标
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
            
            // 搜索输入框
            TextField(searchPlaceholder, text: $prompt)
                .font(.system(size: 13))
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onChange(of: prompt) {
                    scheduleSearch(query: prompt)
                }
                .onKeyPress(keys: [.downArrow, .upArrow, .return, .escape]) { pressed in
                    switch pressed.key {
                    case .downArrow:
                        navigateSelection(delta: 1)
                        return .handled
                    case .upArrow:
                        navigateSelection(delta: -1)
                        return .handled
                    case .return:
                        if pressed.modifiers.contains(.command) {
                            if let url = currentEffectiveFileURL {
                                revealInFinder(url: url)
                                return .handled
                            }
                        } else if pressed.modifiers.contains(.option) {
                            if let url = currentEffectiveFileURL {
                                openWithDefaultApp(url: url)
                                return .handled
                            }
                        }
                        return handleReturnPress()
                    case .escape:
                        if !prompt.isEmpty {
                            prompt = ""
                            return .handled
                        } else {
                            closePopover()
                            return .handled
                        }
                    default:
                        return .ignored
                    }
                }
            
            // 清空按钮
            if !prompt.isEmpty {
                Button(action: { prompt = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.8))
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
            
            // 设置按钮
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("快捷键与偏好设置")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
    
    private var searchPlaceholder: String {
        "搜索文件、正文、剪贴板..."
    }
    
    // MARK: - 左侧列表 (Master List)
    
    private var masterListView: some View {
        ScrollViewReader { proxy in
            Group {
                if !displayItems.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                                MasterRowView(
                                    item: item,
                                    isSelected: selectedItem?.id == item.id,
                                    searchQuery: prompt,
                                    onSelect: {
                                        selectedIndex = index
                                        selectedItem = item
                                    },
                                    onAction: {
                                        executeItemAction(item)
                                    }
                                )
                                .id(item.id)
                                .contextMenu {
                                    if let url = resolveFileURL(from: item) {
                                        Button(action: { revealInFinder(url: url) }) {
                                            Label("在访达中显示路径", systemImage: "folder")
                                        }
                                        Button(action: { openWithDefaultApp(url: url) }) {
                                            Label("打开文件", systemImage: "arrow.up.forward.app")
                                        }
                                        Divider()
                                    }
                                    Button(action: { executeItemAction(item) }) {
                                        Label("复制内容", systemImage: "doc.on.doc")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        if let item = newItem {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(item.id, anchor: .center)
                            }
                        }
                    }
                } else {
                    // 左侧空状态
                    VStack(spacing: 10) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text(prompt.isEmpty ? "暂无内容" : "未找到匹配条目")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(prompt.isEmpty ? "点击设置 ⚙ 选择监控文件夹或添加短语" : "未找到匹配条目，可尝试更换搜索词")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        Spacer()
                    }
                }
            }
        }
    }
    
    // MARK: - 左侧底部状态与快捷键条
    
    private var leftBottomBar: some View {
        HStack {
            // 状态指示或反馈
            if let feedback = statusFeedback {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                    Text(feedback)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .transition(.opacity)
            } else {
                HStack(spacing: 4) {
                    Text("\(displayItems.count) 项")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if !displayItems.isEmpty {
                        Text("• \(selectedIndex + 1)/\(displayItems.count)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
            }
            
            Spacer()
            
            // 快捷键提示条 (左栏导航)
            HStack(spacing: 6) {
                ShortcutBadgeView(key: "↑↓", label: "选择")
                if currentEffectiveFileURL != nil {
                    ShortcutBadgeView(key: "⌘⏎", label: "打开目录")
                }
                ShortcutBadgeView(key: "Esc", label: "关闭")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.35))
    }
    
    // MARK: - 数据流与防抖异步检索
    
    private func updateItems() {
        scheduleSearch(query: prompt)
    }
    
    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空搜索词时立即展示默认列表，无需等待防抖
        if trimmed.isEmpty {
            performQueryBackground(query: "")
            return
        }
        
        // 100ms 异步防抖：快速连续键入时自动拦截中间多余的检索计算
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled { return }
            
            performQueryBackground(query: trimmed)
        }
    }
    
    private func performQueryBackground(query: String) {
        // 在后台并发队列执行高耗时的文件搜索与剪贴板遍历（默认全局全部范围）
        DispatchQueue.global(qos: .userInteractive).async {
            var results: [UnifiedDisplayItem] = []
            
            let promptItems = fetch(prompt: query).map { $0.toUnifiedDisplayItem() }
            let clipItems = ClipboardManager.shared.searchHistory(query: query).map { $0.toUnifiedDisplayItem(searchQuery: query) }
            if query.isEmpty {
                results = Array(clipItems.prefix(15)) + promptItems
            } else {
                results = promptItems + clipItems
            }
            
            // 计算完毕后回到主线程仅做轻量数据替换与渲染
            DispatchQueue.main.async {
                self.displayItems = results
                
                // 保持或更新选中项
                if let current = self.selectedItem, let newIdx = self.displayItems.firstIndex(where: { $0.id == current.id }) {
                    self.selectedIndex = newIdx
                    self.selectedItem = self.displayItems[newIdx]
                } else if let first = self.displayItems.first {
                    self.selectedIndex = 0
                    self.selectedItem = first
                } else {
                    self.selectedIndex = 0
                    self.selectedItem = nil
                }
            }
        }
    }
    
    private func navigateSelection(delta: Int) {
        guard !displayItems.isEmpty else { return }
        let newIndex = max(0, min(displayItems.count - 1, selectedIndex + delta))
        selectedIndex = newIndex
        selectedItem = displayItems[newIndex]
    }
    
    private func handleReturnPress() -> KeyPress.Result {
        if prompt.hasPrefix(":") {
            if performSetting(prompt: prompt) {
                statusFeedback = "指令已执行成功"
                prompt = ""
                updateItems()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    statusFeedback = nil
                }
                return .handled
            }
        }
        
        // 回车不需要复制功能，回车时保持搜索输入框还存在并保持聚焦
        isSearchFocused = true
        return .handled
    }
    
    private func executeItemAction(_ item: UnifiedDisplayItem) {
        switch item.underlyingSource {
        case .prompt(let promptItem):
            let text = promptItem.content.isEmpty ? promptItem.name : promptItem.content
            copyStringToPasteboard(text)
        case .clipboard(let clipItem):
            clipboardManager.copyToClipboard(clipItem)
        }
        closePopover()
    }
    
    private func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
        closePopover()
    }
    
    private func openWithDefaultApp(url: URL) {
        NSWorkspace.shared.open(url)
        closePopover()
    }
    

    private func copySnippetToClipboard(text: String, lineNum: Int) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        let preview = text.prefix(25) + (text.count > 25 ? "..." : "")
        statusFeedback = "✓ 已复制第 \(lineNum) 行: \"\(preview)\""
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            statusFeedback = nil
        }
    }
    
    private func copyIndividualSegment(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        let preview = text.prefix(20) + (text.count > 20 ? "..." : "")
        statusFeedback = "✓ 已复制分段: \"\(preview)\""
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            statusFeedback = nil
        }
    }
    
    private func copyStringToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
