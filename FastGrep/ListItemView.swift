//
//  ListItemView.swift
//  FastGrep 快摘
//
//  Created by Drinking on 09/24/24.
//  Copyright © 2024 Drinking. All rights reserved.
//

import SwiftUI


struct ListItemView: View {
    
    let item: PromptItem
    
    let deleteCallback : (_ item: PromptItem) -> Void
    
    init(data: PromptItem, callback: @escaping (_ itemId: PromptItem) -> Void) {
        self.item = data
        self.deleteCallback = callback
    }
    
    var body: some View {
        
        HStack {
            VStack(alignment: .leading) {
                item.combinedText().font(.title).lineLimit(1).truncationMode(.tail)
                Text(item.content).font(.title2).lineLimit(2)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(item.content, forType: .string)
            }) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundColor(.white)
            }.buttonStyle(.plain)
        }
        
        
    }
}

extension PromptItem {
    
    func combinedText() -> Text {
        var textList: [Text] = []
        var nameCopy = name
        
        if let range = nameCopy.range(of: prompt) {
            let front = nameCopy[..<range.lowerBound]
            if !front.isEmpty {
                textList.append(Text(String(front)))
            }
            textList.append(Text(prompt).foregroundColor(.yellow))
            let after = nameCopy[range.upperBound...]
            textList.append(Text(String(after)))
            return textList.reduce(Text("")) { $0 + $1 }
        }
        
        for char in prompt {
            if let index = nameCopy.firstIndex(of: char) {
                let front = nameCopy[..<index]
                let highlightedChar = Text(String(char)).foregroundColor(.yellow)
                
                if !front.isEmpty {
                    textList.append(Text(String(front)))
                }
                
                textList.append(highlightedChar)
                
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
