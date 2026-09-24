import SwiftUI
import Foundation
import AppKit
import UserNotifications
import SQLite3


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

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    private(set) var isAuthorized = false
    
    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            self?.isAuthorized = granted
            if let error = error {
                NSLog("GeminiQuota Notification authorization error: %@", error.localizedDescription)
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    func sendNotification(title: String, subtitle: String? = nil, body: String, identifier: String = UUID().uuidString, playSound: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let sub = subtitle, !sub.isEmpty {
            content.subtitle = sub
        }
        content.body = body
        if playSound {
            content.sound = UNNotificationSound.default
        }
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("GeminiQuota error delivering notification: %@", error.localizedDescription)
            }
        }
    }
    
    func sendTestNotification() {
        sendNotification(
            title: "🔔 Test GeminiQuota",
            subtitle: "Notifications actives",
            body: "Le système d'alertes natives macOS fonctionne correctement !",
            identifier: "test-\(Date().timeIntervalSince1970)",
            playSound: true
        )
    }
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
    var notificationsEnabled: Bool? = true
    var notifyThreshold80: Bool? = true
    var notifyThreshold90: Bool? = true
    var notifyThreshold100: Bool? = true
    var notifyOn429: Bool? = true
    var notifySound: Bool? = true
    
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
        case notificationsEnabled = "notifications_enabled"
        case notifyThreshold80 = "notify_threshold_80"
        case notifyThreshold90 = "notify_threshold_90"
        case notifyThreshold100 = "notify_threshold_100"
        case notifyOn429 = "notify_on_429"
        case notifySound = "notify_sound"
    }
    
    init(terminal: String? = nil, application: String? = "agy", workingDirectory: String? = "", proxyEnabled: Bool? = true, model: String? = nil, httpProxy: String? = nil, httpsProxy: String? = nil, allProxy: String? = nil, noProxy: String? = nil, notificationsEnabled: Bool? = true, notifyThreshold80: Bool? = true, notifyThreshold90: Bool? = true, notifyThreshold100: Bool? = true, notifyOn429: Bool? = true, notifySound: Bool? = true) {
        self.terminal = terminal
        self.application = application
        self.workingDirectory = workingDirectory
        self.proxyEnabled = proxyEnabled
        self.model = model
        self.httpProxy = httpProxy
        self.httpsProxy = httpsProxy
        self.allProxy = allProxy
        self.noProxy = noProxy
        self.notificationsEnabled = notificationsEnabled
        self.notifyThreshold80 = notifyThreshold80
        self.notifyThreshold90 = notifyThreshold90
        self.notifyThreshold100 = notifyThreshold100
        self.notifyOn429 = notifyOn429
        self.notifySound = notifySound
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
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        notifyThreshold80 = try container.decodeIfPresent(Bool.self, forKey: .notifyThreshold80) ?? true
        notifyThreshold90 = try container.decodeIfPresent(Bool.self, forKey: .notifyThreshold90) ?? true
        notifyThreshold100 = try container.decodeIfPresent(Bool.self, forKey: .notifyThreshold100) ?? true
        notifyOn429 = try container.decodeIfPresent(Bool.self, forKey: .notifyOn429) ?? true
        notifySound = try container.decodeIfPresent(Bool.self, forKey: .notifySound) ?? true
        
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
        try container.encodeIfPresent(notificationsEnabled, forKey: .notificationsEnabled)
        try container.encodeIfPresent(notifyThreshold80, forKey: .notifyThreshold80)
        try container.encodeIfPresent(notifyThreshold90, forKey: .notifyThreshold90)
        try container.encodeIfPresent(notifyThreshold100, forKey: .notifyThreshold100)
        try container.encodeIfPresent(notifyOn429, forKey: .notifyOn429)
        try container.encodeIfPresent(notifySound, forKey: .notifySound)
    }
}

