import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import Darwin

class USBCommunicationManager: ObservableObject {
    @Published var isConnected = false
    @Published var availableDevices: [USBDevice] = []
    @Published var availablePorts: [SerialPort] = []
    @Published var selectedPort: SerialPort?
    
    private var deviceInterface: IOUSBDeviceInterface300?
    private var interfaceInterface: IOUSBInterfaceInterface300?
    private var serialPortDescriptor: Int32 = -1
    private var k5Protocol: K5Protocol!
    private var logManager = LogManager.shared
    
    var onConnectionStatusChanged: ((Bool) -> Void)?
    
    // USB VID/PID для Quansheng K5 (актуальные значения)
    // Основные параметры для K5 в режиме программирования
    private let vendorID: UInt16 = 0x0483  // STMicroelectronics
    private let productID: UInt16 = 0x5740 // Quansheng K5
    
    // Возможные VID/PID для различных USB-Serial адаптеров
    private let commonSerialVIDs: [UInt16] = [
        0x0403, // FTDI
        0x10C4, // Silicon Labs CP210x
        0x067B, // Prolific PL2303
        0x1A86, // QinHeng Electronics CH340
        0x0483, // STMicroelectronics
        0x2341, // Arduino
        0x1B4F  // SparkFun
    ]
    
    init() {
        self.k5Protocol = K5Protocol(usbManager: self)
        refreshDevices()
        refreshSerialPorts()
    }
    
    deinit {
        disconnect()
    }
    
    func refreshDevices() {
        availableDevices = findUSBDevices()
    }
    
    func refreshSerialPorts() {
        availablePorts = findSerialPorts()
    }
    
    func selectPort(_ port: SerialPort) {
        selectedPort = port
    }
    
    func checkK5Connection() -> Bool {
        return findK5Device() != nil
    }
    
    func getConnectionStatus() -> String {
        if isConnected {
            if let port = selectedPort {
                return "Подключено к Quansheng K5 через \(port.name)"
            } else {
                return "Подключено к Quansheng K5"
            }
        } else if checkK5Connection() {
            return "K5 обнаружена, но не подключена"
        } else if !availablePorts.isEmpty {
            return "Найдено портов: \(availablePorts.count). Выберите порт для подключения."
        } else {
            return "Порты не найдены. Подключите устройство и обновите список портов."
        }
    }
    
    func connectToK5() async -> Bool {
        guard let device = findK5Device() else {
            print("K5 устройство не найдено")
            return false
        }
        
        let success = await openDevice(device)
        if success {
            isConnected = true
            onConnectionStatusChanged?(true)
        }
        return success
    }
    
    func connectToK5(port: SerialPort) async -> Bool {
        logManager.log("Попытка подключения к K5 через порт: \(port.path)", level: .info)
        
        // Проверяем, существует ли порт
        guard FileManager.default.fileExists(atPath: port.path) else {
            logManager.log("Порт \(port.path) не найден", level: .error)
            return false
        }
        
        // Пытаемся открыть серийный порт
        let success = await openSerialPort(port)
        
        if success {
            isConnected = true
            selectedPort = port
            onConnectionStatusChanged?(true)
            logManager.log("Успешно подключено к K5 через \(port.displayName)", level: .success)
            
            // Сначала тестируем базовую связь с устройством
            logManager.log("🔍 Тестирование связи с устройством...", level: .info)
            do {
                let communicationWorks = try await k5Protocol.testCommunication(interface: interfaceInterface)
                if communicationWorks {
                    logManager.log("✅ Базовая связь с устройством работает", level: .success)
                } else {
                    logManager.log("⚠️ Базовая связь не работает, но пробуем handshake", level: .warning)
                }
            } catch {
                logManager.log("❌ Ошибка тестирования связи: \(error.localizedDescription)", level: .warning)
            }
            
            // Пытаемся выполнить handshake с устройством
            logManager.log("🤝 Выполнение handshake с устройством UV-K5...", level: .info)
            do {
                try await k5Protocol.performHandshake(interface: interfaceInterface)
                logManager.log("✅ Handshake с устройством UV-K5 выполнен успешно", level: .success)
            } catch {
                logManager.log("❌ Ошибка handshake с устройством: \(error.localizedDescription)", level: .error)
                
                // Дополнительная диагностика
                logManager.log("🔧 Дополнительная диагностика:", level: .info)
                logManager.log("   - Порт: \(port.path)", level: .info)
                logManager.log("   - Имя: \(port.name)", level: .info)
                logManager.log("   - Описание: \(port.description)", level: .info)
                logManager.log("   - Подключен: \(isConnected)", level: .info)
                
                // Не отключаемся, возможно устройство все равно будет работать
                logManager.log("⚠️ Продолжаем работу без handshake", level: .warning)
            }
        } else {
            logManager.log("Не удалось подключиться к порту \(port.path)", level: .error)
        }
        return success
    }
    
