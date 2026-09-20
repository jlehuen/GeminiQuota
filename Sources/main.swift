import SwiftUI
import Foundation
import AppKit

func makeBarGraphImage(color: NSColor) -> NSImage {
    let size = NSSize(width: 16, height: 14)
    let image = NSImage(size: size, flipped: false) { rect in
        color.setFill()
        
        let barWidth: CGFloat = 3.5
        let spacing: CGFloat = 2.0
        let radius: CGFloat = 1.2
        
        // 3 barres de hauteur progressive (bargraphe)
        let heights: [CGFloat] = [4.5, 9.0, 13.5]
        
        for i in 0..<3 {
            let x = CGFloat(i) * (barWidth + spacing)
            let h = heights[i]
            let y = 0.0
            let barRect = NSRect(x: x, y: y, width: barWidth, height: h)
            let path = NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius)
            path.fill()
        }
        return true
    }
    image.isTemplate = false
    return image
}

struct AppConfig: Codable {
    var terminal: String? = nil
    var application: String? = "agy"
    var workingDirectory: String? = ""
    var proxyEnabled: Bool? = true
    var model: String? = nil
    var httpProxy: String? = nil
    var httpsProxy: String? = nil
    var allProxy: String? = nil
    var noProxy: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case terminal
        case application
        case app
        case command
        case workingDirectory = "working_directory"
        case directory
        case workdir
        case proxyEnabled = "proxy_enabled"
        case model
        case httpProxy = "http_proxy"
        case httpsProxy = "https_proxy"
        case allProxy = "all_proxy"
        case noProxy = "no_proxy"
    }
    
    init(terminal: String? = nil, application: String? = "agy", workingDirectory: String? = "", proxyEnabled: Bool? = true, model: String? = nil, httpProxy: String? = nil, httpsProxy: String? = nil, allProxy: String? = nil, noProxy: String? = nil) {
        self.terminal = terminal
        self.application = application
        self.workingDirectory = workingDirectory
        self.proxyEnabled = proxyEnabled
        self.model = model
        self.httpProxy = httpProxy
        self.httpsProxy = httpsProxy
        self.allProxy = allProxy
        self.noProxy = noProxy
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        terminal = try container.decodeIfPresent(String.self, forKey: .terminal)
        proxyEnabled = try container.decodeIfPresent(Bool.self, forKey: .proxyEnabled)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        httpProxy = try container.decodeIfPresent(String.self, forKey: .httpProxy)
        httpsProxy = try container.decodeIfPresent(String.self, forKey: .httpsProxy)
        allProxy = try container.decodeIfPresent(String.self, forKey: .allProxy)
        noProxy = try container.decodeIfPresent(String.self, forKey: .noProxy)
        
        let decodedApp = try container.decodeIfPresent(String.self, forKey: .application)
            ?? container.decodeIfPresent(String.self, forKey: .app)
            ?? container.decodeIfPresent(String.self, forKey: .command)
        application = decodedApp ?? "agy"
        
        let decodedWorkDir = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
            ?? container.decodeIfPresent(String.self, forKey: .directory)
            ?? container.decodeIfPresent(String.self, forKey: .workdir)
        workingDirectory = decodedWorkDir ?? ""
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(terminal, forKey: .terminal)
        try container.encodeIfPresent(application, forKey: .application)
        try container.encodeIfPresent(workingDirectory, forKey: .workingDirectory)
        try container.encodeIfPresent(proxyEnabled, forKey: .proxyEnabled)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(httpProxy, forKey: .httpProxy)
        try container.encodeIfPresent(httpsProxy, forKey: .httpsProxy)
        try container.encodeIfPresent(allProxy, forKey: .allProxy)
        try container.encodeIfPresent(noProxy, forKey: .noProxy)
    }
}

struct QuotaData {
    var todayCount: Int = 0
    var dailyLimit: Int = 1000
    var hourCount: Int = 0
    var lastTimestamp: Date? = nil
    var lastQuery: String = ""
    var activeWorkspace: String = "CodeLab"
    var activeWorkspacePath: String = ""
    var activeModel: String = "Gemini 3.8 Flash (High)"
    
