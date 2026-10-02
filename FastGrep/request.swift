//
//  request.swift
//  FastGrep 快摘
//
//  Created by Drinking on 09/24/24.
//  Copyright © 2024 Drinking. All rights reserved.
//

import Foundation


var KEY : String?

func fetchPrompt(prompt : String,  callback : @escaping (_ content: String?) -> Void) {
    
    
    if(KEY == nil) {
        if let k = UserDefaults.standard.string(forKey: "key") {
            KEY = k
        }
    }
    
    guard let key = KEY else {
        callback("NO Key found, please use ':key <key>' to set")
        return
    }
    
    let jsonData = [
        "model": "openai/gpt-3.5-turbo",
        "messages": [
            [
                "role": "user",
                "content": prompt
            ]
        ]
    ] as [String : Any]
    
    guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions"),
          let data = try? JSONSerialization.data(withJSONObject: jsonData, options: []) else {
        callback(nil)
        return
    }
    let headers = [
        "Content-Type": "application/json",
        "Authorization": "Bearer " + key
    ]
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.allHTTPHeaderFields = headers
    request.httpBody = data
    
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        
        guard let data = data, let str = String(data: data, encoding: .utf8) else {
            print(error ?? "Network Error")
            callback(nil)
            return
        }
        
        callback(parseContent(jsonString: str))
        
    }
    
    task.resume()
}

private func parseContent(jsonString : String) -> String? {
    if let jsonData = jsonString.data(using: .utf8) {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
            
            if let jsonDict = jsonObject as? [String: Any] {
                // Access JSON data here
                let choices = jsonDict["choices"] as? [[String:Any]]
                let message = choices?.first?["message"] as? [String:Any]
                return message?["content"] as? String
            }
        } catch {
            print("Error parsing JSON: \(error)")
        }
    }
    return nil
}


var templatesLoaded = false
var templates = [
    "how to ",
    "what is ",
    "what's the meaning of ",
    "what's the difference between ",
    "what's the relationship between",
    "translate the following to Chinese: ",
    "translate the following to English: ",
    "please revise my message: "
]

public func fetch(prompt: String) -> [PromptItem] {
    
    if(prompt.first == "/") {
        if(!templatesLoaded) {
            let list = UserDefaults.standard.stringArray(forKey: "template") ?? []
            if !list.isEmpty {
                templates = list
            }
            templatesLoaded = true
        }
        
        return templates.filter({ str in
            !str.ranges(of: String(prompt.dropFirst())).isEmpty
        })
        .map { str in
            PromptItem(name: str, content: "", prompt: String(prompt.dropFirst()))
        }
    }
    
    return DataStore.shared.fetchFromDB(prompt: prompt)
}


public func performSetting(prompt: String) -> Bool{
    
    if(prompt.hasPrefix(":add")) {
        let content = prompt.replacingOccurrences(of: ":add", with: "").trimmingCharacters(in: .whitespaces)
        let splits = content.split(separator: " ")
        if(splits.count > 1) {
            _ = DataStore.shared.insert(prompt: String(splits[0]), content: String(splits[1]))
        }
        return true
    }else if(prompt.hasPrefix(":del")) {
        let key = prompt.replacingOccurrences(of: ":del", with: "").trimmingCharacters(in: .whitespaces)
        DataStore.shared.delete(key: key)
        return true
    }else if(prompt.hasPrefix(":pick")) {
        DataStore.shared.pickFile()
        return true
    }
    
    return false
}