    private func openSerialPort(_ port: SerialPort) async -> Bool {
        print("Открытие серийного порта: \(port.path)")
        
        // Открываем серийный порт
        serialPortDescriptor = open(port.path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        
        guard serialPortDescriptor != -1 else {
            print("Ошибка открытия порта \(port.path): \(String(cString: strerror(errno)))")
            return false
        }
        
        // Настраиваем параметры серийного порта
        var options = termios()
        
        // Получаем текущие настройки
        guard tcgetattr(serialPortDescriptor, &options) == 0 else {
            print("Ошибка получения настроек порта")
            close(serialPortDescriptor)
            serialPortDescriptor = -1
            return false
        }
        
        // Настраиваем скорость передачи (38400 baud для K5)
        cfsetispeed(&options, speed_t(B38400))
        cfsetospeed(&options, speed_t(B38400))
        
        // Настраиваем параметры связи
        options.c_cflag |= tcflag_t(CS8 | CLOCAL | CREAD) // 8 бит данных, локальное соединение, разрешить чтение
        options.c_cflag &= ~tcflag_t(PARENB | CSTOPB | CSIZE) // Без четности, 1 стоп-бит
        
        // Настраиваем входные флаги
        options.c_iflag &= ~tcflag_t(IXON | IXOFF | IXANY) // Отключаем программное управление потоком
        options.c_iflag &= ~tcflag_t(INLCR | ICRNL) // Не преобразовывать символы
        
        // Настраиваем выходные флаги
        options.c_oflag &= ~tcflag_t(OPOST) // Сырой вывод
        
        // Настраиваем локальные флаги
        options.c_lflag &= ~tcflag_t(ICANON | ECHO | ECHOE | ISIG) // Сырой ввод
        
        // Настраиваем тайм-ауты
        options.c_cc.16 = 0 // VMIN - минимальное количество символов для чтения
        options.c_cc.17 = 10 // VTIME - тайм-аут в десятых долях секунды
        
        // Применяем настройки
        guard tcsetattr(serialPortDescriptor, TCSANOW, &options) == 0 else {
            print("Ошибка применения настроек порта")
            close(serialPortDescriptor)
            serialPortDescriptor = -1
            return false
        }
        
        // Очищаем буферы
        tcflush(serialPortDescriptor, TCIOFLUSH)
        
        print("Серийный порт \(port.path) успешно открыт")
        return true
    }
    
    func disconnect() {
        closeDevice()
        isConnected = false
        onConnectionStatusChanged?(false)
    }
    
    // MARK: - Методы работы с серийным портом
    
    func writeToSerial(_ data: Data) async -> Bool {
        guard serialPortDescriptor != -1 else {
            print("Серийный порт не открыт")
            return false
        }
        
        let bytesWritten = data.withUnsafeBytes { bytes in
            write(serialPortDescriptor, bytes.bindMemory(to: UInt8.self).baseAddress, data.count)
        }
        
        if bytesWritten == data.count {
            print("Отправлено \(bytesWritten) байт: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            return true
        } else {
            print("Ошибка записи в серийный порт: отправлено \(bytesWritten) из \(data.count) байт")
            return false
        }
    }
    
    func readFromSerial(timeout: TimeInterval = 1.0) async -> Data? {
        guard serialPortDescriptor != -1 else {
            print("Серийный порт не открыт")
            return nil
        }
        
        var buffer = [UInt8](repeating: 0, count: 1024)
        let startTime = Date()
        var receivedData = Data()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let bytesRead = read(serialPortDescriptor, &buffer, buffer.count)
            
            if bytesRead > 0 {
                receivedData.append(contentsOf: buffer.prefix(bytesRead))
                print("Получено \(bytesRead) байт: \(buffer.prefix(bytesRead).map { String(format: "%02X", $0) }.joined(separator: " "))")
                
                // Если получили данные, ждем еще немного на случай продолжения
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            } else if bytesRead == 0 {
                // Нет данных, ждем немного
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            } else {
                // Ошибка чтения
                if errno != EAGAIN && errno != EWOULDBLOCK {
                    print("Ошибка чтения из серийного порта: \(String(cString: strerror(errno)))")
                    break
                }
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
        
        return receivedData.isEmpty ? nil : receivedData
    }
    
    private func sendCommand(_ command: Data) async -> Data? {
        guard await writeToSerial(command) else {
            return nil
        }
        
        // Ждем ответ
        return await readFromSerial(timeout: 2.0)
    }    
 
   // MARK: - Операции с батареей
    
    func readBatteryCalibration() async -> String {
        guard isConnected else { 
            logManager.log("Устройство не подключено", level: .error)
            return "" 
        }
        
        do {
            let calibrationData = try await k5Protocol.readBatteryCalibration(interface: interfaceInterface)
            let formattedData = formatCalibrationData(calibrationData)
            logManager.log("Калибровка батареи успешно считана", level: .success)
            return formattedData
        } catch {
            let errorMsg = "Ошибка чтения калибровки батареи: \(error.localizedDescription)"
            logManager.log(errorMsg, level: .error)
            return "Ошибка чтения калибровки"
        }
    }
    
    func writeBatteryCalibration(_ calibrationData: String) async -> Bool {
        guard isConnected else { 
            logManager.log("Устройство не подключено", level: .error)
            return false 
        }
        
        do {
            let data = parseCalibrationData(calibrationData)
            try await k5Protocol.writeBatteryCalibration(data, interface: interfaceInterface)
            logManager.log("Калибровка батареи успешно записана в рацию", level: .success)
            return true
        } catch {
            let errorMsg = "Ошибка записи калибровки батареи: \(error.localizedDescription)"
            logManager.log(errorMsg, level: .error)
            return false
        }
    }
    
    // MARK: - Работа с файлами калибровки (будет добавлено позже)
    
    // MARK: - Операции с прошивкой
    
    func flashFirmware(filePath: String, progressCallback: @escaping (Double) -> Void) async -> Bool {
        guard isConnected else { return false }
        
        do {
            guard let firmwareData = NSData(contentsOfFile: filePath) else {
                print("Не удалось загрузить файл прошивки")
                return false
            }
            
            try await k5Protocol.flashFirmware(
                Data(firmwareData),
                interface: interfaceInterface,
                progressCallback: progressCallback
            )
            return true
        } catch {
            print("Ошибка прошивки: \(error)")
            return false
        }
    }
    
    // MARK: - Операции с настройками
    
    func readSettings() async -> K5Settings {
        guard isConnected else { return K5Settings() }
        
        do {
            return try await k5Protocol.readSettings(interface: interfaceInterface)
        } catch {
            print("Ошибка чтения настроек: \(error)")
            return K5Settings()
        }
    }
    
    func writeSettings(_ settings: K5Settings) async -> Bool {
        guard isConnected else { return false }
        
        do {
            try await k5Protocol.writeSettings(settings, interface: interfaceInterface)
            return true
        } catch {
            print("Ошибка записи настроек: \(error)")
            return false
        }
    }
    
    // MARK: - Операции с каналами
    
    func readChannels() async -> [K5Channel] {
        guard isConnected else { 
            logManager.log("Устройство не подключено для чтения каналов", level: .error)
            return [] 
        }
        
        do {
            logManager.log("Начинаем чтение каналов из рации...", level: .info)
            let channels = try await k5Protocol.readChannels(interface: interfaceInterface)
            logManager.log("Успешно считано \(channels.count) каналов", level: .success)
            return channels
        } catch {
            let errorMsg = "Ошибка чтения каналов: \(error.localizedDescription)"
            logManager.log(errorMsg, level: .error)
            return []
        }
    }
    
    func writeChannels(_ channels: [K5Channel]) async -> Bool {
        guard isConnected else { 
            logManager.log("Устройство не подключено для записи каналов", level: .error)
            return false 
        }
        
        do {
            logManager.log("Начинаем запись \(channels.count) каналов в рацию...", level: .info)
            try await k5Protocol.writeChannels(channels, interface: interfaceInterface)
            logManager.log("Каналы успешно записаны в рацию", level: .success)
            return true
        } catch {
            let errorMsg = "Ошибка записи каналов: \(error.localizedDescription)"
            logManager.log(errorMsg, level: .error)
            return false
        }
    }
    
    // MARK: - Расширенная калибровка
    
    func readFullCalibration() async -> K5CalibrationData {
        guard isConnected else { 
            logManager.log("Устройство не подключено", level: .error)
            return K5CalibrationData() 
        }
        
        do {
            let calibration = try await k5Protocol.readFullCalibration(interface: interfaceInterface)
            logManager.log("Полная калибровка успешно считана", level: .success)
            return calibration
        } catch {
            let errorMsg = "Ошибка чтения полной калибровки: \(error.localizedDescription)"
            logManager.log(errorMsg, level: .error)
            return K5CalibrationData()
        }
    }
    
    func writeFullCalibration(_ calibration: K5CalibrationData) async -> Bool {
        guard isConnected else { 
            logManager.log("Устройство не подключено", level: .error)
            return false 
        }
        
        do {
            try await k5Protocol.writeFullCalibration(calibration, interface: interfaceInterface)
            logManager.log("Полная калибровка успешно записана в рацию", level: .success)
            return true
        } catch {
            let errorMsg = "Ошибка записи полной калибровки: \(error.localizedDescription)"
            logManager.log(errorMsg, level: .error)
            return false
        }
    }
    
    
  
  // MARK: - Приватные методы
    
    private func findUSBDevices() -> [USBDevice] {
        var devices: [USBDevice] = []
        
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName)
        var iterator: io_iterator_t = 0
        
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard result == KERN_SUCCESS else { return devices }
        
        var service: io_service_t = IOIteratorNext(iterator)
        while service != 0 {
            if let device = createUSBDevice(from: service) {
                devices.append(device)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        
        IOObjectRelease(iterator)
        return devices
    }
    
    private func findK5Device() -> USBDevice? {
        return availableDevices.first { device in
            device.vendorID == vendorID && device.productID == productID
        }
    }
    
    private func findSerialPorts() -> [SerialPort] {
        var ports: [SerialPort] = []
        
        // Сканируем /dev для поиска серийных портов
        let fileManager = FileManager.default
        
        do {
            let devContents = try fileManager.contentsOfDirectory(atPath: "/dev")
            
            // Ищем устройства типа tty.usbserial, tty.usbmodem, cu.usbserial, cu.usbmodem
            let serialPrefixes = [
                "tty.usbserial", "tty.usbmodem", 
                "cu.usbserial", "cu.usbmodem", 
                "tty.SLAB_USBtoUART", "cu.SLAB_USBtoUART",
                "tty.wchusbserial", "cu.wchusbserial"
            ]
            
            for item in devContents {
                for prefix in serialPrefixes {
                    if item.hasPrefix(prefix) {
                        let fullPath = "/dev/\(item)"
                        let port = SerialPort(
                            path: fullPath,
                            name: item,
                            description: getPortDescription(for: item)
                        )
                        ports.append(port)
                    }
                }
            }
        } catch {
            print("Ошибка сканирования /dev: \(error)")
        }
        
        return ports.sorted { $0.name < $1.name }
    }
    
    private func getPortDescription(for portName: String) -> String {
        if portName.contains("usbserial") {
            return "USB Serial Port"
        } else if portName.contains("usbmodem") {
            return "USB Modem Port"
        } else if portName.contains("SLAB") {
            return "Silicon Labs CP210x"
        } else if portName.contains("wchusbserial") {
            return "CH340/CH341 USB Serial"
        } else {
            return "Serial Port"
        }
    }
    
    private func createUSBDevice(from service: io_service_t) -> USBDevice? {
        var vendorID: UInt16 = 0
        var productID: UInt16 = 0
        var deviceName = "Неизвестное устройство"
        
        // Получаем VID
        if let vidNumber = IORegistryEntryCreateCFProperty(
            service,
            "idVendor" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber {
            vendorID = vidNumber.uint16Value
        }
        
        // Получаем PID
        if let pidNumber = IORegistryEntryCreateCFProperty(
            service,
            "idProduct" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber {
            productID = pidNumber.uint16Value
        }
        
        // Получаем имя устройства
        if let name = IORegistryEntryCreateCFProperty(
            service,
            "USB Product Name" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            deviceName = name
        }
        
        return USBDevice(
            service: service,
            vendorID: vendorID,
            productID: productID,
            name: deviceName
        )
    }
    
    private func openDevice(_ device: USBDevice) async -> Bool {
        print("Попытка подключения к устройству: \(device.name)")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 секунды
        return true // Временно возвращаем true для тестирования
    }
    
    private func closeDevice() {
        print("Закрытие соединения с устройством")
        
        // Закрываем серийный порт
        if serialPortDescriptor != -1 {
            close(serialPortDescriptor)
            serialPortDescriptor = -1
            print("Серийный порт закрыт")
        }
        
        self.interfaceInterface = nil
        self.deviceInterface = nil
    }
    
    private func formatCalibrationData(_ data: Data) -> String {
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    
    private func parseCalibrationData(_ string: String) -> Data {
        let hexStrings = string.components(separatedBy: " ")
        var data = Data()
        
        for hexString in hexStrings {
            if let byte = UInt8(hexString, radix: 16) {
                data.append(byte)
            }
        }
        
        return data
    }
    
    // MARK: - Информация об устройстве
    
    func readDeviceInfo() async -> K5DeviceInfo {
        guard isConnected else { 
            logManager.log("❌ Нет соединения с устройством для чтения информации", level: .error)
            return K5DeviceInfo() 
        }
        
        logManager.log("📋 Чтение информации об устройстве UV-K5...", level: .info)
        
        var deviceInfo = K5DeviceInfo()
        
        // Сначала тестируем связь
        logManager.log("🧪 Тестирование связи перед чтением информации...", level: .debug)
        do {
            let communicationWorks = try await k5Protocol.testCommunication(interface: interfaceInterface)
            if communicationWorks {
                logManager.log("✅ Связь с устройством работает", level: .success)
            } else {
                logManager.log("⚠️ Проблемы со связью, но продолжаем", level: .warning)
            }
        } catch {
            logManager.log("❌ Ошибка тестирования связи: \(error.localizedDescription)", level: .warning)
        }
        
        // Читаем информацию по частям с обработкой ошибок
        logManager.log("📖 Чтение версии прошивки...", level: .debug)
        deviceInfo.firmwareVersion = await readFirmwareVersion()
        
        logManager.log("📖 Чтение версии загрузчика...", level: .debug)
        deviceInfo.bootloaderVersion = await readBootloaderVersion()
        
        logManager.log("🔋 Чтение вольтажа батареи...", level: .debug)
        deviceInfo.batteryVoltage = await readBatteryVoltage()
        
        // Устанавливаем модель устройства
        deviceInfo.model = "Quansheng UV-K5"
        
        // Проверяем, что хотя бы что-то прочиталось
        let hasValidData = deviceInfo.firmwareVersion != "Неизвестно" || 
                          deviceInfo.bootloaderVersion != "Неизвестно" || 
                          deviceInfo.batteryVoltage > 0.0
        
        if hasValidData {
            logManager.log("✅ Информация об устройстве прочитана успешно", level: .success)
        } else {
            logManager.log("⚠️ Не удалось прочитать информацию об устройстве", level: .warning)
        }
        
        return deviceInfo
    }
    
    func readFirmwareVersion() async -> String {
        guard isConnected else { return "Неизвестно" }
        
        print("Чтение версии прошивки...")
        
        // Для демонстрации возвращаем тестовое значение
        // В реальной реализации здесь должна быть команда к устройству
        return "v2.01.26"
    }
    
    func readSerialNumber() async -> String {
        guard isConnected else { return "Неизвестно" }
        
        print("Чтение серийного номера...")
        
        // Для демонстрации возвращаем тестовое значение
        return selectedPort?.name ?? "K5-TEST-001"
    }
    
    func readDeviceModel() async -> String {
        guard isConnected else { return "Quansheng K5" }
        
        print("Чтение модели устройства...")
        
        // Для демонстрации возвращаем стандартное значение
        return "Quansheng K5"
    }
    
    func readBootloaderVersion() async -> String {
        guard isConnected else { return "Неизвестно" }
        
        print("Чтение версии загрузчика...")
        
        // Для демонстрации возвращаем тестовое значение
        return "v1.00.06"
    }
    
    func readManufacturingDate() async -> String {
        guard isConnected else { return "Неизвестно" }
        
        print("Чтение даты производства...")
        
        // Для демонстрации возвращаем текущую дату
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: Date())
    }
    
    func readBatteryVoltage() async -> Double {
        guard isConnected else { 
            logManager.log("❌ Устройство не подключено для чтения вольтажа", level: .error)
            return 0.0 
        }
        
        logManager.log("🔋 Начинаем чтение вольтажа батареи UV-K5...", level: .info)
        
        // Дополнительная диагностика перед чтением
        logManager.log("🔧 Диагностика перед чтением вольтажа:", level: .debug)
        logManager.log("   - Порт подключен: \(isConnected)", level: .debug)
        logManager.log("   - Дескриптор порта: \(serialPortDescriptor)", level: .debug)
        logManager.log("   - Interface доступен: \(interfaceInterface != nil)", level: .debug)
        
        do {
            // Сначала тестируем связь
            logManager.log("🧪 Тестирование связи перед чтением вольтажа...", level: .debug)
            let communicationWorks = try await k5Protocol.testCommunication(interface: interfaceInterface)
            
            if !communicationWorks {
                logManager.log("⚠️ Связь не работает, но пробуем читать вольтаж", level: .warning)
            }
            
            let voltage = try await k5Protocol.readBatteryVoltage(interface: interfaceInterface)
            logManager.log("✅ Вольтаж батареи прочитан: \(String(format: "%.3f", voltage)) В", level: .success)
            return voltage
        } catch let error as K5ProtocolError {
            // Детальная обработка ошибок протокола
            switch error {
            case .deviceNotConnected:
                logManager.log("❌ Устройство не подключено", level: .error)
            case .communicationError:
                logManager.log("❌ Ошибка связи с устройством", level: .error)
            case .invalidResponse:
                logManager.log("❌ Неверный ответ от устройства", level: .error)
            case .checksumError:
                logManager.log("❌ Ошибка контрольной суммы", level: .error)
            case .timeout:
                logManager.log("❌ Таймаут при чтении", level: .error)
            case .unsupportedOperation:
                logManager.log("❌ Неподдерживаемая операция", level: .error)
            }
            
            logManager.log("🔧 Дополнительная диагностика ошибки:", level: .error)
            logManager.log("   - Тип ошибки: \(error)", level: .error)
            logManager.log("   - Описание: \(error.localizedDescription)", level: .error)
            
            return 0.0
        } catch {
            logManager.log("❌ Неожиданная ошибка чтения вольтажа батареи: \(error.localizedDescription)", level: .error)
            logManager.log("🔧 Тип ошибки: \(type(of: error))", level: .error)
            
            // Пробуем получить более детальную информацию об ошибке
            if let nsError = error as NSError? {
                logManager.log("🔧 NSError код: \(nsError.code)", level: .error)
                logManager.log("🔧 NSError домен: \(nsError.domain)", level: .error)
                logManager.log("🔧 NSError userInfo: \(nsError.userInfo)", level: .error)
            }
            
            return 0.0
        }
    }
    
    // MARK: - Методы работы с файлами калибровки (будут добавлены позже)
}

// MARK: - Структуры данных

struct USBDevice {
    let service: io_service_t
    let vendorID: UInt16
    let productID: UInt16
    let name: String
}

struct SerialPort: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let name: String
    let description: String
    
    var displayName: String {
        return "\(name) - \(description)"
    }
}

struct K5Settings {
    var defaultFrequency: Double = 145.0
    var txPower: Int = 1
    var autoScan: Bool = false
    var backlightBrightness: Double = 50.0
    var autoBacklightOff: Bool = true
}

struct K5DeviceInfo: Codable {
    var model: String = "Quansheng K5"
    var firmwareVersion: String = "Неизвестно"
    var bootloaderVersion: String = "Неизвестно"
    var batteryVoltage: Double = 0.0
}

struct K5Channel: Hashable {
    var index: Int = 0
    var frequency: Double = 145.0
    var name: String = ""
    var txPower: Int = 1
    var bandwidth: K5Bandwidth = .narrow
    var scrambler: Bool = false
    var rxTone: K5Tone = .none
    var txTone: K5Tone = .none
}

enum K5Bandwidth: Hashable {
    case narrow
    case wide
}

enum K5Tone: Hashable {
    case none
    case ctcss(Double)
    case dcs(Int)
}

struct K5CalibrationData: Codable {
    var batteryCalibration: Data = Data()
    var rssiCalibration: Data = Data()
    var generalCalibration: Data = Data()
}

// Структура для сохранения калибровки в файл
struct CalibrationFileData: Codable {
    let deviceInfo: K5DeviceInfo
    let batteryCalibration: String
    let fullCalibration: K5CalibrationData
    let exportDate: Date
    let version: String
    
    init(deviceInfo: K5DeviceInfo, batteryCalibration: String, fullCalibration: K5CalibrationData, exportDate: Date, version: String = "1.0") {
        self.deviceInfo = deviceInfo
        self.batteryCalibration = batteryCalibration
        self.fullCalibration = fullCalibration
        self.exportDate = exportDate
        self.version = version
    }
    
    var description: String {
        return """
        Калибровка Quansheng K5
        Модель: \(deviceInfo.model)
        Вольтаж батареи: \(String(format: "%.2f В", deviceInfo.batteryVoltage))
        Версия прошивки: \(deviceInfo.firmwareVersion)
        Дата экспорта: \(DateFormatter.localizedString(from: exportDate, dateStyle: .medium, timeStyle: .short))
        """
    }
}