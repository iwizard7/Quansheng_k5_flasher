import SwiftUI

struct InfoView: View {
    @ObservedObject var usbManager: USBCommunicationManager
    @State private var deviceInfo = K5DeviceInfo()
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Информация"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Информация об устройстве")
                .font(.headline)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Чтение информации об устройстве...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Основная информация
                        GroupBox("Основная информация") {
                            VStack(alignment: .leading, spacing: 10) {
                                InfoRow(label: "Модель", value: deviceInfo.model)
                                InfoRow(label: "Вольтаж батареи", value: String(format: "%.2f В", deviceInfo.batteryVoltage))
                            }
                            .padding()
                        }
                        
                        // Информация о прошивке
                        GroupBox("Прошивка") {
                            VStack(alignment: .leading, spacing: 10) {
                                InfoRow(label: "Версия прошивки", value: deviceInfo.firmwareVersion)
                                InfoRow(label: "Версия загрузчика", value: deviceInfo.bootloaderVersion)
                            }
                            .padding()
                        }
                        
                        // Статус подключения
                        GroupBox("Подключение") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Статус:")
                                        .fontWeight(.medium)
                                    Spacer()
                                    HStack {
                                        Circle()
                                            .fill(usbManager.isConnected ? Color.green : Color.red)
                                            .frame(width: 12, height: 12)
                                        Text(usbManager.isConnected ? "Подключено" : "Не подключено")
                                            .foregroundColor(usbManager.isConnected ? .green : .red)
                                    }
                                }
                                
                                if let selectedPort = usbManager.selectedPort {
                                    InfoRow(label: "Порт", value: selectedPort.displayName)
                                }
                                
                                InfoRow(label: "Доступно портов", value: "\(usbManager.availablePorts.count)")
                            }
                            .padding()
                        }
                        

                        
                        // Кнопки действий
                        HStack {
                            Button("Обновить информацию") {
                                readDeviceInfo()
                            }
                            .disabled(!usbManager.isConnected || isLoading)
                            
                            Spacer()
                            
                            Button("Экспорт информации") {
                                exportDeviceInfo()
                            }
                            .disabled(deviceInfo.model == "Неизвестно")
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            if usbManager.isConnected {
                readDeviceInfo()
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func readDeviceInfo() {
        isLoading = true
        Task {
            let info = await usbManager.readDeviceInfo()
            await MainActor.run {
                deviceInfo = info
                isLoading = false
            }
        }
    }
    
    private func exportDeviceInfo() {
        let savePanel = NSSavePanel()
        savePanel.title = "Экспорт информации об устройстве"
        savePanel.allowedContentTypes = [.json, .plainText]
        savePanel.nameFieldStringValue = "K5_Device_Info_\(deviceInfo.model)"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let content: String
                
                if url.pathExtension.lowercased() == "json" {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    encoder.dateEncodingStrategy = .iso8601
                    
                    let data = try encoder.encode(deviceInfo)
                    content = String(data: data, encoding: .utf8) ?? ""
                } else {
                    content = formatDeviceInfoAsText()
                }
                
                try content.write(to: url, atomically: true, encoding: .utf8)
                showAlert(title: "Успех", message: "Информация об устройстве экспортирована")
            } catch {
                showAlert(title: "Ошибка", message: "Не удалось экспортировать информацию: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatDeviceInfoAsText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return """
        Информация об устройстве Quansheng K5
        =====================================
        
        Основная информация:
        - Модель: \(deviceInfo.model)
        - Вольтаж батареи: \(String(format: "%.2f В", deviceInfo.batteryVoltage))
        
        Прошивка:
        - Версия прошивки: \(deviceInfo.firmwareVersion)
        - Версия загрузчика: \(deviceInfo.bootloaderVersion)
        
        Подключение:
        - Статус: \(usbManager.isConnected ? "Подключено" : "Не подключено")
        - Порт: \(usbManager.selectedPort?.displayName ?? "Не выбран")
        - Доступно портов: \(usbManager.availablePorts.count)
        
        Дата экспорта: \(formatter.string(from: Date()))
        """
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    InfoView(usbManager: USBCommunicationManager())
}