    var displayModelName: String {
        var name = activeModel
        if name.hasPrefix("Gemini ") {
            name = String(name.dropFirst(7))
        }
        return name.isEmpty ? "Flash (High)" : name
    }
    
    // Métriques de tokens
    var activeSessionTokens: Int = 0
    var todayTokens: Int = 0
    let maxContextWindow: Int = 1_048_576 // 1M tokens
    
    // 1. Compte à rebours avant minuit (Reset Countdown)
    var resetCountdown: String {
        let calendar = Calendar.current
        let now = Date()
        guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return "--"
        }
        let diff = calendar.dateComponents([.hour, .minute], from: now, to: nextMidnight)
        let hours = diff.hour ?? 0
        let minutes = diff.minute ?? 0
        return "\(hours)h \(String(format: "%02d", minutes))m"
    }
    
    // 5. Estimation du coût équivalent API commercial
    var equivalentApiCost: String {
        let cost = (Double(todayTokens) / 1_000_000.0) * 5.00
        return String(format: "$%.2f", max(0.05, cost))
    }
    
    var contextPercentage: Double {
        guard maxContextWindow > 0 else { return 0 }
        return (Double(activeSessionTokens) / Double(maxContextWindow)) * 100.0
    }
    
    var percentageUsed: Double {
        guard dailyLimit > 0 else { return 0 }
        return min(100.0, (Double(todayCount) / Double(dailyLimit)) * 100.0)
    }
    
    var remainingRequests: Int {
        return max(0, dailyLimit - todayCount)
    }
    
    // Fenêtre glissante (60 minutes)
    var slidingBuckets: [Int] = Array(repeating: 0, count: 12)
    var rateLimitResetDate: Date? = nil
    var lastRateLimitIncidentDate: Date? = nil
    var lastRateLimitIncidentDurationMinutes: Int = 0
    
    var isRateLimited: Bool {
        guard let resetDate = rateLimitResetDate else { return false }
        return resetDate > Date()
    }
    
    var rateLimitRemainingSeconds: Int {
        guard let resetDate = rateLimitResetDate else { return 0 }
        let diff = Int(resetDate.timeIntervalSince(Date()))
        return max(0, diff)
    }
    
    var rateLimitRemainingText: String {
        let s = rateLimitRemainingSeconds
        let m = s / 60
        let sec = s % 60
        return "\(m)m \(String(format: "%02d", sec))s"
    }
    
    var slidingIntensityLabel: String {
        if isRateLimited {
            return "Saturation"
        } else if hourCount == 0 {
            return "Calme"
        } else if hourCount <= 5 {
            return "Faible"
        } else if hourCount <= 15 {
            return "Modéré"
        } else if hourCount <= 30 {
            return "Élevé"
        } else {
            return "Très intense"
        }
    }
    
    var slidingIntensityColor: Color {
        if isRateLimited {
            return .red
        } else if hourCount <= 5 {
            return Color(red: 52/255.0, green: 199/255.0, blue: 89/255.0)
        } else if hourCount <= 15 {
            return .blue
        } else if hourCount <= 30 {
            return .orange
        } else {
            return .red
        }
    }
}

class QuotaModel: ObservableObject {
    @Published var data = QuotaData()
    @Published var isProxyEnabled: Bool = true
    @Published var config = AppConfig()
    private var timer: Timer?
    
    static let availableModels: [String] = [
        "Gemini 3.8 Flash (High)",
        "Gemini 3.8 Flash (Medium)",
        "Gemini 3.8 Flash (Low)",
        "Gemini 3.7 Flash",
        "Gemini 3.6 Flash",
        "Gemini 3.1 Pro"
    ]
    
