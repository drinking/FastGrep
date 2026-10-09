//
//  AppDelegate.swift
//  FastGrep 快摘
//
//  Created by Drinking on 09/24/24.
//  Copyright © 2024 Drinking. All rights reserved.
//

import Cocoa
import SwiftUI
import HotKey

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    
    var hotKey: HotKey!
    var translationHotKey: HotKey!
    var popover: NSPopover!
    var settingsPopover: NSPopover!
    var clipboardPopover: NSPopover!
    var statusBarItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView(
            closePopover: {
                self.popover.performClose(nil)
            },
            openSettings: {
                self.showSettingsPopover()
            }
        )
        
        // Create the main popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 720, height: 480)
        popover.behavior = .transient
        
        popover.contentViewController = NSHostingController(rootView: contentView)
        self.popover = popover
        
        // Create the settings popover
        let settingsView = SettingsView(
            onHotKeyChange: { key, modifiers in
                self.updateHotKey(key: key, modifiers: modifiers)
            },
            onTranslationHotKeyChange: { key, modifiers in
                self.updateTranslationHotKey(key: key, modifiers: modifiers)
            },
            closeSettings: {
                self.settingsPopover.performClose(nil)
            }
        )
        
        let settingsPopover = NSPopover()
        settingsPopover.contentSize = NSSize(width: 540, height: 510)
        settingsPopover.behavior = .transient
        
        settingsPopover.contentViewController = NSHostingController(rootView: settingsView)
        self.settingsPopover = settingsPopover
        
        // Create the clipboard history popover
        let clipboardView = ClipboardHistoryView(
            closeCallback: {
                self.clipboardPopover.performClose(nil)
            }
        )
        
        let clipboardPopover = NSPopover()
        clipboardPopover.contentSize = NSSize(width: 500, height: 600)
        clipboardPopover.behavior = .transient
        
        clipboardPopover.contentViewController = NSHostingController(rootView: clipboardView)
        self.clipboardPopover = clipboardPopover
        
        // Create the status item
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        
        if let button = self.statusBarItem.button {
            let symbolConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            let icon = NSImage(systemSymbolName: "doc.text.magnifyingglass", accessibilityDescription: "FastGrep 快摘")?.withSymbolConfiguration(symbolConfig)
                ?? NSImage(named: "Icon")
            icon?.isTemplate = true
            button.image = icon
            button.toolTip = "FastGrep 快摘"
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        NSApp.activate(ignoringOtherApps: true)
        
        // Load saved hotkey or use default
        setupHotKey()
        setupTranslationHotKey()
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let event = NSApp.currentEvent {
            if event.type == NSEvent.EventType.rightMouseUp {
                showMenu(sender)
            } else {
                showMainView(sender)
            }
        }
    }
    
    func showMainView(_ sender: AnyObject?) {
        if let button = self.statusBarItem.button {
            if self.popover.isShown {
                self.popover.performClose(sender)
            } else {
                if self.settingsPopover.isShown {
                    self.settingsPopover.performClose(nil)
                }
                if self.clipboardPopover.isShown {
                    self.clipboardPopover.performClose(nil)
                }
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    func showMenu(_ sender: AnyObject?) {
        let menu = NSMenu()
        menu.addItem(withTitle: "打开 FastGrep", action: #selector(menuItemAction(_:)), keyEquivalent: "o")
        menu.addItem(withTitle: "剪贴板历史", action: #selector(menuItemAction(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "剪贴板快速翻译", action: #selector(menuItemAction(_:)), keyEquivalent: "t")
        menu.addItem(withTitle: "偏好设置...", action: #selector(menuItemAction(_:)), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "关于 FastGrep", action: #selector(menuItemAction(_:)), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "退出 FastGrep", action: #selector(menuItemAction(_:)), keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    
    @objc func menuItemAction(_ sender: NSMenuItem) {
        switch sender.title {
        case "打开 FastGrep":
            if let button = self.statusBarItem.button {
                showMainView(button)
            }
        case "剪贴板历史":
            showClipboardHistoryPopover()
        case "剪贴板快速翻译":
            showTranslationWindow()
        case "偏好设置...":
            showSettingsPopover()
        case "关于 FastGrep":
            showAboutPanel()
        case "退出 FastGrep":
            NSApplication.shared.terminate(self)
        default:
            break
        }
    }
    
    func showAboutPanel() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            NSApplication.AboutPanelOptionKey.version: "1.0",
            NSApplication.AboutPanelOptionKey.applicationVersion: "Build 1",
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Copyright © 2024-2026 FastGrep Contributors"
        ])
    }
    
    func showSettingsPopover() {
        if let button = self.statusBarItem.button {
            if self.settingsPopover.isShown {
                self.settingsPopover.performClose(nil)
            } else {
                // Close other popovers if they're open
                if self.popover.isShown {
                    self.popover.performClose(nil)
                }
                if self.clipboardPopover.isShown {
                    self.clipboardPopover.performClose(nil)
                }
                self.settingsPopover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    func showClipboardHistoryPopover() {
        if let button = self.statusBarItem.button {
            if self.clipboardPopover.isShown {
                self.clipboardPopover.performClose(nil)
            } else {
                // Close other popovers if they're open
                if self.popover.isShown {
                    self.popover.performClose(nil)
                }
                if self.settingsPopover.isShown {
                    self.settingsPopover.performClose(nil)
                }
                self.clipboardPopover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
    
    func setupHotKey() {
        // Load saved hotkey settings or use defaults
        let defaultKey: Key = .space
        let defaultModifiers: NSEvent.ModifierFlags = [.control, .command]
        
        var key = defaultKey
        var modifiers = defaultModifiers
        
        // Load from UserDefaults if available
        if let keyRawValue = UserDefaults.standard.object(forKey: "hotkey_key") as? UInt16 {
            key = keyCodeToKey(keyRawValue) ?? defaultKey
        }
        
        let modifierFlags = UserDefaults.standard.integer(forKey: "hotkey_modifiers")
        if modifierFlags != 0 {
            modifiers = NSEvent.ModifierFlags(rawValue: UInt(modifierFlags))
        }
        
        updateHotKey(key: key, modifiers: modifiers)
    }
    
    func updateHotKey(key: Key, modifiers: NSEvent.ModifierFlags) {
        // Remove existing hotkey
        hotKey = nil
        
        // Create new hotkey
        hotKey = HotKey(key: key, modifiers: modifiers, keyDownHandler: {
            NSApp.activate(ignoringOtherApps: true)
            if let button = self.statusBarItem.button {
                self.showMainView(button)
            }
        })
    }
    
    func showTranslationWindow(text: String? = nil) {
        TranslationWindowController.shared.showTranslation(initialText: text)
    }
    
    func setupTranslationHotKey() {
        // Default: ⌃ ⌥ T (Control + Option + T)
        let defaultKey: Key = .t
        let defaultModifiers: NSEvent.ModifierFlags = [.control, .option]
        
        var key = defaultKey
        var modifiers = defaultModifiers
        
        if let keyRawValue = UserDefaults.standard.object(forKey: "translation_hotkey_key") as? UInt16 {
            key = keyCodeToKey(keyRawValue) ?? defaultKey
        }
        
        let modifierFlags = UserDefaults.standard.integer(forKey: "translation_hotkey_modifiers")
        if modifierFlags != 0 {
            modifiers = NSEvent.ModifierFlags(rawValue: UInt(modifierFlags))
        }
        
        updateTranslationHotKey(key: key, modifiers: modifiers)
    }
    
    func updateTranslationHotKey(key: Key, modifiers: NSEvent.ModifierFlags) {
        translationHotKey = nil
        translationHotKey = HotKey(key: key, modifiers: modifiers, keyDownHandler: { [weak self] in
            self?.showTranslationWindow()
        })
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
    
    
    
}

