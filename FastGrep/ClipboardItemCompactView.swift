//
//  ClipboardItemCompactView.swift
//  FastGrep 快摘
//
//  Created by Drinking on 10/24/25.
//  Copyright © 2024 Drinking. All rights reserved.
//

import SwiftUI

struct ClipboardItemCompactView: View {
    let item: ClipboardItem
    let searchQuery: String
    let onCopy: () -> Void
    
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
                // 预览文本（带搜索高亮）
                if searchQuery.isEmpty {
                    Text(item.preview)
                        .font(.body)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                } else {
                                            highlightedText(text: item.preview, searchText: searchQuery)
                        .font(.body)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // 元信息
                HStack {
                    // 时间戳
                    Text(timeAgoString(from: item.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let source = item.source {
                        Text("• \(source)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 收藏和使用次数
                    if item.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if item.useCount > 0 {
                        Text("\(item.useCount)×")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // 复制按钮（hover时显示）
            if isHovering {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("复制到剪贴板")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.blue.opacity(0.1) : Color.clear)
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
    
    // MARK: - 辅助方法
    
    private func colorForType(_ type: ClipboardItemType) -> Color {
        switch type {
        case .text: return .primary
        case .image: return .purple
        case .file: return .orange
        case .url: return .blue
        case .color: return .pink
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func highlightedText(text: String, searchText: String) -> Text {
        guard !searchText.isEmpty,
              let range = text.range(of: searchText, options: [.caseInsensitive]) else {
            return Text(text)
        }
        
        let beforeRange = String(text[..<range.lowerBound])
        let matchRange = String(text[range])
        let afterRange = String(text[range.upperBound...])
        
        return Text(beforeRange) +
               Text(matchRange).foregroundColor(.yellow) +
               Text(afterRange)
    }
}