import UIKit
import Foundation

actor AppLogger {
    static let shared = AppLogger()

    private var logs: [(timestamp: Date, event: String)] = []
    private let maxLogs = 500

    private init() {}

    func log(_ event: String) {
        logs.append((timestamp: Date(), event: event))
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }

    func getAllLogs() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return logs.map { "[\(formatter.string(from: $0.timestamp))] \($0.event)" }.joined(separator: "\n")
    }

    func getDiagnostics(username: String?) -> String {
        var lines: [String] = []
        lines.append("=== App Diagnostics ===")
        lines.append("Date: \(Date().formatted())")
        lines.append("App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
        lines.append("iOS: \(UIDevice.current.systemVersion)")
        lines.append("Device: \(UIDevice.current.model)")
        if let username { lines.append("User: \(username)") }
        lines.append("Log entries: \(logs.count)")
        lines.append("")
        lines.append("=== Recent Events ===")

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"

        for entry in logs.suffix(100) {
            lines.append("[\(formatter.string(from: entry.timestamp))] \(entry.event)")
        }

        return lines.joined(separator: "\n")
    }
}

// Convenience global function
func appLog(_ event: String) {
    Task { await AppLogger.shared.log(event) }
}
