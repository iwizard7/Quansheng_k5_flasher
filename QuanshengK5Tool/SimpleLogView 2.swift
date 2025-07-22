import SwiftUI

// Простая версия LogView для начала
struct SimpleLogView: View {
    @ObservedObject var logManager: SimpleLogManager
    @State private var searchText = ""
    
    var filteredEntries: [String] {
        if searchText.isEmpty {
            return logManager.logEntries
        } else {
            return logManager.logEntries.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
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
                    List(Array(filteredEntries.enumerated()), id: \.offset) { index, entry in
                        Text(entry)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .id(index)
                    }
                    .listStyle(PlainListStyle())
                    .onChange(of: logManager.logEntries.count) { _ in
                        // Автоскролл к последней записи
                        if !filteredEntries.isEmpty {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(filteredEntries.count - 1, anchor: .bottom)
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
                logManager.log("Лог экспортирован в файл: \(url.lastPathComponent)")
            } catch {
                logManager.log("Ошибка экспорта лога: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: date)
    }
}

#Preview {
    let logManager = SimpleLogManager()
    logManager.log("Приложение запущено")
    logManager.log("Поиск USB устройств...")
    logManager.log("Найдено 3 серийных порта")
    logManager.log("Подключение к порту /dev/cu.usbserial-1420")
    logManager.log("Соединение установлено")
    
    return SimpleLogView(logManager: logManager)
        .frame(width: 600, height: 400)
}