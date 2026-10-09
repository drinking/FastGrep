//
//  TranslationView.swift
//  FastGrep 快摘
//
//  Created by Drinking on 10/09/26.
//  Copyright © 2026 Drinking. All rights reserved.
//

import SwiftUI
import AppKit

public struct TranslationView: View {
    @ObservedObject var service = OllamaTranslationService.shared
    
    @State private var sourceText: String = ""
    @State private var translatedText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var targetLanguage: TranslationTargetLanguage = .auto
    @State private var currentResolvedTarget: String = "中文"
    @State private var copyFeedback: Bool = false
    
    var onClose: () -> Void = {}
    
    public init(initialText: String? = nil, onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
        _sourceText = State(initialValue: initialText ?? "")
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶栏 Header
            headerBar
            
            Divider()
                .opacity(0.6)
            
            // 内容主体 (上下分栏：原文与译文)
            VStack(spacing: 12) {
                // 原文区域
                sourceSection
                
                // 语言方向与控制条
                middleControlBar
                
                // 译文区域
                targetSection
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
                .opacity(0.6)
            
            // 底栏操作与快捷键提示
            bottomBar
        }
        .frame(width: 580, height: 490)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onAppear {
            if sourceText.isEmpty {
                loadFromClipboard()
            } else {
                startTranslation()
            }
        }
    }
    
    // MARK: - 顶栏
    private var headerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "character.bubble.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 15, weight: .semibold))
            
            Text("剪贴板即时翻译")
                .font(.system(size: 14, weight: .bold))
            
            // 模型标签
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text(service.model)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .cornerRadius(4)
            
            Spacer()
            
            // 关闭按钮
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.8))
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .help("关闭 (Esc)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: - 原文区域
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("剪贴板原文")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text("\(sourceText.count) 字符")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                
                Spacer()
                
                Button(action: loadFromClipboard) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                        Text("重新载入剪贴板")
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                if !sourceText.isEmpty {
                    Button(action: {
                        sourceText = ""
                        translatedText = ""
                        errorMessage = nil
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("清空")
                }
            }
            
            // 原文输入/预览文本框
            TextEditor(text: $sourceText)
                .font(.system(size: 13, design: .default))
                .padding(6)
                .background(Color(NSColor.textBackgroundColor).opacity(0.4))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                .frame(minHeight: 110, maxHeight: 130)
                .onChange(of: sourceText) {
                    // 原文改变时，用户如需翻译可按中栏翻译按钮
                }
        }
    }
    
    // MARK: - 中间控制条
    private var middleControlBar: some View {
        HStack(spacing: 10) {
            // 翻译方向选择
            Menu {
                ForEach(TranslationTargetLanguage.allCases) { lang in
                    Button(lang.displayName) {
                        targetLanguage = lang
                        startTranslation()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 11))
                    Text(targetLanguage.displayName)
                        .font(.system(size: 11, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            
            // 快速方向切换按钮
            Button(action: {
                if targetLanguage == .chinese {
                    targetLanguage = .english
                } else if targetLanguage == .english {
                    targetLanguage = .chinese
                } else {
                    // 若为 auto，按检测反转
                    let isZh = OllamaTranslationService.containsChinese(sourceText)
                    targetLanguage = isZh ? .chinese : .english
                }
                startTranslation()
            }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(5)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .help("切换目标语言")
            
            Spacer()
            
            // 立即翻译按钮
            Button(action: startTranslation) {
                HStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                    }
                    Text(isLoading ? "翻译中..." : "重新翻译")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(isLoading ? 0.4 : 0.85))
                .foregroundColor(.white)
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .disabled(isLoading || sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
    
    // MARK: - 译文区域
    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("翻译结果 (\(currentResolvedTarget))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                if !translatedText.isEmpty {
                    Text("\(translatedText.count) 字符")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                if !translatedText.isEmpty {
                    Button(action: copyResult) {
                        HStack(spacing: 3) {
                            Image(systemName: copyFeedback ? "checkmark" : "doc.on.doc")
                            Text(copyFeedback ? "已复制!" : "复制")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(copyFeedback ? .green : .accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            ZStack {
                // 背景区域
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.textBackgroundColor).opacity(0.4))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                
                if isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("本地模型 \(service.model) 正在翻译中...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 20))
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        
                        Button("重试") {
                            startTranslation()
                        }
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if translatedText.isEmpty {
                    VStack(spacing: 4) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("暂无翻译结果")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        Text(translatedText)
                            .font(.system(size: 13, design: .default))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                }
            }
            .frame(minHeight: 120, maxHeight: .infinity)
        }
    }
    
    // MARK: - 底栏
    private var bottomBar: some View {
        HStack {
            // 快捷提示
            HStack(spacing: 12) {
                Text("快捷键: ⏎ 复制译文   ⎋ 关闭")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 复制并关闭按钮
            Button(action: copyAndClose) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("复制并关闭")
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(translatedText.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(translatedText.isEmpty)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
    }
    
    // MARK: - 功能逻辑
    
    // 从剪贴板重新加载最新文本
    public func loadFromClipboard() {
        let pb = NSPasteboard.general
        if let string = pb.string(forType: .string), !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.sourceText = string
            self.startTranslation()
        } else if let latestItem = ClipboardManager.shared.history.first(where: { $0.type == .text || $0.type == .url }) {
            self.sourceText = latestItem.content
            self.startTranslation()
        } else {
            self.errorMessage = "剪贴板中当前无文本内容，请复制文字后重试。"
        }
    }
    
    // 触发翻译
    public func startTranslation() {
        let trimmed = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请输入或复制需要翻译的文本内容"
            return
        }
        
        isLoading = true
        errorMessage = nil
        copyFeedback = false
        
        service.translate(text: trimmed, targetLanguage: targetLanguage) { result in
            isLoading = false
            switch result {
            case .success(let payload):
                self.translatedText = payload.result
                self.currentResolvedTarget = payload.targetLang
                self.errorMessage = nil
            case .failure(let err):
                self.errorMessage = err.localizedDescription
            }
        }
    }
    
    // 复制译文到系统剪贴板
    private func copyResult() {
        guard !translatedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
        copyFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copyFeedback = false
        }
    }
    
    // 复制并关闭面板
    private func copyAndClose() {
        copyResult()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onClose()
        }
    }
}

// 供 AppKit 弹窗承载的控制器
public class TranslationWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = TranslationWindowController()
    
    private var isSetup = false
    
    public init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 490),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isFloatingPanel = true
        window.level = .floating
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func showTranslation(initialText: String? = nil) {
        let view = TranslationView(initialText: initialText) { [weak self] in
            self?.window?.orderOut(nil)
        }
        
        self.window?.contentViewController = NSHostingController(rootView: view)
        self.window?.center()
        
        NSApp.activate(ignoringOtherApps: true)
        self.window?.makeKeyAndOrderFront(nil)
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        // 当点击其他应用时可选择隐藏或保留，此处保留方便对照阅读，按 Esc 可快速关闭
    }
}
