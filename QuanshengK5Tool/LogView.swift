import SwiftUI

struct LogView: View {
    @ObservedObject var logManager: LogManager
    @State private var selectedLevel: LogLevel? = nil
    @State private var searchText = ""
    
    var filteredEntries: [LogEntry] {
        var entries = logManager.logEntries
        
        // Фильтр по уровню
        if let level = selectedLevel {
            entries = entries.filter { $0.level == level }
        }
        
        // Фильтр по тексту
        if !searchText.isEmpty {
            entries = entries.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        
        return entries
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Панель управления
            HStack {
                // Поиск
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Поиск в логе...", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .frame(maxWidth: 200)
                
                Spacer()
                
                // Фильтр по уровню
                Menu {
                    Button("Все уровни") {
                        selectedLevel = nil
                    }
                    
                    Divider()
                    
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button(level.rawValue.capitalized) {
                            selectedLevel = level
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedLevel?.rawValue.capitalized ?? "Все уровни")
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
                
                // Кнопки управления
                Button("Экспорт") {
                    exportLog()
                }
                .buttonStyle(.bordered)
                
                Button("Очистить") {
                    logManager.clearLog()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Список записей лога
            if filteredEntries.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Лог пуст" : "Записи не найдены")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    if !searchText.isEmpty {
                        Text("Попробуйте изменить критерии поиска")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } else {
                ScrollViewReader { proxy in
                    List(filteredEntries) { entry in
                        LogEntryRow(entry: entry)
                            .id(entry.id)
                    }
                    .listStyle(PlainListStyle())
                    .onChange(of: logManager.logEntries.count) { _ in
                        // Автоскролл к последней записи
                        if let lastEntry = logManager.logEntries.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastEntry.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Лог работы")
    }
    
    private func exportLog() {
        let savePanel = NSSavePanel()
        savePanel.title = "Экспорт лога"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "K5Tool_Log_\(formatDateForFilename(Date())).txt"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let logContent = logManager.exportLog()
                try logContent.write(to: url, atomically: true, encoding: .utf8)
                logManager.log("Лог экспортирован в файл: \(url.lastPathComponent)", level: .success)
            } catch {
                logManager.log("Ошибка экспорта лога: \(error.localizedDescription)", level: .error)
            }
        }
    }
    
    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }
}

struct LogEntryRow: View {
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
                    Text(formatTime(entry.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("[\(entry.level.rawValue.uppercased())]")
                        .font(.caption)
                        .foregroundColor(entry.level.color)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                Text(entry.message)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

#Preview {
    let logManager = LogManager()
    logManager.log("Приложение запущено", level: .info)
    logManager.log("Поиск USB устройств...", level: .debug)
    logManager.log("Найдено 3 серийных порта", level: .info)
    logManager.log("Подключение к порту /dev/cu.usbserial-1420", level: .info)
    logManager.log("Соединение установлено", level: .success)
    logManager.log("Чтение версии прошивки...", level: .debug)
    logManager.log("Версия прошивки: 2.1.27", level: .info)
    logManager.log("Внимание: низкий заряд батареи", level: .warning)
    logManager.log("Ошибка чтения калибровки", level: .error)
    
    return LogView(logManager: logManager)
        .frame(width: 600, height: 400)
}