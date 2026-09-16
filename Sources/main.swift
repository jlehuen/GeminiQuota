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

struct QuotaData {
    var todayCount: Int = 0
    var dailyLimit: Int = 1000
    var hourCount: Int = 0
    var lastTimestamp: Date? = nil
    var lastQuery: String = ""
    var activeWorkspace: String = "CodeLab"
    var activeWorkspacePath: String = ""
    
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
}

class QuotaModel: ObservableObject {
    @Published var data = QuotaData()
    private var timer: Timer?
    
    var nsColor: NSColor {
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
                        if date >= oneHourAgo {
                            hour += 1
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
            
            if let enumerator = fileManager.enumerator(at: brainPath, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: []) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent == "transcript.jsonl" {
                        if let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                           let mtime = values.contentModificationDate,
                           let size = values.fileSize {
                            let tokens = size / 4
                            if mtime >= midnight {
                                todayTokens += tokens
                            }
                            let timeInterval = mtime.timeIntervalSince1970
                            if timeInterval > latestTranscriptMtime {
                                latestTranscriptMtime = timeInterval
                                sessionTokens = tokens
                            }
                        }
                    }
                }
            }
            
            let cleanWorkspace = self.cleanWorkspaceName(workspacePath)
            
            DispatchQueue.main.async {
                self.data.todayCount = today
                self.data.hourCount = hour
                self.data.lastTimestamp = lastDate
                self.data.lastQuery = lastText
                self.data.activeWorkspace = cleanWorkspace
                self.data.activeWorkspacePath = workspacePath
                self.data.activeSessionTokens = sessionTokens
                self.data.todayTokens = todayTokens
            }
        }
    }
    
    func openTerminalWithAgy() {
        let path = data.activeWorkspacePath
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
            let quotaDir = appSupport.appendingPathComponent("GeminiQuota")
            try? fileManager.createDirectory(at: quotaDir, withIntermediateDirectories: true)
            
            let scriptURL = quotaDir.appendingPathComponent("open-agy.command")
            
            var targetDir = path
            var isDir: ObjCBool = false
            if targetDir.isEmpty || !fileManager.fileExists(atPath: targetDir, isDirectory: &isDir) || !isDir.boolValue {
                targetDir = fileManager.homeDirectoryForCurrentUser.path
            }
            
            let escapedDir = targetDir.replacingOccurrences(of: "\"", with: "\\\"")
            
            let scriptContent = """
            #!/bin/zsh -l
            export PATH="$HOME/.local/bin:$HOME/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
            cd "\(escapedDir)"
            clear
            agy
            exec $SHELL -l
            """
            
            try? scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try? fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            
            let iTermAppPath = "/Applications/iTerm.app"
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            if fileManager.fileExists(atPath: iTermAppPath) {
                proc.arguments = ["-a", iTermAppPath, scriptURL.path]
            } else {
                proc.arguments = [scriptURL.path]
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
            
            // Grille des 2 métriques : Métrique 3 (Projet actif) & Métrique 5 (Équivalent API)
            // Dimensions strictement identiques : largeur 50% chacune, hauteur fixe 76pt
            HStack(spacing: 10) {
                // Métrique 3 : Projet actif
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text("Projet actif")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text(model.data.activeWorkspace)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(model.data.hourCount) req dernière heure")
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
                    model.openTerminalWithAgy()
                } label: {
                    Label("agy", systemImage: "terminal")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Ouvrir un terminal avec la commande agy")
                
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
    
    func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.0fk", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
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
                Text(String(format: "%.1f%%", model.data.percentageUsed))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
