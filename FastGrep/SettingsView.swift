//
//  SettingsView.swift
//  FastGrep 快摘
//
//  Created by Drinking on 10/24/25.
//  Copyright © 2024 Drinking. All rights reserved.
//

import SwiftUI
import HotKey
import ServiceManagement

enum SettingsTab: String, CaseIterable, Identifiable {
    case folder = "监控目录"
    case snippets = "常用短语"
    case hotkey = "快捷键"
    case translation = "AI 翻译"
    case general = "通用与关于"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .folder: return "folder"
        case .snippets: return "text.badge.plus"
        case .hotkey: return "command"
        case .translation: return "character.bubble.fill"
        case .general: return "gearshape.2"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .folder
    
    // 主面板快捷键状态
    @State private var selectedKey: Key = .space
    @State private var selectedModifiers: NSEvent.ModifierFlags = [.control, .command]
    @State private var isRecordingMain = false
    @State private var recordedKeyEvent: String = ""
    
    // 剪贴板快速翻译快捷键状态
    @State private var selectedTranslationKey: Key = .t
    @State private var selectedTranslationModifiers: NSEvent.ModifierFlags = [.control, .option]
    @State private var isRecordingTranslation = false
    @State private var recordedTranslationKeyEvent: String = ""
    
    // AI 翻译状态
    @ObservedObject private var translationService = OllamaTranslationService.shared
    @State private var ollamaEndpointInput: String = ""
    @State private var ollamaModelInput: String = ""
    @State private var isTestingOllama = false
    @State private var ollamaTestFeedback: (success: Bool, message: String)? = nil
    
    // 监控目录状态
    @State private var monitoredDirectories: [MonitoredDirectory] = []
    @State private var indexedFilesCount: Int = 0
    @State private var isRescanningFolder = false

    
    // 常用短语状态
    @State private var customSnippets: [CustomSnippet] = []
    @State private var newSnippetKey: String = ""
    @State private var newSnippetContent: String = ""
    @State private var snippetFeedback: String? = nil
    
    // 通用与自启动状态
    @State private var launchAtLogin: Bool = false
    @State private var launchAtLoginError: String? = nil
    
    var onHotKeyChange: (Key, NSEvent.ModifierFlags) -> Void
    var onTranslationHotKeyChange: (Key, NSEvent.ModifierFlags) -> Void = { _, _ in }
    var closeSettings: () -> Void
    
    private let availableKeys: [Key] = [
        .space, .return, .tab, .escape,
        .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m,
        .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z,
        .one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .zero,
        .f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航栏与分类切换
            headerView
            
            Divider()
            
            // 主体内容分页
            VStack(spacing: 0) {
                switch selectedTab {
                case .folder:
                    folderSettingsView
                case .snippets:
                    snippetsSettingsView
                case .hotkey:
                    hotkeySettingsView
                case .translation:
                    translationSettingsView
                case .general:
                    generalSettingsView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
        }
        .frame(width: 580, height: 530)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadSavedHotkey()
            loadSavedTranslationHotkey()
            ollamaEndpointInput = translationService.endpoint
            ollamaModelInput = translationService.model
            refreshFolderInfo()
            loadCustomSnippets()
            checkLaunchAtLoginStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MonitoredDirectoriesDidUpdate"))) { _ in
            refreshFolderInfo()
        }
    }
    
    // MARK: - 顶部导航与标签栏
    