    var proxySummary: String {
        let raw = config.httpsProxy ?? config.httpProxy ?? config.allProxy ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Aucun serveur configuré"
        }
        if let url = URL(string: trimmed), let host = url.host {
            let port = url.port != nil ? ":\(url.port!)" : ""
            return "\(host)\(port)"
        }
        return trimmed.replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "https://", with: "")
    }
    
    var cliAppName: String {
        let app = config.application?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (app?.isEmpty == false) ? app! : "agy"
    }
    
    var nsColor: NSColor {
        if data.isRateLimited {
            return NSColor(srgbRed: 255/255.0, green: 59/255.0, blue: 48/255.0, alpha: 1.0)
        }
        let pct = data.percentageUsed
        if pct < 70 {
            return NSColor(srgbRed: 52/255.0, green: 199/255.0, blue: 89/255.0, alpha: 1.0)
        } else if pct < 90 {
            return NSColor(srgbRed: 255/255.0, green: 149/255.0, blue: 0/255.0, alpha: 1.0)
        } else {
            return NSColor(srgbRed: 255/255.0, green: 59/255.0, blue: 48/255.0, alpha: 1.0)
        }
    }
    
    var tintColor: Color {
        Color(nsColor: nsColor)
    }
    
    var deepColor: Color {
        let pct = data.percentageUsed
        if pct < 70 {
            return Color(red: 30/255.0, green: 135/255.0, blue: 55/255.0)
        } else if pct < 90 {
            return Color(red: 205/255.0, green: 105/255.0, blue: 0/255.0)
        } else {
            return Color(red: 205/255.0, green: 40/255.0, blue: 35/255.0)
        }
    }
    
    var barGraphIcon: NSImage {
        makeBarGraphImage(color: nsColor)
    }
    
    var appGeminiIcon: NSImage {
        if let img = NSImage(named: "AppIcon") {
            return img
        }
        return barGraphIcon
    }
    
    init() {
        loadConfig()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func cleanWorkspaceName(_ rawPath: String) -> String {
        if rawPath.contains("codelab/client") {
            return "CodeLab (client)"
        } else if rawPath.contains("codelab/server") {
            return "CodeLab (serveur)"
        } else if rawPath.contains("diveplanner") {
            return "Diveplanner"
        } else if rawPath.contains("depot-devoirs") {
            return "Dépôt Devoirs"
        }
        let url = URL(fileURLWithPath: rawPath)
        let last = url.lastPathComponent
        return last.isEmpty ? "CodeLab" : last
    }
    
    func refresh() {
        self.loadConfig()
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let home = fileManager.homeDirectoryForCurrentUser
            let historyPath = home.appendingPathComponent(".gemini/antigravity-cli/history.jsonl")
            let brainPath = home.appendingPathComponent(".gemini/antigravity-cli/brain")
            
            let calendar = Calendar.current
            let now = Date()
            let midnight = calendar.startOfDay(for: now)
            let oneHourAgo = now.addingTimeInterval(-3600)
            
            var today = 0
            var hour = 0
            var slidingBuckets = Array(repeating: 0, count: 12)
            var lastDate: Date? = nil
            var lastText = ""
            var workspacePath = ""
            
            // 1. Analyse de history.jsonl
            if let content = try? String(contentsOf: historyPath, encoding: .utf8) {
                let lines = content.split(separator: "\n")
                for line in lines {
                    guard let lineData = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
                    else { continue }
                    
                    if let tsMillis = json["timestamp"] as? Double {
                        let date = Date(timeIntervalSince1970: tsMillis / 1000.0)
                        if date >= midnight {
                            today += 1
                        }
                        if date >= oneHourAgo && date <= now {
                            hour += 1
                            let ageSeconds = now.timeIntervalSince(date)
                            let bucketIndex = 11 - min(11, max(0, Int(ageSeconds / 300.0)))
                            slidingBuckets[bucketIndex] += 1
                        }
                        if lastDate == nil || date > lastDate! {
                            lastDate = date
                            lastText = (json["display"] as? String) ?? ""
                            workspacePath = (json["workspace"] as? String) ?? ""
                        }
                    }
                }
            }
            
            // 2. Analyse des transcripts
            var sessionTokens = 0
            var todayTokens = 0
            var latestTranscriptMtime: TimeInterval = 0
            var latestTranscriptURL: URL? = nil
            var activeRateLimitReset: Date? = nil
            var latestIncidentDate: Date? = nil
            var latestIncidentMinutes: Int = 0
            
            if let enumerator = fileManager.enumerator(at: brainPath, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: []) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent == "transcript.jsonl" {
                        if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                           let mtime = values.contentModificationDate,
                           let size = values.fileSize {
                            let tokens = size / 4
                            if mtime >= midnight {
                                todayTokens += tokens
                                
                                let (activeReset, inc) = self.parseTranscriptRateLimit(fileURL: fileURL, now: now)
                                if let a = activeReset {
                                    if activeRateLimitReset == nil || a > activeRateLimitReset! {
                                        activeRateLimitReset = a
                                    }
                                }
                                if let i = inc {
                                    if latestIncidentDate == nil || i.0 > latestIncidentDate! {
                                        latestIncidentDate = i.0
                                        latestIncidentMinutes = i.1
                                    }
                                }
                            }
                            let timeInterval = mtime.timeIntervalSince1970
                            if timeInterval > latestTranscriptMtime {
                                latestTranscriptMtime = timeInterval
                                sessionTokens = tokens
                                latestTranscriptURL = fileURL
                            }
                        }
                    }
                }
            }
            
            let cleanWorkspace = self.cleanWorkspaceName(workspacePath)
            
            // 3. Détection du modèle actif
            var detectedModel: String? = nil
            let settingsPath = home.appendingPathComponent(".gemini/antigravity-cli/settings.json")
            if let sData = try? Data(contentsOf: settingsPath),
               let sJson = try? JSONSerialization.jsonObject(with: sData) as? [String: Any] {
                if let m = sJson["model"] as? String, !m.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    detectedModel = m.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let m = sJson["modelSelection"] as? String, !m.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    detectedModel = m.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            if detectedModel == nil, let latestURL = latestTranscriptURL,
               let tContent = try? String(contentsOf: latestURL, encoding: .utf8) {
                let tLines = tContent.split(separator: "\n", maxSplits: 15, omittingEmptySubsequences: true)
                for line in tLines {
                    if line.contains("Model Selection` from") {
                        if let range = line.range(of: "from ") {
                            let substring = line[range.upperBound...]
                            if let toRange = substring.range(of: " to ") {
                                let targetPart = substring[toRange.upperBound...]
                                if let endRange = targetPart.range(of: ".") {
                                    let modelFound = String(targetPart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !modelFound.isEmpty && modelFound != "None" {
                                        detectedModel = modelFound
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            if detectedModel == nil, let cfgModel = self.config.model, !cfgModel.isEmpty {
                detectedModel = cfgModel
            }
            
            let finalModel = detectedModel ?? "Gemini 3.8 Flash (High)"
            
            DispatchQueue.main.async {
                self.data.todayCount = today
                self.data.hourCount = hour
                self.data.slidingBuckets = slidingBuckets
                self.data.rateLimitResetDate = activeRateLimitReset
                self.data.lastRateLimitIncidentDate = latestIncidentDate
                self.data.lastRateLimitIncidentDurationMinutes = latestIncidentMinutes
                self.data.lastTimestamp = lastDate
                self.data.lastQuery = lastText
                self.data.activeWorkspace = cleanWorkspace
                self.data.activeWorkspacePath = workspacePath
                self.data.activeSessionTokens = sessionTokens
                self.data.todayTokens = todayTokens
                self.data.activeModel = finalModel
            }
        }
    }
    
    private func parseTranscriptRateLimit(fileURL: URL, now: Date) -> (activeReset: Date?, incident: (Date, Int)?) {
        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return (nil, nil) }
        defer { try? handle.close() }
        
        let fileSize = handle.seekToEndOfFile()
        guard fileSize > 0 else { return (nil, nil) }
        let readLength: UInt64 = min(fileSize, 65536)
        handle.seek(toFileOffset: fileSize - readLength)
        let data = handle.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8),
              text.contains("RESOURCE_EXHAUSTED") || text.contains("Individual quota reached")
        else {
            return (nil, nil)
        }
        
        var activeReset: Date? = nil
        var incident: (Date, Int)? = nil
        
        let isoFormatterWithFractional = ISO8601DateFormatter()
        isoFormatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterStandard = ISO8601DateFormatter()
        isoFormatterStandard.formatOptions = [.withInternetDateTime]
        
        let lines = text.components(separatedBy: "\n")
        let pattern = "(?:([0-9]+)h\\s*)?(?:([0-9]+)m\\s*)?(?:([0-9]+)s)?"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        for line in lines.reversed() {
            // Filtrer STRICTEMENT les véritables messages d erreur système retournés par l API
            // pour ne pas confondre avec le texte d une question utilisateur ou une réponse de l assistant
            guard line.contains("\"source\":\"SYSTEM\"") && line.contains("\"type\":\"ERROR_MESSAGE\"") && line.contains("RESOURCE_EXHAUSTED") else {
                continue
            }
            
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let errorMsg = json["error"] as? String,
                  errorMsg.contains("RESOURCE_EXHAUSTED")
            else {
                continue
            }
            
            var totalSeconds = 0
            if let resetsRange = errorMsg.range(of: "Resets in ") {
                let sub = String(errorMsg[resetsRange.upperBound...])
                var h = 0, m = 0, s = 0
                let range = NSRange(location: 0, length: min(sub.count, 25))
                if let match = regex?.firstMatch(in: sub, options: [], range: range) {
                    if match.range(at: 1).location != NSNotFound, let rH = Range(match.range(at: 1), in: sub), let val = Int(sub[rH]) { h = val }
                    if match.range(at: 2).location != NSNotFound, let rM = Range(match.range(at: 2), in: sub), let val = Int(sub[rM]) { m = val }
                    if match.range(at: 3).location != NSNotFound, let rS = Range(match.range(at: 3), in: sub), let val = Int(sub[rS]) { s = val }
                    totalSeconds = h * 3600 + m * 60 + s
                }
            }
            
            var createdAtDate: Date? = nil
            if let dateStr = json["created_at"] as? String {
                createdAtDate = isoFormatterWithFractional.date(from: dateStr) ?? isoFormatterStandard.date(from: dateStr)
            }
            
            if let errDate = createdAtDate, totalSeconds > 0 {
                let targetReset = errDate.addingTimeInterval(TimeInterval(totalSeconds))
                if targetReset > now {
                    if activeReset == nil || targetReset > activeReset! {
                        activeReset = targetReset
                    }
                }
                if incident == nil || errDate > incident!.0 {
                    incident = (errDate, totalSeconds / 60)
                }
            }
        }
        
        return (activeReset, incident)
    }
    
    func openConfigFile() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let quotaDir = appSupport.appendingPathComponent("GeminiQuota")
        try? fileManager.createDirectory(at: quotaDir, withIntermediateDirectories: true)
        let configURL = quotaDir.appendingPathComponent("config.json")
        if !fileManager.fileExists(atPath: configURL.path) {
            _ = readConfigFile(quotaDir: quotaDir)
        }
        NSWorkspace.shared.open(configURL)
    }
    
    private func readConfigFile(quotaDir: URL) -> AppConfig {
        let fileManager = FileManager.default
        let configURL = quotaDir.appendingPathComponent("config.json")
        if !fileManager.fileExists(atPath: configURL.path) {
            let sampleConfig = """
            {
              "terminal": "",
              "application": "agy",
              "working_directory": "",
              "proxy_enabled": true,
              "http_proxy": "",
              "https_proxy": "",
              "all_proxy": "",
              "no_proxy": ""
            }
            """
            try? sampleConfig.write(to: configURL, atomically: true, encoding: .utf8)
            return AppConfig(terminal: "", application: "agy", workingDirectory: "", proxyEnabled: true)
        }
        guard let data = try? Data(contentsOf: configURL),
              let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig(terminal: "", application: "agy", workingDirectory: "", proxyEnabled: true)
        }
        return decoded
    }
    
    func loadConfig() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let quotaDir = appSupport.appendingPathComponent("GeminiQuota")
        try? fileManager.createDirectory(at: quotaDir, withIntermediateDirectories: true)
        let loaded = readConfigFile(quotaDir: quotaDir)
        DispatchQueue.main.async {
            self.config = loaded
            self.isProxyEnabled = loaded.proxyEnabled ?? true
        }
    }
    
    func setProxyEnabled(_ enabled: Bool) {
        self.isProxyEnabled = enabled
        self.config.proxyEnabled = enabled
        saveConfig()
    }
    
    func setModel(_ newModel: String) {
        self.data.activeModel = newModel
        self.config.model = newModel
        saveConfig()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let home = fileManager.homeDirectoryForCurrentUser
            let geminiDir = home.appendingPathComponent(".gemini/antigravity-cli")
            try? fileManager.createDirectory(at: geminiDir, withIntermediateDirectories: true)
            let settingsURL = geminiDir.appendingPathComponent("settings.json")
            
            var dict: [String: Any] = [:]
            if let data = try? Data(contentsOf: settingsURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                dict = json
            }
            dict["model"] = newModel
            if let outData = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) {
                try? outData.write(to: settingsURL, options: .atomic)
            }
        }
    }
    
    func saveConfig() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let quotaDir = appSupport.appendingPathComponent("GeminiQuota")
        let configURL = quotaDir.appendingPathComponent("config.json")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self.config) {
            try? data.write(to: configURL)
        }
    }
    
    func openTerminalWithAgy() {
        let path = data.activeWorkspacePath
        let proxyActive = self.isProxyEnabled
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
            let quotaDir = appSupport.appendingPathComponent("GeminiQuota")
            try? fileManager.createDirectory(at: quotaDir, withIntermediateDirectories: true)
            
            let config = self.readConfigFile(quotaDir: quotaDir)
            let scriptURL = quotaDir.appendingPathComponent("open-agy.command")
            
            var targetDir = ""
            if let customDir = config.workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines), !customDir.isEmpty {
                let expanded = (customDir as NSString).expandingTildeInPath
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
                    targetDir = expanded
                }
            }
            
            if targetDir.isEmpty {
                var isDir: ObjCBool = false
                if !path.isEmpty && fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue {
                    targetDir = path
                } else {
                    targetDir = fileManager.homeDirectoryForCurrentUser.path
                }
            }
            
            let escapedDir = targetDir.replacingOccurrences(of: "\"", with: "\\\"")
            
            let proxyBlock: String
            if proxyActive {
                var proxyLines: [String] = []
                if let http = config.httpProxy?.trimmingCharacters(in: .whitespacesAndNewlines), !http.isEmpty {
                    proxyLines.append("export http_proxy=\"\(http)\"")
                    proxyLines.append("export HTTP_PROXY=\"\(http)\"")
                }
                if let https = config.httpsProxy?.trimmingCharacters(in: .whitespacesAndNewlines), !https.isEmpty {
                    proxyLines.append("export https_proxy=\"\(https)\"")
                    proxyLines.append("export HTTPS_PROXY=\"\(https)\"")
                }
                if let all = config.allProxy?.trimmingCharacters(in: .whitespacesAndNewlines), !all.isEmpty {
                    proxyLines.append("export all_proxy=\"\(all)\"")
                    proxyLines.append("export ALL_PROXY=\"\(all)\"")
                }
                if let no = config.noProxy?.trimmingCharacters(in: .whitespacesAndNewlines), !no.isEmpty {
                    proxyLines.append("export no_proxy=\"\(no)\"")
                    proxyLines.append("export NO_PROXY=\"\(no)\"")
                }
                proxyBlock = proxyLines.isEmpty ? "" : proxyLines.joined(separator: "\n") + "\n"
            } else {
                proxyBlock = "unset http_proxy HTTP_PROXY https_proxy HTTPS_PROXY all_proxy ALL_PROXY no_proxy NO_PROXY\n"
            }
            
            let cliApp = (config.application?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "agy"
            
            let scriptContent = """
            #!/bin/zsh -l
            export PATH="$HOME/.local/bin:$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
            \(proxyBlock)cd "\(escapedDir)"
            clear
            \(cliApp)
            exec $SHELL -l
            """
            
            try? scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            
            if let term = config.terminal?.trimmingCharacters(in: .whitespacesAndNewlines), !term.isEmpty {
                proc.arguments = ["-a", term, scriptURL.path]
            } else {
                proc.arguments = ["-a", "Terminal", scriptURL.path]
            }
            try? proc.run()
        }
    }
}

