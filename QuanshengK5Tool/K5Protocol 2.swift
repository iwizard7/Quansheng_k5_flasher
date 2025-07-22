import Foundation
import IOKit.usb

enum K5ProtocolError: Error {
    case deviceNotConnected
    case communicationError
    case invalidResponse
    case checksumError
    case timeout
    case unsupportedOperation
}

class K5Protocol {
    
    // Команды протокола K5 (основаны на реверс-инжиниринге и документации сообщества)
    private enum Command: UInt8 {
        // Основные команды связи
        case handshake = 0x14          // Инициализация связи
        case acknowledge = 0x06        // Подтверждение
        
        // Команды чтения/записи памяти
        case readMemory = 0x1B         // Чтение блока памяти
        case writeMemory = 0x1D        // Запись блока памяти
        case readEEPROM = 0x1A         // Чтение EEPROM
        case writeEEPROM = 0x1C        // Запись EEPROM
        
        // Команды загрузчика
        case enterBootloader = 0x18    // Вход в режим загрузчика
        case exitBootloader = 0x16     // Выход из режима загрузчика
        case eraseFlash = 0x15         // Стирание flash памяти
        case writeFlash = 0x19         // Запись flash памяти
        
        // Информационные команды
        case readVersion = 0x17        // Чтение версии прошивки
        case readDeviceID = 0x05       // Чтение ID устройства
        
        // Специфичные команды K5
        case readCalibration = 0x33    // Чтение калибровочных данных
        case writeCalibration = 0x34   // Запись калибровочных данных
        case readSettings = 0x35       // Чтение настроек
        case writeSettings = 0x36      // Запись настроек
    }
    
    // Адреса памяти K5 (основаны на анализе прошивки и документации сообщества)
    private enum MemoryAddress {
        // Основные области памяти
        static let flashStart: UInt32 = 0x08000000      // Начало Flash памяти
        static let flashSize: UInt32 = 0x10000          // 64KB Flash
        static let eepromStart: UInt16 = 0x0000         // Начало EEPROM
        static let eepromSize: UInt16 = 0x2000          // 8KB EEPROM
        
        // Калибровочные данные
        static let batteryCalibration: UInt16 = 0x1EC0  // Калибровка батареи
        static let rssiCalibration: UInt16 = 0x1F80     // Калибровка RSSI
        static let txCalibration: UInt16 = 0x1F40       // Калибровка передатчика
        static let rxCalibration: UInt16 = 0x1F60       // Калибровка приемника
        
        // Настройки и конфигурация
        static let deviceInfo: UInt16 = 0x0000          // Информация об устройстве
        static let firmwareVersion: UInt16 = 0x2000     // Версия прошивки
        static let settings: UInt16 = 0x0E70            // Основные настройки
        static let menuSettings: UInt16 = 0x0F50        // Настройки меню
        
        // Каналы памяти
        static let channels: UInt16 = 0x0F30            // Начало каналов памяти
        static let channelSize: UInt16 = 0x10           // Размер одного канала (16 байт)
        static let maxChannels: UInt16 = 200            // Максимальное количество каналов
        
        // Дополнительные области
        static let scanList: UInt16 = 0x1D00            // Список сканирования
        static let dtmfSettings: UInt16 = 0x1E00        // Настройки DTMF
        static let fmSettings: UInt16 = 0x1E80          // Настройки FM радио
    }
    
    private let timeout: TimeInterval = 5.0
    private let maxRetries = 3
    
    // MARK: - Основные операции
    
