//
//  ClipboardHistoryView.swift
//  FastGrep 快摘
//
//  Created by Drinking on 10/24/25.
//  Copyright © 2024 Drinking. All rights reserved.
//

import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var clipboardManager = ClipboardManager.shared
    @State private var searchText = ""
    @State private var selectedType: ClipboardItemType? = nil
    @State private var showFavoritesOnly = false
    @State private var showStatistics = false
    @FocusState private var isSearchFocused: Bool
    
    var closeCallback: () -> Void
    
    var filteredItems: [ClipboardItem] {
        var items = clipboardManager.history
        
        // 类型过滤
        if let selectedType = selectedType {
            items = items.filter { $0.type == selectedType }
        }
        
        // 收藏过滤
        if showFavoritesOnly {
            items = items.filter { $0.isFavorite }
        }
        
        // 搜索过滤
        if !searchText.isEmpty {
            items = clipboardManager.searchHistory(query: searchText)
        }
        
        return items
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部区域
            headerView
            
            Divider()
            
            // 过滤器区域
            filterView
            
            Divider()
            
            // 主内容区域
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                clipboardListView
            }
            
            // 底部状态栏
            bottomStatusBar
        }
        .frame(width: 500, height: 600)
        .onAppear {
            if !clipboardManager.isMonitoring {
                clipboardManager.startMonitoring()
            }
        }
    }
    
    // MARK: - 子视图
    
    private var headerView: some View {
        HStack {
            Image(systemName: "doc.on.clipboard.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            Text("剪贴板历史")
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            // 统计按钮
            Button(action: { showStatistics.toggle() }) {
                Image(systemName: "chart.bar")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("查看统计信息")
            
            // 清空按钮
            Button(action: { 
                clipboardManager.clearHistory()
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            .help("清空历史记录")
            
            // 关闭按钮
            Button(action: closeCallback) {
                Image(systemName: "xmark")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private var filterView: some View {
        VStack(spacing: 12) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索剪贴板历史...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        // 搜索提交处理
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // 过滤选项
            HStack {
                // 类型过滤
                Menu {
                    Button("全部类型") { selectedType = nil }
                    Divider()
                    ForEach(ClipboardItemType.allCases, id: \.self) { type in
                        Button(action: { 
                            selectedType = selectedType == type ? nil : type
                        }) {
                            HStack {
                                Image(systemName: type.systemIcon)
                                Text(type.displayName)
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedType?.systemIcon ?? "line.3.horizontal.decrease.circle")
                        Text(selectedType?.displayName ?? "类型")
                        Image(systemName: "chevron.down")
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selectedType != nil ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(6)
                
                Spacer()
                
                // 收藏过滤
                Button(action: { showFavoritesOnly.toggle() }) {
                    HStack {
                        Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                        Text("收藏")
                    }
                    .foregroundColor(showFavoritesOnly ? .red : .primary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(showFavoritesOnly ? Color.red.opacity(0.1) : Color.clear)
                .cornerRadius(6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var clipboardListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredItems) { item in
                    ClipboardItemRowView(
                        item: item,
                        onCopy: {
                            clipboardManager.copyToClipboard(item)
                            closeCallback()
                        },
                        onToggleFavorite: {
                            clipboardManager.toggleFavorite(item)
                        },
                        onDelete: {
                            clipboardManager.deleteItem(item)
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("暂无剪贴板历史")
                .font(.title2)
                .foregroundColor(.gray)
            
            if !clipboardManager.isMonitoring {
                Text("剪贴板监控未启动")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("开始监控") {
                    clipboardManager.startMonitoring()
                }
                .buttonStyle(.borderedProminent)
            } else if !searchText.isEmpty || selectedType != nil || showFavoritesOnly {
                Text("没有匹配的项目")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("清除过滤器") {
                    searchText = ""
                    selectedType = nil
                    showFavoritesOnly = false
                }
                .buttonStyle(.bordered)
            } else {
                Text("复制一些内容开始记录历史")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var bottomStatusBar: some View {
        HStack {
            // 左侧状态信息
            HStack(spacing: 16) {
                Text("共 \(clipboardManager.history.count) 项")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !searchText.isEmpty || selectedType != nil || showFavoritesOnly {
                    Text("显示 \(filteredItems.count) 项")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text(clipboardManager.isMonitoring ? "● 监控中" : "○ 已停止")
                    .font(.caption)
                    .foregroundColor(clipboardManager.isMonitoring ? .green : .red)
            }
            
            Spacer()
            
            // 右侧控制按钮
            HStack(spacing: 8) {
                Button(clipboardManager.isMonitoring ? "停止监控" : "开始监控") {
                    if clipboardManager.isMonitoring {
                        clipboardManager.stopMonitoring()
                    } else {
                        clipboardManager.startMonitoring()
                    }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - 剪贴板项目行视图

struct ClipboardItemRowView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: item.type.systemIcon)
                .font(.title3)
                .foregroundColor(colorForType(item.type))
                .frame(width: 24)
            
            // 内容区域
            VStack(alignment: .leading, spacing: 4) {
                // 预览文本
                Text(item.preview)
                    .font(.body)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // 元信息
                HStack {
                    // 时间戳
                    Text(RelativeDateTimeFormatter().localizedString(for: item.timestamp, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let source = item.source {
                        Text("• \(source)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("• \(ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .memory))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if item.useCount > 0 {
                        Text("• 使用 \(item.useCount) 次")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 收藏标识
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮（hover时显示）
            if isHovering {
                HStack(spacing: 4) {
                    // 收藏按钮
                    Button(action: onToggleFavorite) {
                        Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(item.isFavorite ? .red : .gray)
                    }
                    .buttonStyle(.plain)
                    .help(item.isFavorite ? "取消收藏" : "添加收藏")
                    
                    // 复制按钮
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("复制到剪贴板")
                    
                    // 删除按钮
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("删除项目")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.gray.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onCopy()
        }
    }
    
    private func colorForType(_ type: ClipboardItemType) -> Color {
        switch type {
        case .text: return .primary
        case .image: return .purple
        case .file: return .orange
        case .url: return .blue
        case .color: return .pink
        }
    }
}

// MARK: - 统计视图

struct ClipboardStatisticsView: View {
    let statistics: ClipboardStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("剪贴板统计")
                .font(.title2)
                .fontWeight(.semibold)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                GridRow {
                    Text("总项目数:")
                    Text("\(statistics.totalItems)")
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Text("总大小:")
                    Text(statistics.formattedTotalSize)
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Text("今日新增:")
                    Text("\(statistics.todayItems)")
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Text("收藏项目:")
                    Text("\(statistics.favoriteItems)")
                        .fontWeight(.medium)
                }
                
                GridRow {
                    Text("平均大小:")
                    Text(ByteCountFormatter.string(fromByteCount: Int64(statistics.averageSize), countStyle: .memory))
                        .fontWeight(.medium)
                }
            }
            
            Divider()
            
            Text("类型分布")
                .font(.headline)
            
            ForEach(ClipboardItemType.allCases, id: \.self) { type in
                let count = statistics.typeDistribution[type] ?? 0
                if count > 0 {
                    HStack {
                        Image(systemName: type.systemIcon)
                            .foregroundColor(colorForType(type))
                        Text(type.displayName)
                        Spacer()
                        Text("\(count)")
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
    }
    
    private func colorForType(_ type: ClipboardItemType) -> Color {
        switch type {
        case .text: return .primary
        case .image: return .purple
        case .file: return .orange
        case .url: return .blue
        case .color: return .pink
        }
    }
}