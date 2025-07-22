import Foundation
import SwiftUI

// Простая версия LogManager для начала
class SimpleLogManager: ObservableObject {
    @Published var logEntries: [String] = []
    private let maxLogEntries = 100
    
    func log(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let logEntry = "[\(timestamp)] \(message)"
            
            self.logEntries.append(logEntry)
            
            // Ограничиваем количество записей
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
            }
        }
        
        // Также выводим в консоль
        print(message)
    }
    
    func clearLog() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
        }
    }
    
    func exportLog() -> String {
        return logEntries.joined(separator: "\n")
    }
}