import Foundation
import AppKit
import UniformTypeIdentifiers

class CalibrationManager {
    private let logManager: LogManager?
    
    init(logManager: LogManager? = nil) {
        self.logManager = logManager
    }
    
    // MARK: - Сохранение калибровок
    
    func saveCalibrationToFile(_ calibrationData: String, deviceInfo: K5DeviceInfo) -> Bool {
        let savePanel = NSSavePanel()
        savePanel.title = "Сохранить калибровку батареи"
        savePanel.allowedContentTypes = [UTType.json]
        savePanel.nameFieldStringValue = "K5_Battery_Calibration_\(deviceInfo.model).json"
        
        guard savePanel.runModal() == .OK,
              let url = savePanel.url else {
            logManager?.log("Отменено сохранение калибровки", level: .info)
            return false
        }
        
        let calibration = CalibrationFile(
            deviceInfo: deviceInfo,
            batteryCalibration: calibrationData,
            timestamp: Date(),
            version: "1.0"
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(calibration)
            try data.write(to: url)
            
            logManager?.log("Калибровка сохранена в файл: \(url.lastPathComponent)", level: .success)
            return true
        } catch {
            logManager?.log("Ошибка сохранения калибровки: \(error.localizedDescription)", level: .error)
            return false
        }
    }
    
    func saveFullCalibrationToFile(_ calibration: K5CalibrationData, deviceInfo: K5DeviceInfo) -> Bool {
        let savePanel = NSSavePanel()
        savePanel.title = "Сохранить полную калибровку"
        savePanel.allowedContentTypes = [UTType.json]
        savePanel.nameFieldStringValue = "K5_Full_Calibration_\(deviceInfo.model).json"
        
        guard savePanel.runModal() == .OK,
              let url = savePanel.url else {
            logManager?.log("Отменено сохранение полной калибровки", level: .info)
            return false
        }
        
        let fullCalibration = FullCalibrationFile(
            deviceInfo: deviceInfo,
            batteryCalibration: calibration.batteryCalibration.base64EncodedString(),
            rssiCalibration: calibration.rssiCalibration.base64EncodedString(),
            generalCalibration: calibration.generalCalibration.base64EncodedString(),
            timestamp: Date(),
            version: "1.0"
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            let data = try encoder.encode(fullCalibration)
            try data.write(to: url)
            
            logManager?.log("Полная калибровка сохранена в файл: \(url.lastPathComponent)", level: .success)
            return true
        } catch {
            logManager?.log("Ошибка сохранения полной калибровки: \(error.localizedDescription)", level: .error)
            return false
        }
    }
    
    // MARK: - Загрузка калибровок
    