    func performHandshake(interface: IOUSBInterfaceInterface300?) async throws {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        // Этап 1: Инициализация связи с K5
        // Отправляем команду handshake с магическими байтами K5
        let initData = Data([0x14, 0x05, 0x04, 0x00, 0x6a, 0x39, 0x57, 0x64])
        let initResponse = try await sendCommand(initData, interface: interface)
        
        // Проверяем ответ устройства
        guard initResponse.count >= 8 && initResponse[0] == 0x18 else {
            throw K5ProtocolError.invalidResponse
        }
        
        // Этап 2: Подтверждение установления связи
        let confirmData = Data([0x14, 0x05, 0x20, 0x15, 0x75, 0x25])
        let confirmResponse = try await sendCommand(confirmData, interface: interface)
        
        guard confirmResponse.count >= 4 && confirmResponse[0] == 0x18 else {
            throw K5ProtocolError.invalidResponse
        }
        
        // Этап 3: Финальное подтверждение готовности
        let readyData = Data([Command.acknowledge.rawValue, 0x02, 0x00, 0x00])
        let readyResponse = try await sendCommand(readyData, interface: interface)
        
        guard readyResponse.count >= 4 && readyResponse[0] == Command.acknowledge.rawValue else {
            throw K5ProtocolError.invalidResponse
        }
        
        // Стабилизация соединения
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    // MARK: - Операции с батареей
    
    func readBatteryCalibration(interface: IOUSBInterfaceInterface300?) async throws -> Data {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        // Читаем калибровочные данные батареи из EEPROM
        let command = createReadEEPROMCommand(address: MemoryAddress.batteryCalibration, length: 16)
        let response = try await sendCommand(command, interface: interface)
        
        guard response.count >= 20 && response[0] == Command.acknowledge.rawValue else {
            throw K5ProtocolError.invalidResponse
        }
        
        return Data(response.dropFirst(4)) // Убираем заголовок протокола
    }
    
    func writeBatteryCalibration(_ data: Data, interface: IOUSBInterfaceInterface300?) async throws {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        let command = createWriteEEPROMCommand(address: MemoryAddress.batteryCalibration, data: data)
        let response = try await sendCommand(command, interface: interface)
        
        // Проверяем успешность записи
        guard response.count >= 4 && response[0] == Command.acknowledge.rawValue else {
            throw K5ProtocolError.invalidResponse
        }
        
        // Небольшая задержка для завершения записи в EEPROM
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
    
    // MARK: - Операции с прошивкой
    
    func readFirmwareVersion(interface: IOUSBInterfaceInterface300?) async throws -> String {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        let command = createReadCommand(address: MemoryAddress.firmwareVersion, length: 16)
        let response = try await sendCommand(command, interface: interface)
        
        guard response.count >= 16 else {
            throw K5ProtocolError.invalidResponse
        }
        
        let versionData = Data(response.dropFirst(4).prefix(16))
        return parseVersionString(from: versionData)
    }
    
    func flashFirmware(_ firmwareData: Data, interface: IOUSBInterfaceInterface300?, progressCallback: @escaping (Double) -> Void) async throws {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        // Входим в режим загрузчика
        try await enterBootloader(interface: interface)
        
        // Стираем flash память
        try await eraseFlash(interface: interface)
        progressCallback(0.1)
        
        // Записываем прошивку блоками
        let blockSize = 256
        let totalBlocks = (firmwareData.count + blockSize - 1) / blockSize
        
        for blockIndex in 0..<totalBlocks {
            let startOffset = blockIndex * blockSize
            let endOffset = min(startOffset + blockSize, firmwareData.count)
            let blockData = firmwareData.subdata(in: startOffset..<endOffset)
            
            let address = UInt32(MemoryAddress.flashStart) + UInt32(startOffset)
            try await writeFlashBlock(address: UInt16(address & 0xFFFF), data: blockData, interface: interface)
            
            let progress = 0.1 + (Double(blockIndex + 1) / Double(totalBlocks)) * 0.9
            progressCallback(progress)
        }
        
        // Выходим из режима загрузчика
        try await exitBootloader(interface: interface)
    }
    
    // MARK: - Операции с настройками
    
    func readSettings(interface: IOUSBInterfaceInterface300?) async throws -> K5Settings {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        let command = createReadCommand(address: MemoryAddress.settings, length: 32)
        let response = try await sendCommand(command, interface: interface)
        
        guard response.count >= 32 else {
            throw K5ProtocolError.invalidResponse
        }
        
        let settingsData = Data(response.dropFirst(4))
        return parseSettings(from: settingsData)
    }
    
    func writeSettings(_ settings: K5Settings, interface: IOUSBInterfaceInterface300?) async throws {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        let settingsData = encodeSettings(settings)
        let command = createWriteCommand(address: MemoryAddress.settings, data: settingsData)
        let response = try await sendCommand(command, interface: interface)
        
        guard response.count >= 4 && response[0] == 0x18 else {
            throw K5ProtocolError.invalidResponse
        }
    }
    
    // MARK: - Операции с каналами
    
    func readChannels(interface: IOUSBInterfaceInterface300?) async throws -> [K5Channel] {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        var channels: [K5Channel] = []
        let channelSize = 16 // Размер одного канала в байтах
        let maxChannels = 200 // Максимальное количество каналов
        
        for channelIndex in 0..<maxChannels {
            let address = MemoryAddress.channels + UInt16(channelIndex * channelSize)
            let command = createReadCommand(address: address, length: UInt8(channelSize))
            
            do {
                let response = try await sendCommand(command, interface: interface)
                if response.count >= channelSize + 4 {
                    let channelData = Data(response.dropFirst(4))
                    if let channel = parseChannel(from: channelData, index: channelIndex) {
                        channels.append(channel)
                    }
                }
            } catch {
                // Прекращаем чтение при ошибке (возможно, достигли конца каналов)
                break
            }
        }
        
        return channels
    }
    
    func writeChannels(_ channels: [K5Channel], interface: IOUSBInterfaceInterface300?) async throws {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        let channelSize = 16
        
        for (index, channel) in channels.enumerated() {
            let address = MemoryAddress.channels + UInt16(index * channelSize)
            let channelData = encodeChannel(channel)
            let command = createWriteCommand(address: address, data: channelData)
            
            let response = try await sendCommand(command, interface: interface)
            guard response.count >= 4 && response[0] == 0x18 else {
                throw K5ProtocolError.invalidResponse
            }
        }
    }
    
    // MARK: - Расширенная калибровка
    
    func readFullCalibration(interface: IOUSBInterfaceInterface300?) async throws -> K5CalibrationData {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        var calibration = K5CalibrationData()
        
        // Читаем калибровку батареи
        let batteryCommand = createReadCommand(address: MemoryAddress.batteryCalibration, length: 16)
        let batteryResponse = try await sendCommand(batteryCommand, interface: interface)
        if batteryResponse.count >= 20 {
            calibration.batteryCalibration = Data(batteryResponse.dropFirst(4))
        }
        
        // Читаем калибровку RSSI
        let rssiCommand = createReadCommand(address: MemoryAddress.rssiCalibration, length: 32)
        let rssiResponse = try await sendCommand(rssiCommand, interface: interface)
        if rssiResponse.count >= 36 {
            calibration.rssiCalibration = Data(rssiResponse.dropFirst(4))
        }
        
        // Читаем калибровку TX
        let txCommand = createReadCommand(address: MemoryAddress.txCalibration, length: 32)
        let txResponse = try await sendCommand(txCommand, interface: interface)
        if txResponse.count >= 36 {
            calibration.generalCalibration = Data(txResponse.dropFirst(4))
        }
        
        return calibration
    }
    
    func writeFullCalibration(_ calibration: K5CalibrationData, interface: IOUSBInterfaceInterface300?) async throws {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        // Записываем калибровку батареи
        if !calibration.batteryCalibration.isEmpty {
            let batteryCommand = createWriteCommand(address: MemoryAddress.batteryCalibration, data: calibration.batteryCalibration)
            let batteryResponse = try await sendCommand(batteryCommand, interface: interface)
            guard batteryResponse.count >= 4 && batteryResponse[0] == 0x18 else {
                throw K5ProtocolError.invalidResponse
            }
        }
        
        // Записываем калибровку RSSI
        if !calibration.rssiCalibration.isEmpty {
            let rssiCommand = createWriteCommand(address: MemoryAddress.rssiCalibration, data: calibration.rssiCalibration)
            let rssiResponse = try await sendCommand(rssiCommand, interface: interface)
            guard rssiResponse.count >= 4 && rssiResponse[0] == 0x18 else {
                throw K5ProtocolError.invalidResponse
            }
        }
        
        // Записываем калибровку TX
        if !calibration.generalCalibration.isEmpty {
            let txCommand = createWriteCommand(address: MemoryAddress.txCalibration, data: calibration.generalCalibration)
            let txResponse = try await sendCommand(txCommand, interface: interface)
            guard txResponse.count >= 4 && txResponse[0] == 0x18 else {
                throw K5ProtocolError.invalidResponse
            }
        }
    }
    
    // MARK: - Информация об устройстве
    
    func readDeviceInfo(interface: IOUSBInterfaceInterface300?) async throws -> K5DeviceInfo {
        guard let interface = interface else {
            throw K5ProtocolError.deviceNotConnected
        }
        
        try await performHandshake(interface: interface)
        
        var deviceInfo = K5DeviceInfo()
        
        // Читаем версию прошивки
        deviceInfo.firmwareVersion = try await readFirmwareVersion(interface: interface)
        
        // Читаем серийный номер и другую информацию
        let infoCommand = createReadCommand(address: MemoryAddress.deviceInfo, length: 64)
        let response = try await sendCommand(infoCommand, interface: interface)
        
        if response.count >= 64 {
            let infoData = Data(response.dropFirst(4))
            deviceInfo = parseDeviceInfo(from: infoData, existingInfo: deviceInfo)
        }
        
        return deviceInfo
    }
    
    // MARK: - Приватные методы
    
    private func sendCommand(_ command: Data, interface: IOUSBInterfaceInterface300) async throws -> Data {
        for attempt in 0..<maxRetries {
            do {
                return try await performUSBTransaction(command, interface: interface)
            } catch {
                if attempt == maxRetries - 1 {
                    throw error
                }
                // Небольшая задержка перед повтором
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        throw K5ProtocolError.communicationError
    }
    
    private func performUSBTransaction(_ data: Data, interface: IOUSBInterfaceInterface300) async throws -> Data {
        // Упрощенная реализация для демонстрации
        print("Отправка команды: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Имитируем задержку коммуникации
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Возвращаем фиктивный ответ для тестирования
        // В реальной реализации здесь должна быть настоящая USB коммуникация
        let mockResponse = Data([0x18, 0x00, 0x00, 0x00] + Array(repeating: 0x00, count: 16))
        
        print("Получен ответ: \(mockResponse.map { String(format: "%02X", $0) }.joined(separator: " "))")
        return mockResponse
    }
    
    private func createReadCommand(address: UInt16, length: UInt8) -> Data {
        var command = Data()
        command.append(Command.readMemory.rawValue)
        command.append(contentsOf: withUnsafeBytes(of: address.littleEndian) { Array($0) })
        command.append(length)
        command.append(calculateChecksum(command))
        return command
    }
    
    private func createWriteCommand(address: UInt16, data: Data) -> Data {
        var command = Data()
        command.append(Command.writeMemory.rawValue)
        command.append(contentsOf: withUnsafeBytes(of: address.littleEndian) { Array($0) })
        command.append(UInt8(data.count))
        command.append(contentsOf: data)
        command.append(calculateChecksum(command))
        return command
    }
    
    private func createReadEEPROMCommand(address: UInt16, length: UInt8) -> Data {
        var command = Data()
        command.append(Command.readEEPROM.rawValue)
        command.append(contentsOf: withUnsafeBytes(of: address.littleEndian) { Array($0) })
        command.append(length)
        command.append(calculateChecksum(command))
        return command
    }
    
    private func createWriteEEPROMCommand(address: UInt16, data: Data) -> Data {
        var command = Data()
        command.append(Command.writeEEPROM.rawValue)
        command.append(contentsOf: withUnsafeBytes(of: address.littleEndian) { Array($0) })
        command.append(UInt8(data.count))
        command.append(contentsOf: data)
        command.append(calculateChecksum(command))
        return command
    }
    
    private func calculateChecksum(_ data: Data) -> UInt8 {
        return data.reduce(0) { $0 ^ $1 }
    }
    
    private func enterBootloader(interface: IOUSBInterfaceInterface300) async throws {
        let command = Data([Command.enterBootloader.rawValue, 0x00, 0x00, 0x00])
        let response = try await sendCommand(command, interface: interface)
        
        guard response.count >= 4 && response[0] == 0x18 else {
            throw K5ProtocolError.invalidResponse
        }
        
        // Ждем переключения в режим загрузчика
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 секунда
    }
    
    private func exitBootloader(interface: IOUSBInterfaceInterface300) async throws {
        let command = Data([Command.exitBootloader.rawValue, 0x00, 0x00, 0x00])
        _ = try await sendCommand(command, interface: interface)
        
        // Ждем перезагрузки устройства
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 секунды
    }
    
    private func eraseFlash(interface: IOUSBInterfaceInterface300) async throws {
        let command = Data([Command.eraseFlash.rawValue, 0x00, 0x00, 0x00])
        let response = try await sendCommand(command, interface: interface)
        
        guard response.count >= 4 && response[0] == 0x18 else {
            throw K5ProtocolError.invalidResponse
        }
        
        // Ждем завершения стирания
        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 секунд
    }
    
    private func writeFlashBlock(address: UInt16, data: Data, interface: IOUSBInterfaceInterface300) async throws {
        let command = createWriteCommand(address: address, data: data)
        let response = try await sendCommand(command, interface: interface)
        
        guard response.count >= 4 && response[0] == 0x18 else {
            throw K5ProtocolError.invalidResponse
        }
    }
    
    // MARK: - Парсинг данных
    
    private func parseVersionString(from data: Data) -> String {
        // Ищем строку версии в данных
        if let versionString = String(data: data, encoding: .ascii) {
            return versionString.trimmingCharacters(in: .controlCharacters)
        }
        return "Неизвестно"
    }
    
    private func parseSettings(from data: Data) -> K5Settings {
        var settings = K5Settings()
        
        guard data.count >= 32 else { return settings }
        
        // Парсим настройки из бинарных данных
        // Это примерная структура, нужно уточнить по документации
        let frequencyBytes = data.subdata(in: 0..<4)
        settings.defaultFrequency = Double(frequencyBytes.withUnsafeBytes { $0.load(as: UInt32.self) }) / 1000000.0
        
        settings.txPower = Int(data[4])
        settings.autoScan = data[5] != 0
        settings.backlightBrightness = Double(data[6])
        settings.autoBacklightOff = data[7] != 0
        
        return settings
    }
    
    private func encodeSettings(_ settings: K5Settings) -> Data {
        var data = Data(count: 32)
        
        // Кодируем настройки в бинарный формат
        let frequencyValue = UInt32(settings.defaultFrequency * 1000000)
        data.replaceSubrange(0..<4, with: withUnsafeBytes(of: frequencyValue) { Data($0) })
        
        data[4] = UInt8(settings.txPower)
        data[5] = settings.autoScan ? 1 : 0
        data[6] = UInt8(settings.backlightBrightness)
        data[7] = settings.autoBacklightOff ? 1 : 0
        
        return data
    }
    
    private func parseDeviceInfo(from data: Data, existingInfo: K5DeviceInfo) -> K5DeviceInfo {
        var info = existingInfo
        
        guard data.count >= 64 else { return info }
        
        // Парсим информацию об устройстве
        // Серийный номер (предположительно в начале)
        if let serialString = String(data: data.subdata(in: 0..<16), encoding: .ascii) {
            info.serialNumber = serialString.trimmingCharacters(in: .controlCharacters)
        }
        
        // Дата производства (предположительно)
        if let dateString = String(data: data.subdata(in: 16..<32), encoding: .ascii) {
            info.manufacturingDate = dateString.trimmingCharacters(in: .controlCharacters)
        }
        
        return info
    }
    
    private func parseChannel(from data: Data, index: Int) -> K5Channel? {
        guard data.count >= 16 else { return nil }
        
        // Проверяем, что канал не пустой
        let isEmpty = data.allSatisfy { $0 == 0xFF || $0 == 0x00 }
        if isEmpty { return nil }
        
        var channel = K5Channel()
        channel.index = index
        
        // Парсим частоту (4 байта, little endian)
        let frequencyBytes = data.subdata(in: 0..<4)
        let frequencyValue = frequencyBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
        channel.frequency = Double(frequencyValue) / 100000.0 // Конвертируем в MHz
        
        // Парсим настройки канала
        channel.txPower = Int(data[4] & 0x03)
        channel.bandwidth = (data[4] & 0x10) != 0 ? .wide : .narrow
        channel.scrambler = (data[4] & 0x20) != 0
        
        // Парсим CTCSS/DCS коды
        let rxTone = UInt16(data[5]) | (UInt16(data[6]) << 8)
        let txTone = UInt16(data[7]) | (UInt16(data[8]) << 8)
        
        channel.rxTone = parseTone(rxTone)
        channel.txTone = parseTone(txTone)
        
        // Парсим имя канала (если есть)
        let nameData = data.subdata(in: 9..<16)
        if let name = String(data: nameData, encoding: .ascii) {
            channel.name = name.trimmingCharacters(in: .controlCharacters)
        }
        
        return channel
    }
    
    private func encodeChannel(_ channel: K5Channel) -> Data {
        var data = Data(count: 16)
        
        // Кодируем частоту
        let frequencyValue = UInt32(channel.frequency * 100000)
        data.replaceSubrange(0..<4, with: withUnsafeBytes(of: frequencyValue.littleEndian) { Data($0) })
        
        // Кодируем настройки
        var settings: UInt8 = 0
        settings |= UInt8(channel.txPower & 0x03)
        if channel.bandwidth == .wide { settings |= 0x10 }
        if channel.scrambler { settings |= 0x20 }
        data[4] = settings
        
        // Кодируем тоны
        let rxToneValue = encodeTone(channel.rxTone)
        let txToneValue = encodeTone(channel.txTone)
        
        data[5] = UInt8(rxToneValue & 0xFF)
        data[6] = UInt8((rxToneValue >> 8) & 0xFF)
        data[7] = UInt8(txToneValue & 0xFF)
        data[8] = UInt8((txToneValue >> 8) & 0xFF)
        
        // Кодируем имя канала
        if let nameData = channel.name.data(using: .ascii) {
            let nameRange = 9..<min(16, 9 + nameData.count)
            data.replaceSubrange(nameRange, with: nameData.prefix(7))
        }
        
        return data
    }
    
    private func parseTone(_ value: UInt16) -> K5Tone {
        if value == 0 || value == 0xFFFF {
            return .none
        } else if value < 1000 {
            return .ctcss(Double(value) / 10.0)
        } else {
            return .dcs(Int(value))
        }
    }
    
    private func encodeTone(_ tone: K5Tone) -> UInt16 {
        switch tone {
        case .none:
            return 0
        case .ctcss(let frequency):
            return UInt16(frequency * 10)
        case .dcs(let code):
            return UInt16(code)
        }
    }
}