struct WorkspaceUsage: Identifiable {
    let id = UUID()
    let rawPath: String
    let displayName: String
    let count: Int
    let percentage: Double
    let color: Color
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
    var weekWorkspaces: [WorkspaceUsage] = []
    var todayWorkspaces: [WorkspaceUsage] { weekWorkspaces }
    var displayModelName: String {
        var name = activeModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.lowercased().hasPrefix("gemini ") {
            name = String(name.dropFirst(7))
        } else if name.lowercased().hasPrefix("gemini-") {
            name = String(name.dropFirst(7))
        }
        return name.isEmpty ? "3.8 Flash (High)" : name
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
    
    // État du rate limit pour détection de transition
    private var wasRateLimited: Bool = false
    
    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    init() {
        _ = NotificationManager.shared
        loadConfig()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func sendTestNotification() {
        NotificationManager.shared.sendTestNotification()
    }
    
    func checkAndSendAlerts() {
        guard config.notificationsEnabled ?? true else { return }
        let sound = config.notifySound ?? true
        let todayKey = todayDateString
        let pct = data.percentageUsed
        
        // 1. Seuil 100%
        let key100 = "quota_notified_100_\(todayKey)"
        if pct >= 100.0 {
            if (config.notifyThreshold100 ?? true) && !UserDefaults.standard.bool(forKey: key100) {
                UserDefaults.standard.set(true, forKey: key100)
                UserDefaults.standard.set(true, forKey: "quota_notified_90_\(todayKey)")
                UserDefaults.standard.set(true, forKey: "quota_notified_80_\(todayKey)")
                NotificationManager.shared.sendNotification(
                    title: "🛑 Quota Gemini épuisé (100%)",
                    subtitle: "Limite journalière atteinte",
                    body: "La limite de \(data.dailyLimit) requêtes est atteinte. Réinitialisation à minuit (dans \(data.resetCountdown)).",
                    identifier: "quota-100-\(todayKey)",
                    playSound: sound
                )
            }
        }
        // 2. Seuil 90%
        else if pct >= 90.0 {
            let key90 = "quota_notified_90_\(todayKey)"
            if (config.notifyThreshold90 ?? true) && !UserDefaults.standard.bool(forKey: key90) {
                UserDefaults.standard.set(true, forKey: key90)
                UserDefaults.standard.set(true, forKey: "quota_notified_80_\(todayKey)")
                NotificationManager.shared.sendNotification(
                    title: "⚠️ Quota Gemini critique (90%)",
                    subtitle: "Seuil critique atteint",
                    body: "Attention : 90% du quota consommé (\(data.todayCount) / \(data.dailyLimit) requêtes). Il ne reste que \(data.remainingRequests) requêtes.",
                    identifier: "quota-90-\(todayKey)",
                    playSound: sound
                )
            }
        }
        // 3. Seuil 80%
        else if pct >= 80.0 {
            let key80 = "quota_notified_80_\(todayKey)"
            if (config.notifyThreshold80 ?? true) && !UserDefaults.standard.bool(forKey: key80) {
                UserDefaults.standard.set(true, forKey: key80)
                NotificationManager.shared.sendNotification(
                    title: "🟡 Seuil de quota Gemini (80%)",
                    subtitle: "Avertissement de consommation",
                    body: "80% du quota quotidien consommé (\(data.todayCount) / \(data.dailyLimit) requêtes). Il reste \(data.remainingRequests) requêtes.",
                    identifier: "quota-80-\(todayKey)",
                    playSound: sound
                )
            }
        }
        
        // 4. Détection et rétablissement du blocage 429
        if (config.notifyOn429 ?? true) {
            if data.isRateLimited {
                if !wasRateLimited {
                    wasRateLimited = true
                    NotificationManager.shared.sendNotification(
                        title: "🛑 Gemini : Quota saturé (Erreur 429)",
                        subtitle: "Saturation de la fenêtre glissante",
                        body: "Le débit limite est atteint. Déblocage prévu dans \(data.rateLimitRemainingText).",
                        identifier: "rate-limit-active-\(Date().timeIntervalSince1970)",
                        playSound: sound
                    )
                }
            } else {
                if wasRateLimited {
                    wasRateLimited = false
                    NotificationManager.shared.sendNotification(
                        title: "✅ Gemini : Quota rétabli",
                        subtitle: "Accès de nouveau opérationnel",
                        body: "La fenêtre glissante s'est débloquée. Vous pouvez reprendre vos requêtes normalement.",
                        identifier: "rate-limit-resolved-\(Date().timeIntervalSince1970)",
                        playSound: sound
                    )
                }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    static let workspacePalette: [Color] = [
        Color(red: 0/255.0, green: 122/255.0, blue: 255/255.0),   // Apple Blue
        Color(red: 175/255.0, green: 82/255.0, blue: 222/255.0),  // Apple Purple
        Color(red: 255/255.0, green: 149/255.0, blue: 0/255.0),   // Apple Orange
        Color(red: 52/255.0, green: 199/255.0, blue: 89/255.0),   // Apple Green
        Color(red: 48/255.0, green: 176/255.0, blue: 199/255.0),  // Apple Teal
        Color(red: 255/255.0, green: 45/255.0, blue: 85/255.0),   // Apple Pink
        Color(red: 88/255.0, green: 86/255.0, blue: 214/255.0)    // Apple Indigo
    ]
    
    func cleanWorkspaceName(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasSuffix("/Users/lehuen") || trimmed == "/Users/lehuen" {
            return "Personnel / HAL"
        } else if trimmed.contains("codelab/client_2") {
            return "CodeLab (client 2)"
        } else if trimmed.contains("codelab/client") {
            return "CodeLab (client)"
        } else if trimmed.contains("codelab/server") {
            return "CodeLab (serveur)"
        } else if trimmed.contains("codelab") {
            return "CodeLab"
        } else if trimmed.contains("gemini-quota") {
            return "Gemini Quota"
        } else if trimmed.contains("depot-devoirs") {
            return "Dépôt Devoirs"
        } else if trimmed.contains("www_museeIC2") {
            return "Musée IC2"
        } else if trimmed.contains("diveplanner") {
            return "Diveplanner"
        } else if trimmed.contains("Tutos Github") {
            return "Tutos GitHub"
        } else if trimmed.contains("Université/Github") || trimmed.contains("Université/Github") {
            return "Univ GitHub"
        } else if trimmed.contains("HAL") {
            return "HAL"
        }
        let url = URL(fileURLWithPath: trimmed)
        let last = url.lastPathComponent
        return last.isEmpty ? "Personnel / HAL" : last
    }
    
    func isValidModelName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 50,
              !trimmed.contains("\n"),
              !trimmed.contains("\r"),
              !trimmed.contains("\\"),
              !trimmed.contains("\""),
              !trimmed.contains("{"),
              !trimmed.contains("}") else {
            return false
        }
        return true
    }
    
    // Résout n'importe quelle URI ou chemin de projet vers un dossier physique réel sur disque
    func resolveDirectoryPath(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let fileManager = FileManager.default
        
        var candidate = raw
        
        // 1. Détecter et nettoyer le préfixe URI file://
        if candidate.hasPrefix("file://") {
            if let url = URL(string: candidate) {
                candidate = url.path
            } else if let decoded = candidate.removingPercentEncoding, let url = URL(string: decoded) {
                candidate = url.path
            } else {
                candidate = candidate.replacingOccurrences(of: "file://", with: "")
            }
        }
        
        // 2. Décodage percent-encoding (%20 etc.)
        if let decoded = candidate.removingPercentEncoding {
            candidate = decoded
        }
        
        // 3. Développer le tilde ~/
        candidate = (candidate as NSString).expandingTildeInPath
        
        // 4. Supprimer les slashs de fin superflus
        while candidate.count > 1 && candidate.hasSuffix("/") {
            candidate.removeLast()
        }
        
        // 5. Standardisation
        candidate = (candidate as NSString).standardizingPath
        
        // 6. Test d'existence direct
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: candidate, isDirectory: &isDir) {
            return isDir.boolValue ? candidate : (candidate as NSString).deletingLastPathComponent
        }
        
        // 7. Recherche sous ~/dev/<nom> ou ~/<nom> si chemin relatif ou nom de projet seul
        let home = fileManager.homeDirectoryForCurrentUser.path
        let last = (candidate as NSString).lastPathComponent
        if !last.isEmpty && last != "/" && last != "." {
            let devCandidate = (home as NSString).appendingPathComponent("dev/" + last)
            if fileManager.fileExists(atPath: devCandidate, isDirectory: &isDir), isDir.boolValue {
                return devCandidate
            }
            let homeCandidate = (home as NSString).appendingPathComponent(last)
            if fileManager.fileExists(atPath: homeCandidate, isDirectory: &isDir), isDir.boolValue {
                return homeCandidate
            }
        }
        
        return nil
    }
    
    private func loadWorkspacesFromDB(dbURL: URL) -> [String: String] {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_close(db) }
        
        var stmt: OpaquePointer?
        let sql = "SELECT conversation_id, workspace_uris FROM conversation_summaries"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }
        
        var map: [String: String] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let idPtr = sqlite3_column_text(stmt, 0),
               let uriPtr = sqlite3_column_text(stmt, 1) {
                let id = String(cString: idPtr)
                let rawUris = String(cString: uriPtr)
                if let data = rawUris.data(using: .utf8),
                   let arr = try? JSONSerialization.jsonObject(with: data) as? [String],
                   let first = arr.first {
                    if let resolved = self.resolveDirectoryPath(first) {
                        map[id] = resolved
                    } else if let url = URL(string: first), !url.path.isEmpty {
                        map[id] = url.path
                    } else {
                        map[id] = first
                    }
                } else {
                    map[id] = "/Users/lehuen"
                }
            }
        }
        return map
    }
    