    func loadCalibrationFromFile() -> (String, K5DeviceInfo)? {
        let openPanel = NSOpenPanel()
        openPanel.title = "Загрузить калибровку батареи"
        openPanel.allowedContentTypes = [UTType.json, UTType.data]
        openPanel.allowsOtherFileTypes = true
        openPanel.allowsMultipleSelection = false
        
        guard openPanel.runModal() == .OK,
              let url = openPanel.url else {
            logManager?.log("Отменена загрузка калибровки", level: .info)
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Проверяем расширение файла
            if url.pathExtension.lowercased() == "json" {
                // Загружаем JSON файл
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let calibration = try decoder.decode(CalibrationFile.self, from: data)
                
                logManager?.log("Калибровка загружена из JSON файла: \(url.lastPathComponent)", level: .success)
                logManager?.log("Устройство: \(calibration.deviceInfo.model)", level: .info)
                logManager?.log("Дата создания: \(formatDate(calibration.timestamp))", level: .info)
                
                return (calibration.batteryCalibration, calibration.deviceInfo)
            } else {
                // Загружаем .bin файл как сырые данные
                let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                let deviceInfo = K5DeviceInfo(
                    model: "Quansheng K5",
                    firmwareVersion: "Unknown",
                    bootloaderVersion: "Unknown",
                    batteryVoltage: 0.0
                )
                
                logManager?.log("Калибровка загружена из BIN файла: \(url.lastPathComponent)", level: .success)
                logManager?.log("Размер данных: \(data.count) байт", level: .info)
                
                return (hexString, deviceInfo)
            }
        } catch {
            logManager?.log("Ошибка загрузки калибровки: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
    
    func loadFullCalibrationFromFile() -> (K5CalibrationData, K5DeviceInfo)? {
        let openPanel = NSOpenPanel()
        openPanel.title = "Загрузить полную калибровку"
        openPanel.allowedContentTypes = [UTType.json, UTType.data]
        openPanel.allowsOtherFileTypes = true
        openPanel.allowsMultipleSelection = false
        
        guard openPanel.runModal() == .OK,
              let url = openPanel.url else {
            logManager?.log("Отменена загрузка полной калибровки", level: .info)
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            // Проверяем расширение файла
            if url.pathExtension.lowercased() == "json" {
                // Загружаем JSON файл
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let fullCalibration = try decoder.decode(FullCalibrationFile.self, from: data)
                
                guard let batteryData = Data(base64Encoded: fullCalibration.batteryCalibration),
                      let rssiData = Data(base64Encoded: fullCalibration.rssiCalibration),
                      let generalData = Data(base64Encoded: fullCalibration.generalCalibration) else {
                    logManager?.log("Ошибка декодирования данных калибровки", level: .error)
                    return nil
                }
                
                let calibrationData = K5CalibrationData(
                    batteryCalibration: batteryData,
                    rssiCalibration: rssiData,
                    generalCalibration: generalData
                )
                
                logManager?.log("Полная калибровка загружена из JSON файла: \(url.lastPathComponent)", level: .success)
                logManager?.log("Устройство: \(fullCalibration.deviceInfo.model)", level: .info)
                logManager?.log("Дата создания: \(formatDate(fullCalibration.timestamp))", level: .info)
                
                return (calibrationData, fullCalibration.deviceInfo)
            } else {
                // Загружаем .bin файл как сырые данные
                // Предполагаем, что .bin файл содержит только данные калибровки батареи
                let calibrationData = K5CalibrationData(
                    batteryCalibration: data,
                    rssiCalibration: Data(),
                    generalCalibration: Data()
                )
                
                let deviceInfo = K5DeviceInfo(
                    model: "Quansheng K5",
                    firmwareVersion: "Unknown",
                    bootloaderVersion: "Unknown",
                    batteryVoltage: 0.0
                )
                
                logManager?.log("Полная калибровка загружена из BIN файла: \(url.lastPathComponent)", level: .success)
                logManager?.log("Размер данных: \(data.count) байт", level: .info)
                
                return (calibrationData, deviceInfo)
            }
        } catch {
            logManager?.log("Ошибка загрузки полной калибровки: \(error.localizedDescription)", level: .error)
            return nil
        }
    }
    
    // MARK: - Сохранение в .bin формате
    
    func saveBatteryCalibrationToBinFile(_ calibrationData: String, deviceInfo: K5DeviceInfo) -> Bool {
        let savePanel = NSSavePanel()
        savePanel.title = "Сохранить калибровку батареи в BIN"
        savePanel.allowedContentTypes = [UTType.data]
        savePanel.nameFieldStringValue = "K5_Battery_Calibration_\(deviceInfo.model).bin"
        
        guard savePanel.runModal() == .OK,
              let url = savePanel.url else {
            logManager?.log("Отменено сохранение калибровки в BIN", level: .info)
            return false
        }
        
        // Конвертируем hex строку в Data
        let hexString = calibrationData.replacingOccurrences(of: " ", with: "")
        var data = Data()
        
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2, limitedBy: hexString.endIndex) ?? hexString.endIndex
            let byteString = String(hexString[index..<nextIndex])
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        
        do {
            try data.write(to: url)
            logManager?.log("Калибровка сохранена в BIN файл: \(url.lastPathComponent)", level: .success)
            return true
        } catch {
            logManager?.log("Ошибка сохранения калибровки в BIN: \(error.localizedDescription)", level: .error)
            return false
        }
    }
    
    // MARK: - Вспомогательные методы
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}

// MARK: - Структуры для файлов калибровки

struct CalibrationFile: Codable {
    let deviceInfo: K5DeviceInfo
    let batteryCalibration: String
    let timestamp: Date
    let version: String
}

struct FullCalibrationFile: Codable {
    let deviceInfo: K5DeviceInfo
    let batteryCalibration: String
    let rssiCalibration: String
    let generalCalibration: String
    let timestamp: Date
    let version: String
}

// K5DeviceInfo уже объявлен как Codable в USBCommunication.swift