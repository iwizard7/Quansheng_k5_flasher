import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var usbManager = USBCommunicationManager()
    @State private var selectedTab = 0
    @State private var connectionStatus = "Не подключено"
    @State private var isConnected = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Уведомление"
    
    var body: some View {
        VStack {
            // Заголовок и статус подключения
            HStack {
                Text("Quansheng K5 Tool")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(connectionStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Выбор порта
            HStack {
                Text("Порт:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Выберите порт", selection: $usbManager.selectedPort) {
                    Text("Не выбран").tag(nil as SerialPort?)
                    ForEach(usbManager.availablePorts) { port in
                        Text(port.displayName).tag(port as SerialPort?)
                    }
                }
                .frame(minWidth: 200)
                
                Button("Обновить порты") {
                    refreshPorts()
                }
                .font(.caption)
            }
            .padding(.horizontal)
            
            // Кнопки подключения
            HStack {
                Button("Подключиться") {
                    connectToDevice()
                }
                .disabled(isConnected || usbManager.selectedPort == nil)
                
                Button("Отключиться") {
                    disconnectFromDevice()
                }
                .disabled(!isConnected)
                
                Spacer()
                
                Button("Обновить устройства") {
                    refreshDevices()
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Основной интерфейс с боковым меню
            HStack(spacing: 0) {
                // Боковое меню навигации
                NavigationSidebar(selectedTab: $selectedTab)
                    .frame(width: 250)
                    .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Основной контент
                Group {
                    switch selectedTab {
                    case 0:
                        BatteryCalibrationView(usbManager: usbManager)
                    case 1:
                        FirmwareView(usbManager: usbManager)
                    case 2:
                        SettingsView(usbManager: usbManager)
                    case 3:
                        ChannelsView(usbManager: usbManager)
                    case 4:
                        InfoView(usbManager: usbManager)
                    case 5:
                        Text("Лог будет добавлен позже")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    default:
                        BatteryCalibrationView(usbManager: usbManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 700, minHeight: 500)
        }
        .onAppear {
            setupUSBManager()
            startStatusTimer()
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func connectToDevice() {
        guard let selectedPort = usbManager.selectedPort else {
            showAlert(title: "Ошибка", message: "Выберите порт для подключения")
            return
        }
        
        Task {
            let success = await usbManager.connectToK5(port: selectedPort)
            await MainActor.run {
                isConnected = success
                connectionStatus = success ? "Подключено к K5 через \(selectedPort.name)" : "Ошибка подключения к \(selectedPort.name)"
            }
        }
    }
    
    private func disconnectFromDevice() {
        usbManager.disconnect()
        isConnected = false
        connectionStatus = "Отключено"
    }
    
    private func refreshDevices() {
        usbManager.refreshDevices()
        connectionStatus = usbManager.getConnectionStatus()
    }
    
    private func refreshPorts() {
        usbManager.refreshSerialPorts()
    }
    
    private func setupUSBManager() {
        usbManager.onConnectionStatusChanged = { connected in
            DispatchQueue.main.async {
                isConnected = connected
                connectionStatus = usbManager.getConnectionStatus()
            }
        }
    }
    
    private func startStatusTimer() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            if !isConnected {
                connectionStatus = usbManager.getConnectionStatus()
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Боковое меню навигации
struct NavigationSidebar: View {
    @Binding var selectedTab: Int
    
    private let menuItems = [
        MenuItem(id: 0, title: "Калибровка батареи", icon: "battery.100", description: "Чтение и запись калибровки"),
        MenuItem(id: 1, title: "Прошивка", icon: "cpu", description: "Обновление прошивки"),
        MenuItem(id: 2, title: "Настройки", icon: "gear", description: "Конфигурация устройства"),
        MenuItem(id: 3, title: "Каналы", icon: "radio", description: "Управление каналами"),
        MenuItem(id: 4, title: "Информация", icon: "info.circle", description: "Данные об устройстве"),
        MenuItem(id: 5, title: "Лог", icon: "doc.text", description: "Журнал работы")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Заголовок меню
            HStack {
                Text("Навигация")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
            
            Divider()
            
            // Список пунктов меню
            VStack(spacing: 2) {
                ForEach(menuItems, id: \.id) { item in
                    NavigationMenuItem(
                        item: item,
                        isSelected: selectedTab == item.id
                    ) {
                        selectedTab = item.id
                    }
                }
            }
            .padding(.vertical, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct NavigationMenuItem: View {
    let item: MenuItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(item.description)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 8)
    }
}

struct MenuItem {
    let id: Int
    let title: String
    let icon: String
    let description: String
}

// MARK: - Вкладка калибровки батареи
struct BatteryCalibrationView: View {
    @ObservedObject var usbManager: USBCommunicationManager
    @State private var batteryLevel: Double = 0.0
    @State private var calibrationData: String = ""
    @State private var fullCalibration: K5CalibrationData = K5CalibrationData()
    @State private var isCalibrating = false
    @State private var selectedCalibrationTab = 0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = "Ошибка"
    @State private var logManager = LogManager()
    @State private var calibrationManager: CalibrationManager?

    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Калибровка устройства")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Текущий уровень батареи: \(String(format: "%.1f", batteryLevel))%")
                
                ProgressView(value: batteryLevel / 100.0)
                    .progressViewStyle(LinearProgressViewStyle())
            }
            
            // Вкладки калибровки
            TabView(selection: $selectedCalibrationTab) {
                // Простая калибровка батареи
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Основные операции
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Button("Считать калибровку") {
                                    readBatteryCalibration()
                                }
                                .disabled(!usbManager.isConnected || isCalibrating)
                                
                                Button("Записать калибровку") {
                                    writeBatteryCalibration()
                                }
                                .disabled(!usbManager.isConnected || isCalibrating || calibrationData.isEmpty)
                            }
                            
                            HStack {
                                Button("Сохранить JSON") {
                                    saveBatteryCalibrationToFile()
                                }
                                .disabled(calibrationData.isEmpty)
                                
                                Button("Сохранить BIN") {
                                    saveBatteryCalibrationToBinFile()
                                }
                                .disabled(calibrationData.isEmpty)
                                
                                Button("Загрузить файл") {
                                    loadBatteryCalibrationFromFile()
                                }
                            }
                        }
                        

                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Данные калибровки батареи:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        TextEditor(text: $calibrationData)
                            .font(.system(.body, design: .monospaced))
                            .border(Color.gray, width: 1)
                            .frame(minHeight: 200)
                    }
                }
                .tabItem {
                    Text("Батарея")
                }
                .tag(0)
                
                // Полная калибровка
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button("Считать полную калибровку") {
                                readFullCalibration()
                            }
                            .disabled(!usbManager.isConnected || isCalibrating)
                            
                            Button("Записать полную калибровку") {
                                writeFullCalibration()
                            }
                            .disabled(!usbManager.isConnected || isCalibrating)
                        }
                        
                        HStack {
                            Button("Сохранить в файл") {
                                saveFullCalibrationToFile()
                            }
                            .disabled(fullCalibration.batteryCalibration.isEmpty)
                            
                            Button("Загрузить из файла") {
                                loadFullCalibrationFromFile()
                            }
                            
                            Spacer()
                            
                            Button("Экспорт (старый)") {
                                exportCalibration()
                            }
                            .disabled(fullCalibration.batteryCalibration.isEmpty)
                            
                            Button("Импорт (старый)") {
                                importCalibration()
                            }
                        }
                    }
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            CalibrationDataView(
                                title: "Калибровка батареи",
                                data: fullCalibration.batteryCalibration
                            )
                            
                            CalibrationDataView(
                                title: "Калибровка RSSI",
                                data: fullCalibration.rssiCalibration
                            )
                            
                            CalibrationDataView(
                                title: "Общая калибровка",
                                data: fullCalibration.generalCalibration
                            )
                        }
                    }
                }
                .tabItem {
                    Text("Полная")
                }
                .tag(1)
            }
            .frame(minHeight: 300)
            
            if isCalibrating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Выполняется операция...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .onAppear {
            if calibrationManager == nil {
                calibrationManager = CalibrationManager(logManager: logManager)
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func readBatteryCalibration() {
        isCalibrating = true
        Task {
            let data = await usbManager.readBatteryCalibration()
            await MainActor.run {
                calibrationData = data
                isCalibrating = false
            }
        }
    }
    
    private func writeBatteryCalibration() {
        isCalibrating = true
        Task {
            let success = await usbManager.writeBatteryCalibration(calibrationData)
            await MainActor.run {
                isCalibrating = false
                if !success {
                    showAlert(title: "Ошибка", message: "Не удалось записать калибровку батареи")
                }
            }
        }
    }
    
    private func readFullCalibration() {
        isCalibrating = true
        Task {
            let calibration = await usbManager.readFullCalibration()
            await MainActor.run {
                fullCalibration = calibration
                isCalibrating = false
            }
        }
    }
    
    private func writeFullCalibration() {
        isCalibrating = true
        Task {
            let success = await usbManager.writeFullCalibration(fullCalibration)
            await MainActor.run {
                isCalibrating = false
                if !success {
                    showAlert(title: "Ошибка", message: "Не удалось записать полную калибровку")
                }
            }
        }
    }
    
    private func saveBatteryCalibrationToFile() {
        guard let calibrationManager = calibrationManager else { return }
        
        // Получаем информацию об устройстве
        let deviceInfo = K5DeviceInfo(
            model: "Quansheng K5",
            serialNumber: usbManager.selectedPort?.name ?? "Unknown",
            firmwareVersion: "Unknown",
            bootloaderVersion: "Unknown",
            frequencyRange: "136-174 MHz",
            manufacturingDate: "Unknown"
        )
        
        let success = calibrationManager.saveCalibrationToFile(calibrationData, deviceInfo: deviceInfo)
        if success {
            showAlert(title: "Успех", message: "Калибровка батареи сохранена в файл")
        } else {
            showAlert(title: "Ошибка", message: "Не удалось сохранить калибровку в файл")
        }
    }
    
    private func loadBatteryCalibrationFromFile() {
        guard let calibrationManager = calibrationManager else { return }
        
        if let (loadedCalibration, deviceInfo) = calibrationManager.loadCalibrationFromFile() {
            calibrationData = loadedCalibration
            showAlert(title: "Успех", message: "Калибровка батареи загружена из файла\nУстройство: \(deviceInfo.model)\nS/N: \(deviceInfo.serialNumber)")
        }
    }
    
    private func saveFullCalibrationToFile() {
        guard let calibrationManager = calibrationManager else { return }
        
        // Получаем информацию об устройстве
        let deviceInfo = K5DeviceInfo(
            model: "Quansheng K5",
            serialNumber: usbManager.selectedPort?.name ?? "Unknown",
            firmwareVersion: "Unknown",
            bootloaderVersion: "Unknown",
            frequencyRange: "136-174 MHz",
            manufacturingDate: "Unknown"
        )
        
        let success = calibrationManager.saveFullCalibrationToFile(fullCalibration, deviceInfo: deviceInfo)
        if success {
            showAlert(title: "Успех", message: "Полная калибровка сохранена в файл")
        } else {
            showAlert(title: "Ошибка", message: "Не удалось сохранить полную калибровку в файл")
        }
    }
    
    private func loadFullCalibrationFromFile() {
        guard let calibrationManager = calibrationManager else { return }
        
        if let (loadedCalibration, deviceInfo) = calibrationManager.loadFullCalibrationFromFile() {
            fullCalibration = loadedCalibration
            showAlert(title: "Успех", message: "Полная калибровка загружена из файла\nУстройство: \(deviceInfo.model)\nS/N: \(deviceInfo.serialNumber)")
        }
    }
    
    private func saveBatteryCalibrationToBinFile() {
        guard let calibrationManager = calibrationManager else { return }
        
        // Получаем информацию об устройстве
        let deviceInfo = K5DeviceInfo(
            model: "Quansheng K5",
            serialNumber: usbManager.selectedPort?.name ?? "Unknown",
            firmwareVersion: "Unknown",
            bootloaderVersion: "Unknown",
            frequencyRange: "136-174 MHz",
            manufacturingDate: "Unknown"
        )
        
        let success = calibrationManager.saveBatteryCalibrationToBinFile(calibrationData, deviceInfo: deviceInfo)
        if success {
            showAlert(title: "Успех", message: "Калибровка батареи сохранена в BIN файл")
        } else {
            showAlert(title: "Ошибка", message: "Не удалось сохранить калибровку в BIN файл")
        }
    }
    

    
    private func exportCalibration() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "k5_calibration.json"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                
                let calibrationDict: [String: String] = [
                    "batteryCalibration": fullCalibration.batteryCalibration.base64EncodedString(),
                    "rssiCalibration": fullCalibration.rssiCalibration.base64EncodedString(),
                    "generalCalibration": fullCalibration.generalCalibration.base64EncodedString()
                ]
                
                let jsonData = try encoder.encode(calibrationDict)
                try jsonData.write(to: url)
            } catch {
                print("Ошибка экспорта: \(error)")
            }
        }
    }
    
    private func importCalibration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let jsonData = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let calibrationDict = try decoder.decode([String: String].self, from: jsonData)
                
                if let batteryData = calibrationDict["batteryCalibration"],
                   let battery = Data(base64Encoded: batteryData) {
                    fullCalibration.batteryCalibration = battery
                }
                
                if let rssiData = calibrationDict["rssiCalibration"],
                   let rssi = Data(base64Encoded: rssiData) {
                    fullCalibration.rssiCalibration = rssi
                }
                
                if let generalData = calibrationDict["generalCalibration"],
                   let general = Data(base64Encoded: generalData) {
                    fullCalibration.generalCalibration = general
                }
            } catch {
                print("Ошибка импорта: \(error)")
            }
        }
    }
    

    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct CalibrationDataView: View {
    let title: String
    let data: Data
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if data.isEmpty {
                Text("Нет данных")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            } else {
                Text(formatHexData(data))
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func formatHexData(_ data: Data) -> String {
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        
        // Разбиваем на строки по 16 байт
        let chunks = hexString.components(separatedBy: " ").chunked(into: 16)
        return chunks.map { $0.joined(separator: " ") }.joined(separator: "\n")
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Вкладка прошивки
struct FirmwareView: View {
    @ObservedObject var usbManager: USBCommunicationManager
    @State private var firmwareFilePath: String = ""
    @State private var isFlashing = false
    @State private var flashProgress: Double = 0.0
    @State private var currentFirmwareVersion = "Неизвестно"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Управление прошивкой")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Текущая версия прошивки: \(currentFirmwareVersion)")
                
                Button("Считать информацию о прошивке") {
                    readFirmwareInfo()
                }
                .disabled(!usbManager.isConnected)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Обновление прошивки")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    TextField("Путь к файлу прошивки", text: $firmwareFilePath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Выбрать файл") {
                        selectFirmwareFile()
                    }
                }
                
                if isFlashing {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Прошивка устройства... \(String(format: "%.0f", flashProgress))%")
                            .font(.caption)
                        
                        ProgressView(value: flashProgress / 100.0)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                } else {
                    Button("Прошить устройство") {
                        flashFirmware()
                    }
                    .disabled(!usbManager.isConnected || firmwareFilePath.isEmpty)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            if usbManager.isConnected {
                readFirmwareInfo()
            }
        }
    }
    
    private func readFirmwareInfo() {
        Task {
            let version = await usbManager.readFirmwareVersion()
            await MainActor.run {
                currentFirmwareVersion = version
            }
        }
    }
    
    private func selectFirmwareFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            firmwareFilePath = panel.url?.path ?? ""
        }
    }
    
    private func flashFirmware() {
        isFlashing = true
        flashProgress = 0.0
        
        Task {
            let success = await usbManager.flashFirmware(filePath: firmwareFilePath) { progress in
                DispatchQueue.main.async {
                    flashProgress = progress * 100
                }
            }
            
            await MainActor.run {
                isFlashing = false
                if success {
                    readFirmwareInfo()
                }
            }
        }
    }
}