    func refresh() {
        self.loadConfig()
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let home = fileManager.homeDirectoryForCurrentUser
            
            let calendar = Calendar.current
            let now = Date()
            let midnight = calendar.startOfDay(for: now)
            let oneHourAgo = now.addingTimeInterval(-3600)
            let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: midnight) ?? now.addingTimeInterval(-7 * 86400)
            
            var today = 0
            var hour = 0
            var slidingBuckets = Array(repeating: 0, count: 12)
            var lastDate: Date? = nil
            var lastText = ""
            var workspacePath = ""
            var weekWorkspacesCounts: [String: Int] = [:]
            
            // 1. Analyse de history.jsonl pour le terminal CLI agy (s'il existe)
            let cliHistoryPath = home.appendingPathComponent(".gemini/antigravity-cli/history.jsonl")
            if let content = try? String(contentsOf: cliHistoryPath, encoding: .utf8) {
                let lines = content.split(separator: "\n")
                for line in lines {
                    guard let lineData = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any]
                    else { continue }
                    
                    if let tsMillis = json["timestamp"] as? Double {
                        let date = Date(timeIntervalSince1970: tsMillis / 1000.0)
                        let ws = (json["workspace"] as? String) ?? "/Users/lehuen"
                        if date >= midnight {
                            today += 1
                        }
                        if date >= oneWeekAgo {
                            weekWorkspacesCounts[ws, default: 0] += 1
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
                            workspacePath = ws
                        }
                    }
                }
            }
            
            // 2. Analyse multi-sources (Antigravity.app, CLI, IDE)
            var sessionTokens = 0
            var todayTokens = 0
            var latestTranscriptMtime: TimeInterval = 0
            var activeRateLimitReset: Date? = nil
            var latestIncidentDate: Date? = nil
            var latestIncidentMinutes: Int = 0
            
            let isoFormatterFractional = ISO8601DateFormatter()
            isoFormatterFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoFormatterStandard = ISO8601DateFormatter()
            isoFormatterStandard.formatOptions = [.withInternetDateTime]
            
            let sources: [(dirName: String, hasHistoryFile: Bool)] = [
                (".gemini/antigravity", false),      // Antigravity.app (Desktop)
                (".gemini/antigravity-cli", true),    // Antigravity CLI (agy)
                (".gemini/antigravity-ide", false)    // Antigravity IDE (VS Code)
            ]
            
            for source in sources {
                let baseDir = home.appendingPathComponent(source.dirName)
                let brainDir = baseDir.appendingPathComponent("brain")
                guard fileManager.fileExists(atPath: brainDir.path) else { continue }
                
                var workspaceMap: [String: String] = [:]
                if !source.hasHistoryFile {
                    let dbURL = baseDir.appendingPathComponent("conversation_summaries.db")
                    if fileManager.fileExists(atPath: dbURL.path) {
                        workspaceMap = self.loadWorkspacesFromDB(dbURL: dbURL)
                    }
                }
                
                guard let convDirs = try? fileManager.contentsOfDirectory(at: brainDir, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { continue }
                
                for convDir in convDirs {
                    let transcriptURL = convDir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                    guard let values = try? transcriptURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                          let mtime = values.contentModificationDate,
                          let size = values.fileSize else { continue }
                    
                    let tokens = size / 4
                    if mtime >= midnight {
                        todayTokens += tokens
                        
                        let (activeReset, inc) = self.parseTranscriptRateLimit(fileURL: transcriptURL, now: now)
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
                    }
                    
                    // Pour les sources sans fichier history.jsonl, extraire les USER_INPUT de la semaine
                    if !source.hasHistoryFile && mtime >= oneWeekAgo {
                        let convId = convDir.lastPathComponent
                        let ws = workspaceMap[convId] ?? "/Users/lehuen"
                        
                        if let content = try? String(contentsOf: transcriptURL, encoding: .utf8) {
                            let lines = content.split(separator: "\n")
                            for line in lines {
                                guard line.contains("\"type\":\"USER_INPUT\"") || line.contains("\"type\": \"USER_INPUT\"") else { continue }
                                guard let data = line.data(using: .utf8),
                                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                                      let dateStr = json["created_at"] as? String,
                                      let date = (isoFormatterFractional.date(from: dateStr) ?? isoFormatterStandard.date(from: dateStr))
                                else { continue }
                                
                                var query = ""
                                if let rawContent = json["content"] as? String {
                                    if let startTag = rawContent.range(of: "<USER_REQUEST>"),
                                       let endTag = rawContent.range(of: "</USER_REQUEST>") {
                                        query = String(rawContent[startTag.upperBound..<endTag.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                                    } else {
                                        let firstLine = rawContent.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                        query = String(firstLine.prefix(120))
                                    }
                                }
                                
                                if date >= midnight {
                                    today += 1
                                }
                                if date >= oneWeekAgo {
                                    weekWorkspacesCounts[ws, default: 0] += 1
                                }
                                if date >= oneHourAgo && date <= now {
                                    hour += 1
                                    let ageSeconds = now.timeIntervalSince(date)
                                    let bucketIndex = 11 - min(11, max(0, Int(ageSeconds / 300.0)))
                                    slidingBuckets[bucketIndex] += 1
                                }
                                if lastDate == nil || date > lastDate! {
                                    lastDate = date
                                    lastText = query
                                    workspacePath = ws
                                }
                            }
                        }
                    }
                }
            }
            
            // Calcul de la répartition par projet sur la semaine
            let totalWeekReqs = max(1, weekWorkspacesCounts.values.reduce(0, +))
            let sortedWorkspaces = weekWorkspacesCounts.sorted { $0.value > $1.value }
            var computedWorkspaces: [WorkspaceUsage] = []
            for (index, entry) in sortedWorkspaces.enumerated() {
                let pct = (Double(entry.value) / Double(totalWeekReqs)) * 100.0
                let color = QuotaModel.workspacePalette[index % QuotaModel.workspacePalette.count]
                let name = self.cleanWorkspaceName(entry.key)
                computedWorkspaces.append(WorkspaceUsage(
                    rawPath: entry.key,
                    displayName: name,
                    count: entry.value,
                    percentage: pct,
                    color: color
                ))
            }
            
            let cleanWorkspace = self.cleanWorkspaceName(workspacePath)
            
            // 3. Détection du modèle actif
            var detectedModel: String? = nil
            
            // Priorité 1 : settings.json d'Antigravity CLI (~/.gemini/antigravity-cli/settings.json)
            let settingsPath = home.appendingPathComponent(".gemini/antigravity-cli/settings.json")
            if let sData = try? Data(contentsOf: settingsPath),
               let sJson = try? JSONSerialization.jsonObject(with: sData) as? [String: Any] {
                if let m = sJson["model"] as? String, self.isValidModelName(m) {
                    detectedModel = m.trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let m = sJson["modelSelection"] as? String, self.isValidModelName(m) {
                    detectedModel = m.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            // Priorité 2 : Configuration locale GeminiQuota (config.json)
            if detectedModel == nil, let cfgModel = self.config.model, self.isValidModelName(cfgModel) {
                detectedModel = cfgModel.trimmingCharacters(in: .whitespacesAndNewlines)
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
                self.data.weekWorkspaces = computedWorkspaces
                self.data.activeSessionTokens = sessionTokens
                self.data.todayTokens = todayTokens
                self.data.activeModel = finalModel
                self.checkAndSendAlerts()
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
              "notifications_enabled": true,
              "notify_threshold_80": true,
              "notify_threshold_90": true,
              "notify_threshold_100": true,
              "notify_on_429": true,
              "notify_sound": true,
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
    
    func openTerminalWithAgy(workspacePath: String? = nil) {
        let proxyActive = self.isProxyEnabled
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
            let quotaDir = appSupport.appendingPathComponent("GeminiQuota")
            try? fileManager.createDirectory(at: quotaDir, withIntermediateDirectories: true)
            
            let config = self.readConfigFile(quotaDir: quotaDir)
            let scriptURL = quotaDir.appendingPathComponent("open-agy.command")
            
            // Résolution prioritaire et précise du répertoire du projet
            var resolvedTargetDir: String? = nil
            if let specific = workspacePath {
                resolvedTargetDir = self.resolveDirectoryPath(specific)
            }
            if resolvedTargetDir == nil {
                resolvedTargetDir = self.resolveDirectoryPath(self.data.activeWorkspacePath)
            }
            if resolvedTargetDir == nil, let customDir = config.workingDirectory {
                resolvedTargetDir = self.resolveDirectoryPath(customDir)
            }
            
            let finalTargetDir = resolvedTargetDir ?? {
                let devDir = (fileManager.homeDirectoryForCurrentUser.path as NSString).appendingPathComponent("dev")
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: devDir, isDirectory: &isDir), isDir.boolValue {
                    return devDir
                }
                return fileManager.homeDirectoryForCurrentUser.path
            }()
            
            let escapedDir = finalTargetDir.replacingOccurrences(of: "\"", with: "\\\"")
            
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
            
            let term = config.terminal?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if term.lowercased().contains("iterm") {
                let escapedScript = scriptURL.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                let appleScript = """
                tell application "iTerm"
                    activate
                    create window with default profile
                    tell current session of current window
                        write text (quoted form of "\(escapedScript)")
                    end tell
                end tell
                """
                let asProc = Process()
                asProc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                asProc.arguments = ["-e", appleScript]
                try? asProc.run()
            } else {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                if !term.isEmpty {
                    proc.arguments = ["-a", term, scriptURL.path]
                } else {
                    proc.arguments = ["-a", "Terminal", scriptURL.path]
                }
                try? proc.run()
            }
        }
    }
    
    func launchAntigravityApp(workspacePath: String? = nil, forceProxy: Bool? = nil, restart: Bool = false) {
        let proxyActive = forceProxy ?? self.isProxyEnabled
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let defaultAppPath = "/Applications/Antigravity.app"
            let userAppPath = ("~/Applications/Antigravity.app" as NSString).expandingTildeInPath
            let appPath = fileManager.fileExists(atPath: defaultAppPath) ? defaultAppPath :
                          (fileManager.fileExists(atPath: userAppPath) ? userAppPath : defaultAppPath)
            
            guard fileManager.fileExists(atPath: appPath) else {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Antigravity introuvable"
                    alert.informativeText = "L'application Antigravity.app n'a pas été trouvée dans /Applications ni dans ~/Applications."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
                return
            }
            
            if restart {
                let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.antigravity")
                for app in runningApps {
                    app.terminate()
                }
                for _ in 0..<20 {
                    if NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.antigravity").isEmpty {
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
            
            guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
            let quotaDir = appSupport.appendingPathComponent("GeminiQuota")
            let currentConfig = self.readConfigFile(quotaDir: quotaDir)
            
            let proxyServer = (currentConfig.httpsProxy ?? currentConfig.httpProxy ?? currentConfig.allProxy ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            var targetDir = ""
            if let specific = workspacePath, let resolved = self.resolveDirectoryPath(specific) {
                targetDir = resolved
            }
            
            var args: [String] = ["-a", appPath]
            
            if proxyActive && !proxyServer.isEmpty {
                // Injection des variables d'environnement pour le backend Go et sous-processus
                args.append(contentsOf: [
                    "--env", "HTTP_PROXY=\(proxyServer)",
                    "--env", "HTTPS_PROXY=\(proxyServer)",
                    "--env", "http_proxy=\(proxyServer)",
                    "--env", "https_proxy=\(proxyServer)",
                    "--env", "NO_PROXY=localhost,127.0.0.1,::1,.local",
                    "--env", "no_proxy=localhost,127.0.0.1,::1,.local"
                ])
                
                // Liste de contournement (bypass) pour Chromium
                var bypass = "<local>;127.0.0.1;localhost"
                if let customNo = currentConfig.noProxy?.trimmingCharacters(in: .whitespacesAndNewlines), !customNo.isEmpty {
                    bypass += ";" + customNo.replacingOccurrences(of: ",", with: ";")
                }
                
                if !targetDir.isEmpty {
                    args.append(targetDir)
                }
                
                // Drapeaux Chromium pour le moteur Electron
                args.append("--args")
                args.append("--proxy-server=\(proxyServer)")
                args.append("--proxy-bypass-list=\(bypass)")
            } else {
                // Mode direct sans proxy
                args.append(contentsOf: [
                    "--env", "HTTP_PROXY=",
                    "--env", "HTTPS_PROXY=",
                    "--env", "http_proxy=",
                    "--env", "https_proxy="
                ])
                
                if !targetDir.isEmpty {
                    args.append(targetDir)
                }
                
                args.append("--args")
                args.append("--no-proxy-server")
            }
            
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = args
            try? proc.run()
        }
    }
}

// Ligne de projet interactive avec ouverture dans le terminal agy
struct WorkspaceClickableRow: View {
    let ws: WorkspaceUsage
    let cliAppName: String
    let onTerminal: () -> Void
    let onOpenAntigravity: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button {
            onTerminal()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(ws.color)
                    .frame(width: 6.5, height: 6.5)
                Text(ws.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(ws.count) req · \(Int(round(ws.percentage)))%")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                Image(systemName: "terminal")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.secondary)
                    .opacity(isHovered ? 0.85 : 0.0)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 2.5)
            .background(isHovered ? Color.primary.opacity(0.08) : Color.black.opacity(0.0001))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("Ouvrir un terminal \(cliAppName) dans \(ws.displayName)")
        .contextMenu {
            Button {
                onTerminal()
            } label: {
                Label("Ouvrir dans le Terminal (\(cliAppName))", systemImage: "terminal")
            }
            Button {
                onOpenAntigravity()
            } label: {
                Label("Ouvrir dans Antigravity.app", systemImage: "sparkles")
            }
            Divider()
            Button {
                let url = URL(fileURLWithPath: ws.rawPath)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Label("Révéler dans le Finder", systemImage: "folder")
            }
        }
    }
}

struct PopoverView: View {
    @ObservedObject var model: QuotaModel
    
    var body: some View {
        VStack(spacing: 11) {
            // Header (pleine largeur)
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
                
                HStack(spacing: 8) {
                    // Badge Débit horaire (dernière heure)
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("\(model.data.hourCount) req/h")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(Capsule())
                    .help("Activité récente : \(model.data.hourCount) requête\(model.data.hourCount > 1 ? "s" : "") au cours des 60 dernières minutes")
                    
                    // Badge Quota du jour consommé
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
            }
            
            // Grille 2 Colonnes
            HStack(alignment: .top, spacing: 11) {
                // COLONNE GAUCHE : Modèle actif, Quotas quotidiens, Fenêtre glissante, Proxy
                VStack(spacing: 11) {
                    // Carte : Modèle actif (largeur normale, hauteur 64)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.subheadline)
                                    .foregroundStyle(.purple)
                                Text("Modèle actif")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
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
                                HStack(spacing: 4) {
                                    Text(model.data.displayModelName)
                                        .font(.system(size: 11, weight: .bold))
                                        .lineLimit(1)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.purple.opacity(0.12))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                            }
                            .menuStyle(.borderlessButton)
                            .help("Cliquer pour changer de modèle")
                        }
                        
                        Spacer(minLength: 0)
                        
                        Text("Modèle de langage configuré")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Jauge des requêtes quotidiennes + Reset Countdown (hauteur 82)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "terminal.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                                Text("Requêtes quotidiennes")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Text("\(model.data.todayCount) / \(model.data.dailyLimit)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
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
                                .foregroundStyle(.secondary)
                            Spacer()
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
                    .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 82, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Carte Fenêtre Glissante (60 min, hauteur 180)
                    VStack(alignment: .leading, spacing: 6) {
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
                                    Text("Reset dans \(model.data.rateLimitRemainingText)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.95))
                                }
                                Spacer()
                            }
                            .padding(6)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        // En-tête de la carte
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                                Text("Fenêtre glissante (60 min)")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
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
                        let maxChartHeight: CGFloat = model.data.isRateLimited ? 44.0 : 82.0
                        VStack(spacing: 3) {
                            HStack(alignment: .bottom, spacing: 5) {
                                ForEach(0..<12, id: \.self) { index in
                                    let count = model.data.slidingBuckets[index]
                                    let maxVal = max(3, model.data.slidingBuckets.max() ?? 1)
                                    let heightFactor = CGFloat(count) / CGFloat(maxVal)
                                    let barHeight = max(4.0, heightFactor * (maxChartHeight - 2.0))
                                    
                                    VStack(spacing: 0) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(slidingBarColor(for: count, index: index, isRateLimited: model.data.isRateLimited))
                                            .frame(height: barHeight)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .bottom)
                                    .help(slidingBucketHelp(for: index, count: count))
                                }
                            }
                            .frame(height: maxChartHeight, alignment: .bottom)
                            
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
                        
                        Spacer(minLength: 0)
                        
                        // Statut de la fenêtre & détails
                        HStack {
                            Text("\(model.data.hourCount) requête\(model.data.hourCount > 1 ? "s" : "") écoulée\(model.data.hourCount > 1 ? "s" : "")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180, alignment: .topLeading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Carte : Proxy avec interrupteur (largeur normale de colonne)
                    HStack(spacing: 8) {
                        Image(systemName: model.isProxyEnabled ? "network" : "network.slash")
                            .font(.subheadline)
                            .foregroundStyle(model.isProxyEnabled ? .blue : .secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("Proxy")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
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
                        
                        Toggle("", isOn: Binding(
                            get: { model.isProxyEnabled },
                            set: { model.setProxyEnabled($0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                    }
                    .padding(11)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity)
                
                // COLONNE DROITE : Équivalent API, Tokens, Projets de la semaine (Rien sous projets)
                VStack(spacing: 11) {
                    // Carte : Équivalent API (largeur normale, hauteur 64)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                                Text("Équivalent API")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Text(model.data.equivalentApiCost)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(model.deepColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(model.deepColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        Spacer(minLength: 0)
                        
                        Text("Valeur commerciale incluse dans le compte")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 64, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Carte : Contexte & Tokens (hauteur 82)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "character.bubble.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                                Text("Contexte & Tokens")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
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
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, minHeight: 82, maxHeight: 82, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Carte : Projets de la semaine (Multi-Workspaces, hauteur 180)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Image(systemName: "folder.fill")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                            Text("Projets de la semaine")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        
                        // Barre segmentée façon stockage macOS
                        if !model.data.weekWorkspaces.isEmpty {
                            let topLimit = 6
                            let topWorkspaces = Array(model.data.weekWorkspaces.prefix(topLimit))
                            let otherWorkspaces = Array(model.data.weekWorkspaces.dropFirst(topLimit))
                            let otherCount = otherWorkspaces.reduce(0) { $0 + $1.count }
                            let otherPercentage = otherWorkspaces.reduce(0.0) { $0 + $1.percentage }
                            let hasOthers = !otherWorkspaces.isEmpty && otherCount > 0
                            
                            let segmentCount = topWorkspaces.count + (hasOthers ? 1 : 0)
                            let totalBarWidth: CGFloat = 253.0
                            let spacingWidth: CGFloat = CGFloat(max(0, segmentCount - 1)) * 2.0
                            let usableWidth: CGFloat = max(10.0, totalBarWidth - spacingWidth)
                            
                            HStack(spacing: 2) {
                                ForEach(topWorkspaces) { ws in
                                    let barW = max(3.0, usableWidth * CGFloat(ws.percentage / 100.0))
                                    Button {
                                        model.openTerminalWithAgy(workspacePath: ws.rawPath)
                                    } label: {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(ws.color)
                                            .frame(width: barW, height: 7)
                                    }
                                    .buttonStyle(.plain)
                                    .help("\(ws.displayName) : \(ws.count) requête(s) (\(String(format: "%.1f", ws.percentage))%) - Clic pour ouvrir dans le terminal (\(model.cliAppName))")
                                }
                                if hasOthers {
                                    let otherBarW = max(3.0, usableWidth * CGFloat(otherPercentage / 100.0))
                                    let otherHelpText: String = otherWorkspaces.count == 1
                                        ? "\(otherWorkspaces.first?.displayName ?? "Autre projet") : \(otherCount) requête(s) (\(String(format: "%.1f", otherPercentage))%)"
                                        : "Autres projets (\(otherWorkspaces.count)) : \(otherCount) requête(s) (\(String(format: "%.1f", otherPercentage))%)"
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.5))
                                        .frame(width: otherBarW, height: 7)
                                        .help(otherHelpText)
                                }
                            }
                            .frame(height: 7)
                            .padding(.top, 5)
                            
                            // Liste des projets (top 6, cliquables pour ouvrir dans le terminal agy)
                            VStack(spacing: 3) {
                                ForEach(topWorkspaces) { ws in
                                    WorkspaceClickableRow(
                                        ws: ws,
                                        cliAppName: model.cliAppName,
                                        onTerminal: {
                                            model.openTerminalWithAgy(workspacePath: ws.rawPath)
                                        },
                                        onOpenAntigravity: {
                                            model.launchAntigravityApp(workspacePath: ws.rawPath)
                                        }
                                    )
                                }
                            }
                            .padding(.top, 2)
                            
                            Spacer(minLength: 0)
                        } else {
                            Spacer(minLength: 0)
                            Text("Aucune interaction projet cette semaine")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 180, alignment: .topLeading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity)
            }
            
            Divider()
            
            // Footer avec liens et actions
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Button {
                        if let url = URL(string: "https://aistudio.google.com") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("AI Studio", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Ouvrir Google AI Studio (clic droit : quotas / clés API)")
                    .contextMenu {
                        Button {
                            if let url = URL(string: "https://aistudio.google.com") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Accueil AI Studio", systemImage: "sparkles")
                        }
                        Button {
                            if let url = URL(string: "https://aistudio.google.com/usage") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Consommation & Quotas", systemImage: "chart.bar")
                        }
                        Button {
                            if let url = URL(string: "https://aistudio.google.com/app/apikey") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Clés API", systemImage: "key")
                        }
                    }
                    
                    Button {
                        model.launchAntigravityApp()
                    } label: {
                        Label("Antigravity", systemImage: "sparkles")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Lancer Antigravity.app (\(model.isProxyEnabled ? "avec proxy" : "connexion directe")) - Clic droit : options")
                    .contextMenu {
                        if !model.data.weekWorkspaces.isEmpty {
                            Text("Ouvrir Antigravity dans :")
                            ForEach(model.data.weekWorkspaces.prefix(6)) { ws in
                                Button {
                                    model.launchAntigravityApp(workspacePath: ws.rawPath)
                                } label: {
                                    Label(ws.displayName, systemImage: "folder")
                                }
                            }
                            Divider()
                        }
                        Button {
                            model.launchAntigravityApp(forceProxy: true)
                        } label: {
                            Label("Lancer avec proxy", systemImage: "network")
                        }
                        Button {
                            model.launchAntigravityApp(forceProxy: false)
                        } label: {
                            Label("Lancer sans proxy (direct)", systemImage: "network.slash")
                        }
                        Divider()
                        Button {
                            model.launchAntigravityApp(restart: true)
                        } label: {
                            Label("Relancer Antigravity (Appliquer)", systemImage: "arrow.clockwise")
                        }
                    }
                    
                    Button {
                        model.openTerminalWithAgy()
                    } label: {
                        Label("Terminal agy", systemImage: "terminal")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Ouvrir un terminal avec \(model.cliAppName) (clic droit : config.json)")
                    .contextMenu {
                        if !model.data.weekWorkspaces.isEmpty {
                            Text("Ouvrir terminal dans :")
                            ForEach(model.data.weekWorkspaces.prefix(6)) { ws in
                                Button {
                                    model.openTerminalWithAgy(workspacePath: ws.rawPath)
                                } label: {
                                    Label(ws.displayName, systemImage: "folder")
                                }
                            }
                            Divider()
                        }
                        Button {
                            model.openConfigFile()
                        } label: {
                            Label("Ouvrir config.json", systemImage: "gearshape")
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
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
                    .help("Éditer la configuration (clic droit : options & test)")
                    .contextMenu {
                        Button {
                            model.openConfigFile()
                        } label: {
                            Label("Ouvrir config.json", systemImage: "gearshape")
                        }
                        Divider()
                        Button {
                            model.sendTestNotification()
                        } label: {
                            Label("Tester une notification", systemImage: "bell.badge")
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
        }
        .padding(14)
        .frame(width: 590)
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
