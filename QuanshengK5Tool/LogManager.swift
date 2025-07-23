import Foundation
import SwiftUI

class LogManager: ObservableObject {
    static let shared = LogManager()
    
    @Published var logEntries: [LogEntry] = []
    private let maxLogEntries = 1000
    
    private init() {}
    
    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message
        )
        
        DispatchQueue.main.async {
            self.logEntries.append(entry)
            
            // Ограничиваем количество записей в логе
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
            }
        }
        
        // Также выводим в консоль для отладки
        print("[\(level.rawValue.uppercased())] \(message)")
    }
    
    func clearLog() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
        }
    }
    
    func exportLog() -> String {
        return logEntries.map { entry in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return "[\(formatter.string(from: entry.timestamp))] [\(entry.level.rawValue.uppercased())] \(entry.message)"
        }.joined(separator: "\n")
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
}

enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case success = "success"
    
    var color: Color {
        switch self {
        case .debug:
            return .gray
        case .info:
            return .primary
        case .warning:
            return .orange
        case .error:
            return .red
        case .success:
            return .green
        }
    }
}