// MARK: - Вкладка настроек
struct SettingsView: View {
    @ObservedObject var usbManager: USBCommunicationManager
    @State private var settings: K5Settings = K5Settings()
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Настройки устройства")
                .font(.headline)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Загрузка настроек...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        // Основные настройки
                        GroupBox("Основные настройки") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Частота по умолчанию:")
                                    Spacer()
                                    TextField("MHz", value: $settings.defaultFrequency, format: .number)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 100)
                                }
                                
                                HStack {
                                    Text("Мощность передачи:")
                                    Spacer()
                                    Picker("", selection: $settings.txPower) {
                                        Text("Низкая").tag(0)
                                        Text("Средняя").tag(1)
                                        Text("Высокая").tag(2)
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                    .frame(width: 200)
                                }
                                
                                Toggle("Автоматическое сканирование", isOn: $settings.autoScan)
                            }
                            .padding()
                        }
                        
                        // Настройки дисплея
                        GroupBox("Дисплей") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Яркость подсветки:")
                                    Spacer()
                                    Slider(value: $settings.backlightBrightness, in: 0...100, step: 1)
                                        .frame(width: 150)
                                    Text("\(Int(settings.backlightBrightness))%")
                                        .frame(width: 40)
                                }
                                
                                Toggle("Автоотключение подсветки", isOn: $settings.autoBacklightOff)
                            }
                            .padding()
                        }
                    }
                }
            }
            
            HStack {
                Button("Считать настройки") {
                    readSettings()
                }
                .disabled(!usbManager.isConnected || isLoading)
                
                Button("Записать настройки") {
                    writeSettings()
                }
                .disabled(!usbManager.isConnected || isLoading)
                
                Spacer()
            }
        }
        .padding()
        .onAppear {
            if usbManager.isConnected {
                readSettings()
            }
        }
    }
    
    private func readSettings() {
        isLoading = true
        Task {
            let deviceSettings = await usbManager.readSettings()
            await MainActor.run {
                settings = deviceSettings
                isLoading = false
            }
        }
    }
    
    private func writeSettings() {
        isLoading = true
        Task {
            let success = await usbManager.writeSettings(settings)
            await MainActor.run {
                isLoading = false
                if !success {
                    print("Ошибка записи настроек")
                }
            }
        }
    }
}