struct PopoverView: View {
    @ObservedObject var model: QuotaModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(nsImage: model.appGeminiIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                    Text("Gemini Quota")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Spacer()
                Text("\(Int(round(model.data.percentageUsed)))% consommé")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(model.deepColor)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: model.deepColor.opacity(0.3), radius: 2, y: 1)
            }
            
            // Grille des 2 métriques : Métrique 3 (Modèle actif) & Métrique 5 (Équivalent API)
            // Dimensions strictement identiques : largeur 50% chacune, hauteur fixe 76pt
            HStack(spacing: 10) {
                // Métrique 3 : Modèle actif (sélecteur interactif)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                        Text("Modèle actif")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Menu {
                        ForEach(QuotaModel.availableModels, id: \.self) { m in
                            Button {
                                model.setModel(m)
                            } label: {
                                if m == model.data.activeModel {
                                    Label(m, systemImage: "checkmark")
                                } else {
                                    Text(m)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(model.data.displayModelName)
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    Spacer(minLength: 0)
                    Text("cliquer pour changer")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Métrique 5 : Équivalent valeur API
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(model.deepColor)
                        Text("Équivalent API")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text(model.data.equivalentApiCost)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(model.deepColor)
                    Spacer(minLength: 0)
                    Text("inclus dans compte")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Jauge des requêtes quotidiennes + Métrique 1 (Reset Countdown)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Requêtes quotidiennes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(model.data.todayCount) / \(model.data.dailyLimit)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Gauge(value: model.data.percentageUsed, in: 0...100) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(model.tintColor)
                
                HStack {
                    Text("\(model.data.remainingRequests) dispo aujourd'hui")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(model.deepColor)
                    Spacer()
                    // Métrique 1 : Compte à rebours avant réinitialisation
                    HStack(spacing: 3) {
                        Image(systemName: "hourglass")
                            .font(.caption2)
                        Text("Reset dans \(model.data.resetCountdown)")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(11)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Carte Fenêtre Glissante (60 min)
            VStack(alignment: .leading, spacing: 7) {
                // Alerte si quota atteint (Erreur 429)
                if model.data.isRateLimited {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Quota individuel atteint (Erreur 429)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("Réinitialisation de la fenêtre dans \(model.data.rateLimitRemainingText)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.95))
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // En-tête de la carte
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.subheadline)
                            .foregroundStyle(model.data.slidingIntensityColor)
                        Text("Fenêtre glissante (60 min)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    
                    // Badge d'intensité
                    Text(model.data.slidingIntensityLabel)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(model.data.slidingIntensityColor.opacity(0.15))
                        .foregroundStyle(model.data.slidingIntensityColor)
                        .clipShape(Capsule())
                }
                
                // Histogramme des 12 tranches de 5 minutes
                VStack(spacing: 3) {
                    HStack(alignment: .bottom, spacing: 5) {
                        ForEach(0..<12, id: \.self) { index in
                            let count = model.data.slidingBuckets[index]
                            let maxVal = max(3, model.data.slidingBuckets.max() ?? 1)
                            let heightFactor = CGFloat(count) / CGFloat(maxVal)
                            let barHeight = max(4.0, heightFactor * 24.0)
                            
                            VStack(spacing: 0) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(slidingBarColor(for: count, index: index, isRateLimited: model.data.isRateLimited))
                                    .frame(height: barHeight)
                            }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                            .help(slidingBucketHelp(for: index, count: count))
                        }
                    }
                    .frame(height: 26, alignment: .bottom)
                    
                    // Axe temporel sous l'histogramme
                    HStack {
                        Text("-60m")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("-30m")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Maintenant")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Statut de la fenêtre & détails
                HStack {
                    Text("\(model.data.hourCount) requête\(model.data.hourCount > 1 ? "s" : "") écoulée\(model.data.hourCount > 1 ? "s" : "")")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Spacer()
                    if model.data.isRateLimited {
                        HStack(spacing: 3) {
                            Image(systemName: "timer")
                                .font(.caption2)
                            Text("Reset : \(model.data.rateLimitRemainingText)")
                        }
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                    } else if let incDate = model.data.lastRateLimitIncidentDate {
                        Text("Dernier pic : \(formatShortTime(incDate)) (levé)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Débit normal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(11)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Carte : Contexte & Tokens
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "brain.head.profile")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        Text("Contexte & Tokens")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    Text("\(formatTokens(model.data.activeSessionTokens)) / 1M")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                
                Gauge(value: min(100.0, model.data.contextPercentage), in: 0...100) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(model.data.contextPercentage > 60 ? .orange : .blue)
                
                HStack {
                    Text("Session : \(String(format: "%.1f%%", model.data.contextPercentage)) de 1M")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Aujourd'hui : ~\(formatTokens(model.data.todayTokens))")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
            .padding(11)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Carte : Dernière requête
            if let lastDate = model.data.lastTimestamp {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Dernière requête (\(formatTime(lastDate)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !model.data.lastQuery.isEmpty {
                        Text(model.data.lastQuery)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Carte Proxy avec interrupteur
            HStack(spacing: 8) {
                Image(systemName: model.isProxyEnabled ? "network" : "network.slash")
                    .font(.subheadline)
                    .foregroundStyle(model.isProxyEnabled ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Proxy")
                            .font(.caption)
                            .fontWeight(.semibold)
                        if model.isProxyEnabled {
                            Text("Actif")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        } else {
                            Text("Inactif")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundStyle(.secondary)
                                .clipShape(Capsule())
                        }
                    }
                    Text(model.isProxyEnabled ? model.proxySummary : "Connexion directe")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button {
                    model.openConfigFile()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Éditer config.json")
                
                Toggle("", isOn: Binding(
                    get: { model.isProxyEnabled },
                    set: { model.setProxyEnabled($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            Divider()
            
            // Footer avec liens et actions
            HStack {
                Button {
                    if let url = URL(string: "https://aistudio.google.com/app/plan_information") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("AI Studio", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Rafraîchir")
                
                Button {
                    model.openConfigFile()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Éditer la configuration (config.json)")
                
                Button {
                    model.openTerminalWithAgy()
                } label: {
                    Image(systemName: "terminal")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Ouvrir un terminal avec \(model.cliAppName) (clic droit : config.json)")
                .contextMenu {
                    Button {
                        model.openConfigFile()
                    } label: {
                        Label("Ouvrir config.json", systemImage: "gearshape")
                    }
                }
                
                Button("Quitter") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    func formatShortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.0fk", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
    
    func slidingBarColor(for count: Int, index: Int, isRateLimited: Bool) -> Color {
        if count == 0 {
            return Color.secondary.opacity(0.18)
        }
        if isRateLimited && index >= 8 {
            return .red
        }
        if count <= 2 {
            return Color.blue.opacity(0.65)
        } else if count <= 5 {
            return Color.blue
        } else if count <= 8 {
            return Color.orange
        } else {
            return Color.red
        }
    }
    
    func slidingBucketHelp(for index: Int, count: Int) -> String {
        let startMin = (12 - index) * 5
        let endMin = startMin - 5
        let rangeStr = endMin == 0 ? "De -5 min à maintenant" : "De -\(startMin)m à -\(endMin)m"
        return "\(rangeStr) : \(count) requête(s)"
    }
}

@main
struct GeminiQuotaApp: App {
    @StateObject private var model = QuotaModel()
    
    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: model.barGraphIcon)
                    .renderingMode(.original)
                if model.data.isRateLimited {
                    Text("⚠️ 429 (\(model.data.rateLimitRemainingText))")
                        .foregroundStyle(.red)
                } else {
                    Text(String(format: "%.1f%%", model.data.percentageUsed))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
