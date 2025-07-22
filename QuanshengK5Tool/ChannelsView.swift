import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ChannelsView: View {
    @ObservedObject var usbManager: USBCommunicationManager
    @State private var channels: [K5Channel] = []
    @State private var isLoading = false
    @State private var selectedChannel: K5Channel?
    @State private var showingChannelEditor = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Уведомление"
    @State private var searchText = ""
    
    var filteredChannels: [K5Channel] {
        if searchText.isEmpty {
            return channels
        } else {
            return channels.filter { channel in
                channel.name.localizedCaseInsensitiveContains(searchText) ||
                String(format: "%.5f", channel.frequency).contains(searchText) ||
                String(channel.index + 1).contains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Управление каналами")
                .font(.headline)
            
            // Панель управления
            HStack {
                Button("Считать каналы") {
                    readChannels()
                }
                .disabled(!usbManager.isConnected || isLoading)
                
                Button("Записать каналы") {
                    writeChannels()
                }
                .disabled(!usbManager.isConnected || isLoading || channels.isEmpty)
                
                Spacer()
                
                Button("Добавить канал") {
                    addNewChannel()
                }
                
                Button("Импорт") {
                    importChannels()
                }
                
                Button("Экспорт") {
                    exportChannels()
                }
                .disabled(channels.isEmpty)
            }
            
            // Поиск
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Поиск каналов...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Список каналов
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Загрузка каналов...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if filteredChannels.isEmpty {
                VStack {
                    Image(systemName: "radio")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(channels.isEmpty ? "Каналы не загружены" : "Каналы не найдены")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(channels.isEmpty ? "Нажмите 'Считать каналы' для загрузки" : "Попробуйте изменить поисковый запрос")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredChannels, id: \.index) { channel in
                            ChannelRowView(
                                channel: channel,
                                onEdit: {
                                    selectedChannel = channel
                                    showingChannelEditor = true
                                },
                                onDelete: {
                                    deleteChannel(channel)
                                }
                            )
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Статистика
            if !channels.isEmpty {
                HStack {
                    Text("Всего каналов: \(channels.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let validationErrors = K5Utilities.validateChannels(channels)
                    if validationErrors.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Все каналы корректны")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Ошибок: \(validationErrors.count)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingChannelEditor) {
            if let channel = selectedChannel {
                ChannelEditorView(channel: channel) { updatedChannel in
                    updateChannel(updatedChannel)
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func readChannels() {
        isLoading = true
        Task {
            let loadedChannels = await usbManager.readChannels()
            await MainActor.run {
                channels = loadedChannels
                isLoading = false
                if channels.isEmpty {
                    showAlert(title: "Информация", message: "Каналы не найдены или устройство не подключено")
                } else {
                    showAlert(title: "Успех", message: "Загружено каналов: \(channels.count)")
                }
            }
        }
    }
    
    private func writeChannels() {
        isLoading = true
        Task {
            let success = await usbManager.writeChannels(channels)
            await MainActor.run {
                isLoading = false
                if success {
                    showAlert(title: "Успех", message: "Каналы записаны в устройство")
                } else {
                    showAlert(title: "Ошибка", message: "Не удалось записать каналы в устройство")
                }
            }
        }
    }
    
    private func addNewChannel() {
        let newChannel = K5Channel(
            index: channels.count,
            frequency: 145.0,
            name: "Новый",
            txPower: 1,
            bandwidth: .narrow,
            scrambler: false,
            rxTone: .none,
            txTone: .none
        )
        selectedChannel = newChannel
        showingChannelEditor = true
    }
    
    private func updateChannel(_ updatedChannel: K5Channel) {
        if let index = channels.firstIndex(where: { $0.index == updatedChannel.index }) {
            channels[index] = updatedChannel
        } else {
            channels.append(updatedChannel)
            channels.sort { $0.index < $1.index }
        }
    }
    
    private func deleteChannel(_ channel: K5Channel) {
        channels.removeAll { $0.index == channel.index }
    }
    
    private func importChannels() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Импорт каналов"
        openPanel.allowedContentTypes = [.json, .commaSeparatedText]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let importedChannels: [K5Channel]
                
                if url.pathExtension.lowercased() == "json" {
                    importedChannels = try K5Utilities.importChannels(from: url)
                } else {
                    importedChannels = try K5Utilities.importChannelsFromCSV(from: url)
                }
                
                channels = importedChannels
                showAlert(title: "Успех", message: "Импортировано каналов: \(importedChannels.count)")
            } catch {
                showAlert(title: "Ошибка", message: "Не удалось импортировать каналы: \(error.localizedDescription)")
            }
        }
    }
    
    private func exportChannels() {
        let savePanel = NSSavePanel()
        savePanel.title = "Экспорт каналов"
        savePanel.allowedContentTypes = [.json, .commaSeparatedText]
        savePanel.nameFieldStringValue = "K5_Channels"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                if url.pathExtension.lowercased() == "json" {
                    try K5Utilities.exportChannels(channels, to: url)
                } else {
                    try K5Utilities.exportChannelsToCSV(channels, to: url)
                }
                showAlert(title: "Успех", message: "Каналы экспортированы в файл: \(url.lastPathComponent)")
            } catch {
                showAlert(title: "Ошибка", message: "Не удалось экспортировать каналы: \(error.localizedDescription)")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

#Preview {
    ChannelsView(usbManager: USBCommunicationManager())
}