    private var headerView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14))
                Text("FastGrep 偏好设置")
                    .font(.system(size: 14, weight: .semibold))
            }
            
            Spacer()
            
            // 顶部 3 个 Tab 分段切换器（避免 AppKit 原生 NSSegmentedControl 拆解 HStack 图标与文字导致出现 6 个入口）
            HStack(spacing: 2) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                        )
                        .foregroundColor(selectedTab == tab ? .white : .primary.opacity(0.85))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            Spacer()
            
            Button(action: closeSettings) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .help("关闭设置")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Tab 1: 监控目录管理 (支持添加与管理多个本地文件夹)
    
    private var folderSettingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶栏操作与统计概览
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("本地文本与代码监控目录")
                        .font(.system(size: 13, weight: .bold))
                    Text("共监控 \(monitoredDirectories.count) 个目录 · 已索引 \(indexedFilesCount) 个文件")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        DataStore.shared.addDirectoriesViaPanel {
                            refreshFolderInfo()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("添加目录...")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button(action: {
                        isRescanningFolder = true
                        DataStore.shared.rescanAllMonitoredDirectories {
                            isRescanningFolder = false
                            refreshFolderInfo()
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isRescanningFolder {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("重新扫描全部")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isRescanningFolder || monitoredDirectories.isEmpty)
                    
                    if !monitoredDirectories.isEmpty {
                        Button(action: {
                            DataStore.shared.clearAllMonitoredDirectories {
                                refreshFolderInfo()
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("清空所有监控目录")
                    }
                }
            }
            
            // 目录列表容器
            if !monitoredDirectories.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(monitoredDirectories) { dir in
                            directoryCard(dir: dir)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 220)
            } else {
                // 尚未添加任何目录的空白占位
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    VStack(spacing: 4) {
                        Text("尚未添加任何监控目录")
                            .font(.system(size: 13, weight: .semibold))
                        Text("点击上方「添加目录」按钮，可选取一个或多个本地文件夹。\nFastGrep 快摘 会自动读取支持的 Markdown 笔记、代码与文本，建立统一检索索引。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    Button("添加监控目录...") {
                        DataStore.shared.addDirectoriesViaPanel {
                            refreshFolderInfo()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.15), lineWidth: 1))
            }
            
            // 底部规则说明卡片
            VStack(alignment: .leading, spacing: 5) {
                Text("功能与规则说明：")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("• 支持多目录共存：所有已添加目录的文件将聚合去重，并进行统一全文索引。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.85))
                Text("• 支持格式：Markdown (.md)、代码 (.swift, .py, .js, .ts, .sh)、配置 (.json, .yaml, .env)、普通文本 (.txt)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.85))
                Text("• 智能过滤：单文件最大限制 3MB，自动跳过 .git、node_modules、build、DerivedData 等目录。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.85))
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(8)
            
            Spacer()
        }
    }
    
    // 单个目录展示卡片
    private func directoryCard(dir: MonitoredDirectory) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(dir.isAvailable ? Color.blue.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: dir.isAvailable ? "folder.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(dir.isAvailable ? .blue : .orange)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(dir.name)
                        .font(.system(size: 12, weight: .bold))
                    
                    if dir.isAvailable {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                            Text("\(dir.fileCount) 个文件")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
                    } else {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 9))
                            Text("目录不可访问")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(4)
                    }
                }
                
                Text(dir.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            // 操作按钮：在访达中显示 & 移除
            HStack(spacing: 4) {
                Button(action: {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
                }) {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("在访达 (Finder) 中显示此目录")
                
                Button(action: {
                    DataStore.shared.removeMonitoredDirectory(id: dir.id) {
                        refreshFolderInfo()
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("移除此监控目录")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.16), lineWidth: 1))
    }
    
    private func refreshFolderInfo() {
        monitoredDirectories = DataStore.shared.getMonitoredDirectories()
        indexedFilesCount = DataStore.shared.indexedFilesCount
    }
    
    // MARK: - Tab 2: 自定义常用短语管理 (取代 :add 与 :del)
    
    private var snippetsSettingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 新建短语表单卡片
            VStack(alignment: .leading, spacing: 8) {
                Text("新建快捷常用语")
                    .font(.system(size: 12, weight: .bold))
                
                HStack(spacing: 8) {
                    Text("关键词:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 44, alignment: .trailing)
                    
                    TextField("例如: email, 税号, github, prompt_code", text: $newSnippetKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Text("内容:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 44, alignment: .trailing)
                        .padding(.top, 4)
                    
                    TextEditor(text: $newSnippetContent)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 52)
                        .padding(2)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25), lineWidth: 1))
                }
                
                HStack {
                    if let msg = snippetFeedback {
                        Text(msg)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    Button("添加短语") {
                        if DataStore.shared.addPrompt(key: newSnippetKey, value: newSnippetContent) {
                            let key = newSnippetKey
                            newSnippetKey = ""
                            newSnippetContent = ""
                            snippetFeedback = "✓ 已添加: \(key)"
                            loadCustomSnippets()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                snippetFeedback = nil
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newSnippetKey.trimmingCharacters(in: .whitespaces).isEmpty || newSnippetContent.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.18), lineWidth: 1))
            
            // 已保存短语列表
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("已保存常用语 (\(customSnippets.count) 个)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                if !customSnippets.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 5) {
                            ForEach(customSnippets) { snippet in
                                HStack(alignment: .center, spacing: 10) {
                                    Text(snippet.prompt)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(4)
                                    
                                    Text(snippet.content.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " "))
                                        .font(.system(size: 11))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        DataStore.shared.deletePrompt(id: snippet.id)
                                        loadCustomSnippets()
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 11))
                                            .foregroundColor(.red.opacity(0.75))
                                            .padding(4)
                                    }
                                    .buttonStyle(.plain)
                                    .help("删除此项")
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.35))
                                .cornerRadius(6)
                            }
                        }
                    }
                    .frame(height: 190)
                } else {
                    VStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "doc.text")
                            .font(.system(size: 26))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("暂无自定义短语")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("在上方输入关键词与常用文本即可一键添加，在主界面输入关键词即可瞬间检索复制")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.12), lineWidth: 1))
        }
    }
    
    private func loadCustomSnippets() {
        customSnippets = DataStore.shared.loadAllPromptsFromDB()
    }
    
    // MARK: - Tab 3: 全局快捷键
    
    private var hotkeySettingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 卡片 1: 全局激活主面板
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "command")
                            .foregroundColor(.accentColor)
                        Text("全局呼出主面板快捷键")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("当前快捷键:")
                                .font(.system(size: 11))
                            Text(getHotkeyDescription(key: selectedKey, modifiers: selectedModifiers))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(5)
                                .font(.system(.body, design: .monospaced).weight(.bold))
                            
                            Spacer()
                            
                            Button(action: { startRecording(isTranslation: false) }) {
                                HStack(spacing: 4) {
                                    if isRecordingMain {
                                        Image(systemName: "waveform")
                                        Text("请按下组合键...")
                                            .foregroundColor(.orange)
                                    } else {
                                        Image(systemName: "record.circle")
                                        Text("录制")
                                    }
                                }
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isRecordingMain ? Color.orange.opacity(0.2) : Color.blue.opacity(0.15))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("主按键:")
                                .font(.system(size: 11))
                            Picker("", selection: $selectedKey) {
                                ForEach(availableKeys, id: \.self) { key in
                                    Text(getKeyDisplayName(key)).tag(key)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 110)
                            
                            Spacer()
                            
                            Text("修饰键:")
                                .font(.system(size: 11))
                            HStack(spacing: 8) {
                                Toggle("⌘ Cmd", isOn: Binding(
                                    get: { selectedModifiers.contains(.command) },
                                    set: { if $0 { selectedModifiers.insert(.command) } else { selectedModifiers.remove(.command) } }
                                ))
                                Toggle("⌥ Opt", isOn: Binding(
                                    get: { selectedModifiers.contains(.option) },
                                    set: { if $0 { selectedModifiers.insert(.option) } else { selectedModifiers.remove(.option) } }
                                ))
                                Toggle("⌃ Ctrl", isOn: Binding(
                                    get: { selectedModifiers.contains(.control) },
                                    set: { if $0 { selectedModifiers.insert(.control) } else { selectedModifiers.remove(.control) } }
                                ))
                                Toggle("⇧ Shift", isOn: Binding(
                                    get: { selectedModifiers.contains(.shift) },
                                    set: { if $0 { selectedModifiers.insert(.shift) } else { selectedModifiers.remove(.shift) } }
                                ))
                            }
                            .font(.system(size: 10))
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15), lineWidth: 1))
                }
                
                // 卡片 2: 剪贴板快速翻译
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "character.bubble.fill")
                            .foregroundColor(.purple)
                        Text("剪贴板即时翻译快捷键 (Ollama 本地模型)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("当前快捷键:")
                                .font(.system(size: 11))
                            Text(getHotkeyDescription(key: selectedTranslationKey, modifiers: selectedTranslationModifiers))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.purple.opacity(0.15))
                                .foregroundColor(.purple)
                                .cornerRadius(5)
                                .font(.system(.body, design: .monospaced).weight(.bold))
                            
                            Spacer()
                            
                            Button(action: { startRecording(isTranslation: true) }) {
                                HStack(spacing: 4) {
                                    if isRecordingTranslation {
                                        Image(systemName: "waveform")
                                        Text("请按下组合键...")
                                            .foregroundColor(.orange)
                                    } else {
                                        Image(systemName: "record.circle")
                                        Text("录制")
                                    }
                                }
                                .font(.system(size: 11))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isRecordingTranslation ? Color.orange.opacity(0.2) : Color.purple.opacity(0.15))
                                .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("主按键:")
                                .font(.system(size: 11))
                            Picker("", selection: $selectedTranslationKey) {
                                ForEach(availableKeys, id: \.self) { key in
                                    Text(getKeyDisplayName(key)).tag(key)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 110)
                            
                            Spacer()
                            
                            Text("修饰键:")
                                .font(.system(size: 11))
                            HStack(spacing: 8) {
                                Toggle("⌘ Cmd", isOn: Binding(
                                    get: { selectedTranslationModifiers.contains(.command) },
                                    set: { if $0 { selectedTranslationModifiers.insert(.command) } else { selectedTranslationModifiers.remove(.command) } }
                                ))
                                Toggle("⌥ Opt", isOn: Binding(
                                    get: { selectedTranslationModifiers.contains(.option) },
                                    set: { if $0 { selectedTranslationModifiers.insert(.option) } else { selectedTranslationModifiers.remove(.option) } }
                                ))
                                Toggle("⌃ Ctrl", isOn: Binding(
                                    get: { selectedTranslationModifiers.contains(.control) },
                                    set: { if $0 { selectedTranslationModifiers.insert(.control) } else { selectedTranslationModifiers.remove(.control) } }
                                ))
                                Toggle("⇧ Shift", isOn: Binding(
                                    get: { selectedTranslationModifiers.contains(.shift) },
                                    set: { if $0 { selectedTranslationModifiers.insert(.shift) } else { selectedTranslationModifiers.remove(.shift) } }
                                ))
                            }
                            .font(.system(size: 10))
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15), lineWidth: 1))
                }
                
                HStack {
                    Text("提示: 默认主面板 ⌃⌘Space，剪贴板翻译 ⌃⌥T")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("应用所有快捷键设置") {
                        applyAllHotkeys()
                        closeSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedModifiers.isEmpty || selectedTranslationModifiers.isEmpty)
                }
                .padding(.top, 4)
            }
            .padding(.trailing, 2)
        }
    }
    
    // MARK: - Tab 4: AI 翻译设置
    
    private var translationSettingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("本地 Ollama 翻译模型配置")
                .font(.system(size: 14, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 12) {
                // 模型卡片说明
                HStack(spacing: 10) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("腾讯混元翻译模型 (Tencent-HY-MT 1.5)")
                            .font(.system(size: 12, weight: .semibold))
                        Text("当前配置模型: \(translationService.model) ，针对中英文互译进行了深度优化，离线高品质极速翻译。")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
                
                // 表单
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ollama API 基础地址:")
                            .font(.system(size: 11, weight: .medium))
                        TextField("http://127.0.0.1:11434", text: $ollamaEndpointInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("模型名称:")
                            .font(.system(size: 11, weight: .medium))
                        TextField("MedAIBase/Tencent-HY-MT1.5:1.8b", text: $ollamaModelInput)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
                
                HStack(spacing: 8) {
                    Button(action: testOllamaConnection) {
                        HStack(spacing: 4) {
                            if isTestingOllama {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "network")
                            }
                            Text(isTestingOllama ? "正在测试..." : "测试连接与模型")
                        }
                        .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTestingOllama)
                    
                    Button("恢复默认设置") {
                        ollamaEndpointInput = OllamaTranslationService.defaultEndpoint
                        ollamaModelInput = OllamaTranslationService.defaultModel
                        saveOllamaSettings()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("测试翻译窗口") {
                        saveOllamaSettings()
                        TranslationWindowController.shared.showTranslation()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.bordered)
                }
                
                if let feedback = ollamaTestFeedback {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: feedback.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(feedback.success ? .green : .red)
                            .font(.system(size: 12))
                        Text(feedback.message)
                            .font(.system(size: 10))
                            .foregroundColor(feedback.success ? .green : .red)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((feedback.success ? Color.green : Color.red).opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.18), lineWidth: 1))
            
            Spacer()
            
            HStack {
                Text("复制任意文字后按下翻译快捷键 (默认 ⌃ ⌥ T) 即可呼出翻译悬浮窗。")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Button("保存模型设置") {
                    saveOllamaSettings()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private func testOllamaConnection() {
        saveOllamaSettings()
        isTestingOllama = true
        ollamaTestFeedback = nil
        
        translationService.testConnection { success, message in
            isTestingOllama = false
            ollamaTestFeedback = (success: success, message: message)
        }
    }
    
    private func saveOllamaSettings() {
        let ep = ollamaEndpointInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let md = ollamaModelInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ep.isEmpty {
            translationService.endpoint = ep
        }
        if !md.isEmpty {
            translationService.model = md
        }
    }
    
    // MARK: - 快捷键辅助方法
    
    private func getHotkeyDescription(key: Key, modifiers: NSEvent.ModifierFlags) -> String {
        var components: [String] = []
        if modifiers.contains(.control) { components.append("⌃") }
        if modifiers.contains(.option) { components.append("⌥") }
        if modifiers.contains(.shift) { components.append("⇧") }
        if modifiers.contains(.command) { components.append("⌘") }
        components.append(getKeyDisplayName(key))
        return components.joined(separator: " + ")
    }
    
    private func getKeyDisplayName(_ key: Key) -> String {
        switch key {
        case .space: return "Space"
        case .return: return "Return"
        case .tab: return "Tab"
        case .escape: return "Escape"
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        case .g: return "G"
        case .h: return "H"
        case .i: return "I"
        case .j: return "J"
        case .k: return "K"
        case .l: return "L"
        case .m: return "M"
        case .n: return "N"
        case .o: return "O"
        case .p: return "P"
        case .q: return "Q"
        case .r: return "R"
        case .s: return "S"
        case .t: return "T"
        case .u: return "U"
        case .v: return "V"
        case .w: return "W"
        case .x: return "X"
        case .y: return "Y"
        case .z: return "Z"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .zero: return "0"
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        default: return "Unknown"
        }
    }
    
    private func startRecording(isTranslation: Bool) {
        if isTranslation {
            isRecordingTranslation = true
            isRecordingMain = false
            recordedTranslationKeyEvent = ""
        } else {
            isRecordingMain = true
            isRecordingTranslation = false
            recordedKeyEvent = ""
        }
        
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            if self.isRecordingMain || self.isRecordingTranslation {
                self.handleKeyEvent(event)
            }
        }
        
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if self.isRecordingMain || self.isRecordingTranslation {
                self.handleKeyEvent(event)
                return nil
            }
            return event
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.stopRecording()
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecordingMain || isRecordingTranslation else { return }
        
        var modifiers: NSEvent.ModifierFlags = []
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        
        if let key = keyCodeToKey(event.keyCode) {
            DispatchQueue.main.async {
                if self.isRecordingTranslation {
                    self.selectedTranslationKey = key
                    self.selectedTranslationModifiers = modifiers
                    self.recordedTranslationKeyEvent = self.getHotkeyDescription(key: key, modifiers: modifiers)
                } else {
                    self.selectedKey = key
                    self.selectedModifiers = modifiers
                    self.recordedKeyEvent = self.getHotkeyDescription(key: key, modifiers: modifiers)
                }
                self.stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        isRecordingMain = false
        isRecordingTranslation = false
    }
    
    private func keyCodeToKey(_ keyCode: UInt16) -> Key? {
        switch keyCode {
        case 49: return .space
        case 36: return .return
        case 48: return .tab
        case 53: return .escape
        case 0: return .a
        case 11: return .b
        case 8: return .c
        case 2: return .d
        case 14: return .e
        case 3: return .f
        case 5: return .g
        case 4: return .h
        case 34: return .i
        case 38: return .j
        case 40: return .k
        case 37: return .l
        case 46: return .m
        case 45: return .n
        case 31: return .o
        case 35: return .p
        case 12: return .q
        case 15: return .r
        case 1: return .s
        case 17: return .t
        case 32: return .u
        case 9: return .v
        case 13: return .w
        case 7: return .x
        case 16: return .y
        case 6: return .z
        case 18: return .one
        case 19: return .two
        case 20: return .three
        case 21: return .four
        case 23: return .five
        case 22: return .six
        case 26: return .seven
        case 28: return .eight
        case 25: return .nine
        case 29: return .zero
        case 122: return .f1
        case 120: return .f2
        case 99: return .f3
        case 118: return .f4
        case 96: return .f5
        case 97: return .f6
        case 98: return .f7
        case 100: return .f8
        case 101: return .f9
        case 109: return .f10
        case 103: return .f11
        case 111: return .f12
        default: return nil
        }
    }
    
    private func loadSavedHotkey() {
        if let keyRawValue = UserDefaults.standard.object(forKey: "hotkey_key") as? UInt16,
           let key = keyCodeToKey(keyRawValue) {
            selectedKey = key
        }
        
        let modifierFlags = UserDefaults.standard.integer(forKey: "hotkey_modifiers")
        if modifierFlags != 0 {
            selectedModifiers = NSEvent.ModifierFlags(rawValue: UInt(modifierFlags))
        }
    }
    
    private func loadSavedTranslationHotkey() {
        let defaultKey: Key = .t
        let defaultModifiers: NSEvent.ModifierFlags = [.control, .option]
        
        selectedTranslationKey = defaultKey
        selectedTranslationModifiers = defaultModifiers
        
        if let keyRawValue = UserDefaults.standard.object(forKey: "translation_hotkey_key") as? UInt16,
           let key = keyCodeToKey(keyRawValue) {
            selectedTranslationKey = key
        }
        
        let modifierFlags = UserDefaults.standard.integer(forKey: "translation_hotkey_modifiers")
        if modifierFlags != 0 {
            selectedTranslationModifiers = NSEvent.ModifierFlags(rawValue: UInt(modifierFlags))
        }
    }
    
    private func applyHotkey() {
        UserDefaults.standard.set(getKeyCode(selectedKey), forKey: "hotkey_key")
        UserDefaults.standard.set(selectedModifiers.rawValue, forKey: "hotkey_modifiers")
        onHotKeyChange(selectedKey, selectedModifiers)
    }
    
    private func applyAllHotkeys() {
        applyHotkey()
        
        UserDefaults.standard.set(getKeyCode(selectedTranslationKey), forKey: "translation_hotkey_key")
        UserDefaults.standard.set(selectedTranslationModifiers.rawValue, forKey: "translation_hotkey_modifiers")
        onTranslationHotKeyChange(selectedTranslationKey, selectedTranslationModifiers)
    }
    
    private func getKeyCode(_ key: Key) -> UInt16 {
        switch key {
        case .space: return 49
        case .return: return 36
        case .tab: return 48
        case .escape: return 53
        case .a: return 0
        case .b: return 11
        case .c: return 8
        case .d: return 2
        case .e: return 14
        case .f: return 3
        case .g: return 5
        case .h: return 4
        case .i: return 34
        case .j: return 38
        case .k: return 40
        case .l: return 37
        case .m: return 46
        case .n: return 45
        case .o: return 31
        case .p: return 35
        case .q: return 12
        case .r: return 15
        case .s: return 1
        case .t: return 17
        case .u: return 32
        case .v: return 9
        case .w: return 13
        case .x: return 7
        case .y: return 16
        case .z: return 6
        case .one: return 18
        case .two: return 19
        case .three: return 20
        case .four: return 21
        case .five: return 23
        case .six: return 22
        case .seven: return 26
        case .eight: return 28
        case .nine: return 25
        case .zero: return 29
        case .f1: return 122
        case .f2: return 120
        case .f3: return 99
        case .f4: return 118
        case .f5: return 96
        case .f6: return 97
        case .f7: return 98
        case .f8: return 100
        case .f9: return 101
        case .f10: return 109
        case .f11: return 103
        case .f12: return 111
        default: return 49
        }
    }
    
    // MARK: - Tab 4: 通用与关于
    
    private var generalSettingsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 系统与常驻行为
            VStack(alignment: .leading, spacing: 10) {
                Text("系统行为")
                    .font(.system(size: 13, weight: .semibold))
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("开机自启动")
                                .font(.system(size: 12, weight: .medium))
                            Text("登录 macOS 后自动在后台运行 FastGrep，随时随地快捷呼出")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { launchAtLogin },
                            set: { updateLaunchAtLogin($0) }
                        ))
                        .toggleStyle(.switch)
                    }
                    
                    if let err = launchAtLoginError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 11))
                            Text(err)
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("剪贴板敏感隐私保护")
                                .font(.system(size: 12, weight: .medium))
                            Text("已自动识别并静默过滤 1Password、Bitwarden 等密码管理器的敏感复制")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            Text("已启用")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.12), lineWidth: 1))
            }
            
            // 关于与开源社区
            VStack(alignment: .leading, spacing: 10) {
                Text("关于 FastGrep")
                    .font(.system(size: 13, weight: .semibold))
                
                HStack(spacing: 16) {
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 54, height: 54)
                            .cornerRadius(12)
                    } else {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("FastGrep 快摘")
                                .font(.system(size: 15, weight: .bold))
                            Text("v1.0 (Build 1)")
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .cornerRadius(4)
                        }
                        Text("专为 macOS 打造的高效本地文本快摘、代码检索与剪贴板管理器")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Copyright © 2024-2026 FastGrep Contributors (MIT License)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    
                    Spacer()
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.12), lineWidth: 1))
                
                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/drinking/FastGrep") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                            Text("GitHub 仓库")
                        }
                        .font(.system(size: 11))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                    
                    Button(action: {
                        let alert = NSAlert()
                        alert.messageText = "FastGrep 快摘"
                        alert.informativeText = "当前版本已是最新版 (v1.0)。\n请留意 GitHub Releases 发布页以获取未来更新与功能增强。"
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "确定")
                        alert.runModal()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("检查更新")
                        }
                        .font(.system(size: 11))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
        }
    }
    
    private func checkLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = "更新开机自启状态失败: \(error.localizedDescription)"
            }
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
}