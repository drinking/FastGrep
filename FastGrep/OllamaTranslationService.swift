//
//  OllamaTranslationService.swift
//  FastGrep 快摘
//
//  Created by Drinking on 10/09/26.
//  Copyright © 2026 Drinking. All rights reserved.
//

import Foundation

public enum TranslationTargetLanguage: String, CaseIterable, Identifiable {
    case auto = "auto"
    case chinese = "zh"
    case english = "en"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .auto: return "自动检测 (中英互译)"
        case .chinese: return "翻译为中文"
        case .english: return "翻译为英文"
        }
    }
}

public class OllamaTranslationService: ObservableObject {
    public static let shared = OllamaTranslationService()
    
    // UserDefaults 键名
    public static let endpointKey = "ollama_endpoint"
    public static let modelKey = "ollama_model"
    public static let defaultEndpoint = "http://127.0.0.1:11434"
    public static let defaultModel = "MedAIBase/Tencent-HY-MT1.5:1.8b"
    
    @Published public var endpoint: String {
        didSet {
            UserDefaults.standard.set(endpoint, forKey: Self.endpointKey)
        }
    }
    
    @Published public var model: String {
        didSet {
            UserDefaults.standard.set(model, forKey: Self.modelKey)
        }
    }
    
    private init() {
        let savedEndpoint = UserDefaults.standard.string(forKey: Self.endpointKey)
        self.endpoint = (savedEndpoint?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? savedEndpoint! : Self.defaultEndpoint
            
        let savedModel = UserDefaults.standard.string(forKey: Self.modelKey)
        self.model = (savedModel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? savedModel! : Self.defaultModel
    }
    
    public var cleanEndpoint: String {
        var ep = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        if ep.hasSuffix("/") {
            ep = String(ep.dropLast())
        }
        return ep
    }
    
    // 文本中是否包含中文字符
    public static func containsChinese(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                return true
            }
        }
        return false
    }
    
    // 生成 Tencent-HY-MT 针对性翻译提示词
    public func buildPrompt(for text: String, targetLanguage: TranslationTargetLanguage = .auto) -> (prompt: String, resolvedTarget: String) {
        let isChinese = Self.containsChinese(text)
        let resolvedTarget: String
        
        switch targetLanguage {
        case .chinese:
            resolvedTarget = "中文"
        case .english:
            resolvedTarget = "英文"
        case .auto:
            // 文本含中文则默认译为英文，否则译为中文
            resolvedTarget = isChinese ? "英文" : "中文"
        }
        
        let prompt = "将以下文本翻译为\(resolvedTarget)，注意只需要输出翻译后的结果，不要额外解释：\n\(text)"
        return (prompt, resolvedTarget)
    }
    
    // 检查本地 Ollama 服务连通性与模型是否存在
    public func testConnection(completion: @escaping (_ success: Bool, _ message: String) -> Void) {
        guard let url = URL(string: "\(cleanEndpoint)/api/tags") else {
            completion(false, "无效的服务地址: \(endpoint)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5
        
        let targetModel = self.model
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "连接失败: \(error.localizedDescription) (请确认 Ollama 正在运行)")
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let models = json["models"] as? [[String: Any]] else {
                    completion(false, "服务响应异常，未能读取模型列表")
                    return
                }
                
                let modelNames = models.compactMap { $0["name"] as? String }
                let exists = modelNames.contains { name in
                    name == targetModel || name.hasPrefix("\(targetModel):") || targetModel.hasPrefix("\(name):")
                }
                
                if exists {
                    completion(true, "连接成功！已检测到模型 \(targetModel)")
                } else {
                    let available = modelNames.joined(separator: ", ")
                    completion(false, "Ollama 连接正常，但未找到模型 \(targetModel)。可用模型: [\(available.isEmpty ? "无" : available)]")
                }
            }
        }.resume()
    }
    
    // 执行翻译请求
    public func translate(
        text: String,
        targetLanguage: TranslationTargetLanguage = .auto,
        completion: @escaping (Result<(result: String, targetLang: String), Error>) -> Void
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(NSError(domain: "OllamaTranslation", code: -1, userInfo: [NSLocalizedDescriptionKey: "文本为空，无可翻译内容"])))
            return
        }
        
        guard let url = URL(string: "\(cleanEndpoint)/api/generate") else {
            completion(.failure(NSError(domain: "OllamaTranslation", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效的 Ollama API 地址"])))
            return
        }
        
        let (prompt, resolvedTarget) = buildPrompt(for: trimmed, targetLanguage: targetLanguage)
        let requestBody: [String: Any] = [
            "model": self.model,
            "prompt": prompt,
            "stream": false
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "OllamaTranslation", code: -3, userInfo: [NSLocalizedDescriptionKey: "序列化请求参数失败"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 45 // 适当留给模型首次加载的时间
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    let msg = "调用 Ollama 失败: \(error.localizedDescription)。请确认本地 Ollama 服务已启动。"
                    completion(.failure(NSError(domain: "OllamaTranslation", code: -4, userInfo: [NSLocalizedDescriptionKey: msg])))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "OllamaTranslation", code: -5, userInfo: [NSLocalizedDescriptionKey: "未收到有效的 HTTP 响应"])))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "OllamaTranslation", code: -6, userInfo: [NSLocalizedDescriptionKey: "返回数据为空"])))
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    let errStr = String(data: data, encoding: .utf8) ?? "状态码 \(httpResponse.statusCode)"
                    completion(.failure(NSError(domain: "OllamaTranslation", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Ollama 错误: \(errStr)"])))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let translationResponse = json["response"] as? String {
                        let cleanResult = translationResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                        completion(.success((result: cleanResult, targetLang: resolvedTarget)))
                    } else {
                        completion(.failure(NSError(domain: "OllamaTranslation", code: -7, userInfo: [NSLocalizedDescriptionKey: "解析翻译结果失败"])))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
