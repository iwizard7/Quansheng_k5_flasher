import Foundation
import AppKit
import UniformTypeIdentifiers

// Простая версия CalibrationManager для начала
class SimpleCalibrationManager {
    private let logManager: SimpleLogManager?
    
    init(logManager: SimpleLogManager? = nil) {
        self.logManager = logManager
    }
    
    // Сохранение калибровки батареи в файл
    func saveCalibrationToFile(_ calibrationData: String, deviceInfo: K5DeviceInfo) -> Bool {
        let savePanel = NSSavePanel()
        savePanel.title = "Сохранить калибровку батареи"
        savePanel.allowedContentTypes = [UTType.json]
        savePanel.nameFieldStringValue = "K5_Battery_Calibration_\(deviceInfo.serialNumber).json"
        
        guard savePanel.runModal() == .OK,
              let url = savePanel.url else {
            logManager?.log("Отменено сохранение калибровки")
            return false
        }
        
        let calibration = SimpleCalibrationFile(
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
            
            logManager?.log("Калибровка сохранена в файл: \(url.lastPathComponent)")
            return true
        } catch {
            logManager?.log("Ошибка сохранения калибровки: \(error.localizedDescription)")
            return false
        }
    }
    
    // Загрузка калибровки батареи из файла
    func loadCalibrationFromFile() -> (String, K5DeviceInfo)? {
        let openPanel = NSOpenPanel()
        openPanel.title = "Загрузить калибровку батареи"
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.allowsMultipleSelection = false
        
        guard openPanel.runModal() == .OK,
              let url = openPanel.url else {
            logManager?.log("Отменена загрузка калибровки")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let calibration = try decoder.decode(SimpleCalibrationFile.self, from: data)
            
            logManager?.log("Калибровка загружена из файла: \(url.lastPathComponent)")
            logManager?.log("Устройство: \(calibration.deviceInfo.model), S/N: \(calibration.deviceInfo.serialNumber)")
            
            return (calibration.batteryCalibration, calibration.deviceInfo)
        } catch {
            logManager?.log("Ошибка загрузки калибровки: \(error.localizedDescription)")
            return nil
        }
    }
}

// Структура для файла калибровки
struct SimpleCalibrationFile: Codable {
    let deviceInfo: K5DeviceInfo
    let batteryCalibration: String
    let timestamp: Date
    let version: String
}