// MARK: - Вкладка информации
struct InfoView: View {
    @ObservedObject var usbManager: USBCommunicationManager
    @State private var deviceInfo: K5DeviceInfo = K5DeviceInfo()
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Информация об устройстве")
                .font(.headline)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Получение информации...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    // Основная информация
                    GroupBox("Основная информация") {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(title: "Модель", value: deviceInfo.model)
                            InfoRow(title: "Серийный номер", value: deviceInfo.serialNumber)
                            InfoRow(title: "Дата производства", value: deviceInfo.manufacturingDate)
                        }
                        .padding()
                    }
                    
                    // Информация о прошивке
                    GroupBox("Прошивка") {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(title: "Версия прошивки", value: deviceInfo.firmwareVersion)
                            InfoRow(title: "Версия загрузчика", value: deviceInfo.bootloaderVersion)
                        }
                        .padding()
                    }
                    
                    // Технические характеристики
                    GroupBox("Технические характеристики") {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(title: "Частотный диапазон", value: deviceInfo.frequencyRange)
                            InfoRow(title: "Тип модуляции", value: "FM")
                            InfoRow(title: "Количество каналов", value: "200")
                            InfoRow(title: "Мощность передачи", value: "1-5 Вт")
                        }
                        .padding()
                    }
                    
                    // Статус подключения
                    GroupBox("Статус подключения") {
                        VStack(alignment: .leading, spacing: 12) {
                            InfoRow(title: "Порт", value: usbManager.selectedPort?.displayName ?? "Не выбран")
                            InfoRow(title: "Состояние", value: usbManager.isConnected ? "Подключено" : "Отключено")
                            if let port = usbManager.selectedPort {
                                InfoRow(title: "Путь к порту", value: port.path)
                            }
                        }
                        .padding()
                    }
                }
            }
            
            Button("Обновить информацию") {
                loadDeviceInfo()
            }
            .disabled(!usbManager.isConnected || isLoading)
            
            Spacer()
        }
        .padding()
        .onAppear {
            if usbManager.isConnected {
                loadDeviceInfo()
            }
        }
    }
    
    private func loadDeviceInfo() {
        isLoading = true
        Task {
            do {
                let info = await usbManager.readDeviceInfo()
                await MainActor.run {
                    deviceInfo = info
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Ошибка загрузки информации об устройстве: \(error)")
                    isLoading = false
                }
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title + ":")
                .fontWeight(.medium)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Вкладка каналов
struct ChannelsView: View {
    @ObservedObject var usbManager: USBCommunicationManager
    @State private var channels: [K5Channel] = []
    @State private var selectedChannel: K5Channel?
    @State private var isLoading = false
    @State private var showingChannelEditor = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Управление каналами")
                    .font(.headline)
                
                Spacer()
                
                HStack {
                    Button("Считать каналы") {
                        loadChannels()
                    }
                    .disabled(!usbManager.isConnected || isLoading)
                    
                    Button("Записать каналы") {
                        saveChannels()
                    }
                    .disabled(!usbManager.isConnected || isLoading || channels.isEmpty)
                    
                    Button("Добавить канал") {
                        addNewChannel()
                    }
                    .disabled(isLoading)
                    
                    Menu("Импорт/Экспорт") {
                        Button("Экспорт в JSON") {
                            exportChannelsJSON()
                        }
                        .disabled(channels.isEmpty)
                        
                        Button("Импорт из JSON") {
                            importChannelsJSON()
                        }
                        
                        Button("Экспорт в CSV") {
                            exportChannelsCSV()
                        }
                        .disabled(channels.isEmpty)
                        
                        Button("Импорт из CSV") {
                            importChannelsCSV()
                        }
                        
                        Button("Экспорт в CHIRP") {
                            exportChannelsCHIRP()
                        }
                        .disabled(channels.isEmpty)
                    }
                    .disabled(isLoading)
                }
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Загрузка каналов...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                List {
                    ForEach(channels, id: \.index) { channel in
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
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingChannelEditor) {
            if let channel = selectedChannel {
                ChannelEditorView(channel: channel) { editedChannel in
                    updateChannel(editedChannel)
                }
            }
        }
        .onAppear {
            if usbManager.isConnected && channels.isEmpty {
                loadChannels()
            }
        }
    }
    
    private func loadChannels() {
        isLoading = true
        Task {
            let loadedChannels = await usbManager.readChannels()
            await MainActor.run {
                channels = loadedChannels
                isLoading = false
            }
        }
    }
    
    private func saveChannels() {
        isLoading = true
        Task {
            let success = await usbManager.writeChannels(channels)
            await MainActor.run {
                isLoading = false
                if !success {
                    print("Ошибка записи каналов")
                }
            }
        }
    }
    
    private func addNewChannel() {
        var newChannel = K5Channel()
        newChannel.index = channels.count
        selectedChannel = newChannel
        showingChannelEditor = true
    }
    
    private func updateChannel(_ channel: K5Channel) {
        if let index = channels.firstIndex(where: { $0.index == channel.index }) {
            channels[index] = channel
        } else {
            channels.append(channel)
        }
    }
    
    private func deleteChannel(_ channel: K5Channel) {
        channels.removeAll { $0.index == channel.index }
    }
    
    // MARK: - Методы импорта/экспорта каналов
    
    private func exportChannelsJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "k5_channels.json"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try K5Utilities.exportChannels(channels, to: url)
            } catch {
                print("Ошибка экспорта JSON: \(error)")
            }
        }
    }
    
    private func importChannelsJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                channels = try K5Utilities.importChannels(from: url)
            } catch {
                print("Ошибка импорта JSON: \(error)")
            }
        }
    }
    
    private func exportChannelsCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "k5_channels.csv"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try K5Utilities.exportChannelsToCSV(channels, to: url)
            } catch {
                print("Ошибка экспорта CSV: \(error)")
            }
        }
    }
    
    private func importChannelsCSV() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                channels = try K5Utilities.importChannelsFromCSV(from: url)
            } catch {
                print("Ошибка импорта CSV: \(error)")
            }
        }
    }
    
    private func exportChannelsCHIRP() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "k5_channels_chirp.csv"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try K5Utilities.exportToCHIRP(channels, to: url)
            } catch {
                print("Ошибка экспорта CHIRP: \(error)")
            }
        }
    }
}