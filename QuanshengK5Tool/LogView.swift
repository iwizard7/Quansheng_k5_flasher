import SwiftUI
import AppKit

struct LogView: View {
    @ObservedObject var logManager: LogManager
    @State private var selectedLogLevel: LogLevel? = nil
    @State private var searchText = ""
    @State private var autoScroll = true
    
    var filteredEntries: [LogEntry] {
        var entries = logManager.logEntries
        
        // Фильтр по уровню
        if let selectedLevel = selectedLogLevel {
            entries = entries.filter { $0.level == selectedLevel }
        }
        
        // Фильтр по тексту
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return entries
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Журнал работы")
                .font(.headline)
            
            // Панель управления
            HStack {
                // Фильтр по уровню
                Picker("Уровень", selection: $selectedLogLevel) {
                    Text("Все").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue.capitalized).tag(level as LogLevel?)
                    }
                }
                .frame(width: 120)
                
                Spacer()
                
                // Поиск
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Поиск в логах...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                }
                
                Spacer()
                
                // Управление
                Toggle("Автопрокрутка", isOn: $autoScroll)
                
                Button("Очистить") {
                    logManager.clearLog()
                }
                
                Button("Экспорт") {
                    exportLog()
                }
                .disabled(logManager.logEntries.isEmpty)
            }
            
            // Статистика
            HStack {
                let stats = calculateStats()
                ForEach(LogLevel.allCases, id: \.self) { level in
                    HStack {
                        Circle()
                            .fill(level.color)
                            .frame(width: 8, height: 8)
                        Text("\(level.rawValue.capitalized): \(stats[level] ?? 0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text("Всего: \(logManager.logEntries.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Список логов
            if filteredEntries.isEmpty {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(logManager.logEntries.isEmpty ? "Журнал пуст" : "Записи не найдены")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(logManager.logEntries.isEmpty ? "Записи будут появляться здесь по мере работы приложения" : "Попробуйте изменить фильтры")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(filteredEntries) { entry in
                                LogEntryView(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .onChange(of: filteredEntries.count) {
                        if autoScroll && !filteredEntries.isEmpty {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(filteredEntries.last?.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func calculateStats() -> [LogLevel: Int] {
        var stats: [LogLevel: Int] = [:]
        for level in LogLevel.allCases {
            stats[level] = logManager.logEntries.filter { $0.level == level }.count
        }
        return stats
    }
    
    private func exportLog() {
        let savePanel = NSSavePanel()
        savePanel.title = "Экспорт журнала"
        savePanel.allowedContentTypes = [.plainText, .json]
        savePanel.nameFieldStringValue = "K5_Log_\(DateFormatter.filenameDateFormatter.string(from: Date()))"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let content: String
                
                if url.pathExtension.lowercased() == "json" {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    encoder.dateEncodingStrategy = .iso8601
                    
                    let exportData = LogExport(
                        exportDate: Date(),
                        totalEntries: logManager.logEntries.count,
                        entries: logManager.logEntries.map { entry in
                            LogExportEntry(
                                timestamp: entry.timestamp,
                                level: entry.level.rawValue,
                                message: entry.message
                            )
                        }
                    )
                    
                    let data = try encoder.encode(exportData)
                    content = String(data: data, encoding: .utf8) ?? ""
                } else {
                    content = logManager.exportLog()
                }
                
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Ошибка экспорта лога: \(error)")
            }
        }
    }
}

struct LogEntryView: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Индикатор уровня
            Circle()
                .fill(entry.level.color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(DateFormatter.logTimeFormatter.string(from: entry.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    
                    Text(entry.level.rawValue.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(entry.level.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(entry.level.color.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                }
                
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

// MARK: - Структуры для экспорта

struct LogExport: Codable {
    let exportDate: Date
    let totalEntries: Int
    let entries: [LogExportEntry]
}

struct LogExportEntry: Codable {
    let timestamp: Date
    let level: String
    let message: String
}

// MARK: - Расширения DateFormatter

extension DateFormatter {
    static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

#Preview {
    LogView(logManager: LogManager.shared)
}