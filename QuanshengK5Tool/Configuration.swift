import Foundation

// MARK: - Конфигурация приложения

struct AppConfiguration {
    static let shared = AppConfiguration()
    
    // Версия приложения
    static let version = "1.0.0"
    static let buildNumber = "1"
    
    // USB параметры
    struct USB {
        static let vendorID: UInt16 = 0x0483  // STMicroelectronics
        static let productID: UInt16 = 0x5740 // Quansheng K5
        static let baudRate: speed_t = speed_t(B38400)
        static let timeout: TimeInterval = 5.0
        static let maxRetries = 3
    }
    
    // Параметры серийного порта
    struct SerialPort {
        static let prefixes = [
            "tty.usbserial", "tty.usbmodem", 
            "cu.usbserial", "cu.usbmodem", 
            "tty.SLAB_USBtoUART", "cu.SLAB_USBtoUART",
            "tty.wchusbserial", "cu.wchusbserial"
        ]
        static let readTimeout: TimeInterval = 2.0
        static let writeTimeout: TimeInterval = 1.0
    }
    
    // Параметры K5
    struct K5 {
        static let maxChannels = 200
        static let channelSize = 16
        static let maxChannelNameLength = 7
        static let frequencyRange = 136.0...174.0
        static let flashSize: UInt32 = 0x10000  // 64KB
        static let eepromSize: UInt16 = 0x2000  // 8KB
    }
    
    // Настройки UI
    struct UI {
        static let minWindowWidth: CGFloat = 700
        static let minWindowHeight: CGFloat = 500
        static let sidebarWidth: CGFloat = 250
        static let maxLogEntries = 1000
        static let autoScrollDelay: TimeInterval = 0.3
    }
    
    // Настройки файлов
    struct Files {
        static let calibrationFileVersion = "1.0"
        static let channelFileVersion = "1.0"
        static let maxFileSize: Int64 = 10 * 1024 * 1024 // 10MB
    }
    
    private init() {}
}

// MARK: - Константы протокола K5

struct K5Constants {
    // Команды протокола
    enum Command: UInt8 {
        case handshake = 0x14
        case acknowledge = 0x06
        case readMemory = 0x1B
        case writeMemory = 0x1D
        case readEEPROM = 0x1A
        case writeEEPROM = 0x1C
        case enterBootloader = 0x18
        case exitBootloader = 0x16
        case eraseFlash = 0x15
        case writeFlash = 0x19
        case readVersion = 0x17
        case readDeviceID = 0x05
        case readCalibration = 0x33
        case writeCalibration = 0x34
        case readSettings = 0x35
        case writeSettings = 0x36
    }
    
    // Адреса памяти
    enum MemoryAddress {
        static let flashStart: UInt32 = 0x08000000
        static let flashSize: UInt32 = 0x10000
        static let eepromStart: UInt16 = 0x0000
        static let eepromSize: UInt16 = 0x2000
        static let batteryCalibration: UInt16 = 0x1EC0
        static let rssiCalibration: UInt16 = 0x1F80
        static let txCalibration: UInt16 = 0x1F40
        static let rxCalibration: UInt16 = 0x1F60
        static let deviceInfo: UInt16 = 0x0000
        static let firmwareVersion: UInt16 = 0x2000
        static let settings: UInt16 = 0x0E70
        static let menuSettings: UInt16 = 0x0F50
        static let channels: UInt16 = 0x0F30
        static let channelSize: UInt16 = 0x10
        static let maxChannels: UInt16 = 200
        static let scanList: UInt16 = 0x1D00
        static let dtmfSettings: UInt16 = 0x1E00
        static let fmSettings: UInt16 = 0x1E80
    }
    
    // Handshake последовательности
    static let handshakeInit = Data([0x14, 0x05, 0x04, 0x00, 0x6a, 0x39, 0x57, 0x64])
    static let handshakeConfirm = Data([0x14, 0x05, 0x20, 0x15, 0x75, 0x25])
    static let handshakeReady = Data([0x06, 0x02, 0x00, 0x00])
}

// MARK: - Настройки пользователя

class UserSettings: ObservableObject {
    @Published var autoConnectToLastPort = true
    @Published var autoRefreshPorts = true
    @Published var showAdvancedOptions = false
    @Published var logLevel: LogLevel = .info
    @Published var autoScrollLog = true
    @Published var maxLogEntries = 1000
    @Published var backupBeforeWrite = true
    @Published var validateChannelsBeforeWrite = true
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        autoConnectToLastPort = userDefaults.bool(forKey: "autoConnectToLastPort")
        autoRefreshPorts = userDefaults.bool(forKey: "autoRefreshPorts")
        showAdvancedOptions = userDefaults.bool(forKey: "showAdvancedOptions")
        autoScrollLog = userDefaults.bool(forKey: "autoScrollLog")
        maxLogEntries = userDefaults.integer(forKey: "maxLogEntries")
        backupBeforeWrite = userDefaults.bool(forKey: "backupBeforeWrite")
        validateChannelsBeforeWrite = userDefaults.bool(forKey: "validateChannelsBeforeWrite")
        
        if let logLevelString = userDefaults.string(forKey: "logLevel"),
           let level = LogLevel(rawValue: logLevelString) {
            logLevel = level
        }
        
        // Устанавливаем значения по умолчанию, если они не были сохранены
        if maxLogEntries == 0 {
            maxLogEntries = 1000
        }
    }
    
    func saveSettings() {
        userDefaults.set(autoConnectToLastPort, forKey: "autoConnectToLastPort")
        userDefaults.set(autoRefreshPorts, forKey: "autoRefreshPorts")
        userDefaults.set(showAdvancedOptions, forKey: "showAdvancedOptions")
        userDefaults.set(logLevel.rawValue, forKey: "logLevel")
        userDefaults.set(autoScrollLog, forKey: "autoScrollLog")
        userDefaults.set(maxLogEntries, forKey: "maxLogEntries")
        userDefaults.set(backupBeforeWrite, forKey: "backupBeforeWrite")
        userDefaults.set(validateChannelsBeforeWrite, forKey: "validateChannelsBeforeWrite")
    }
}

// MARK: - Валидация

struct ValidationRules {
    static func validateFrequency(_ frequency: Double) -> Bool {
        return AppConfiguration.K5.frequencyRange.contains(frequency)
    }
    
    static func validateChannelName(_ name: String) -> Bool {
        return name.count <= AppConfiguration.K5.maxChannelNameLength
    }
    
    static func validateTxPower(_ power: Int) -> Bool {
        return (0...2).contains(power)
    }
    
    static func validateCTCSS(_ frequency: Double) -> Bool {
        return (67.0...254.1).contains(frequency)
    }
    
    static func validateDCS(_ code: Int) -> Bool {
        return (1...999).contains(code)
    }
}

// MARK: - Ошибки приложения

enum AppError: Error, LocalizedError {
    case deviceNotFound
    case connectionFailed(String)
    case communicationTimeout
    case invalidData(String)
    case fileOperationFailed(String)
    case validationFailed([String])
    case unsupportedOperation
    
    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Устройство Quansheng K5 не найдено"
        case .connectionFailed(let reason):
            return "Ошибка подключения: \(reason)"
        case .communicationTimeout:
            return "Превышено время ожидания ответа от устройства"
        case .invalidData(let details):
            return "Неверные данные: \(details)"
        case .fileOperationFailed(let details):
            return "Ошибка работы с файлом: \(details)"
        case .validationFailed(let errors):
            return "Ошибки валидации: \(errors.joined(separator: ", "))"
        case .unsupportedOperation:
            return "Операция не поддерживается"
        }
    }
}