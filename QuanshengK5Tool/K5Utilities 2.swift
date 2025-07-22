import Foundation

// MARK: - Утилиты для работы с файлами каналов

class K5Utilities {
    
    // MARK: - Экспорт/Импорт каналов
    
    static func exportChannels(_ channels: [K5Channel], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let exportData = K5ChannelExport(
            version: "1.0",
            deviceModel: "Quansheng K5",
            exportDate: Date(),
            channels: channels
        )
        
        let jsonData = try encoder.encode(exportData)
        try jsonData.write(to: url)
    }
    
    static func importChannels(from url: URL) throws -> [K5Channel] {
        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importData = try decoder.decode(K5ChannelExport.self, from: jsonData)
        return importData.channels
    }
    
    // MARK: - Работа с CSV файлами
    
    static func exportChannelsToCSV(_ channels: [K5Channel], to url: URL) throws {
        var csvContent = "Index,Name,Frequency,TxPower,Bandwidth,Scrambler,RxTone,TxTone\n"
        
        for channel in channels {
            let row = [
                String(channel.index),
                escapeCSVField(channel.name),
                String(format: "%.5f", channel.frequency),
                String(channel.txPower),
                channel.bandwidth == .wide ? "Wide" : "Narrow",
                channel.scrambler ? "Yes" : "No",
                toneToString(channel.rxTone),
                toneToString(channel.txTone)
            ].joined(separator: ",")
            
            csvContent += row + "\n"
        }
        
        try csvContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    static func importChannelsFromCSV(from url: URL) throws -> [K5Channel] {
        let csvContent = try String(contentsOf: url, encoding: .utf8)
        let lines = csvContent.components(separatedBy: .newlines)
        
        guard lines.count > 1 else {
            throw K5UtilitiesError.invalidCSVFormat
        }
        
        var channels: [K5Channel] = []
        
        // Пропускаем заголовок
        for line in lines.dropFirst() {
            guard !line.isEmpty else { continue }
            
            let fields = parseCSVLine(line)
            guard fields.count >= 8 else { continue }
            
            var channel = K5Channel()
            channel.index = Int(fields[0]) ?? 0
            channel.name = fields[1]
            channel.frequency = Double(fields[2]) ?? 145.0
            channel.txPower = Int(fields[3]) ?? 1
            channel.bandwidth = fields[4].lowercased() == "wide" ? .wide : .narrow
            channel.scrambler = fields[5].lowercased() == "yes"
            channel.rxTone = stringToTone(fields[6])
            channel.txTone = stringToTone(fields[7])
            
            channels.append(channel)
        }
        
        return channels
    }
    
    // MARK: - Работа с CHIRP файлами
    
    static func exportToCHIRP(_ channels: [K5Channel], to url: URL) throws {
        var chirpContent = "Location,Name,Frequency,Duplex,Offset,Tone,rToneFreq,cToneFreq,DtcsCode,DtcsPolarity,Mode,TStep,Skip,Comment,URCALL,RPT1CALL,RPT2CALL\n"
        
        for channel in channels {
            let row = [
                String(channel.index + 1), // CHIRP использует 1-based индексы
                escapeCSVField(channel.name),
                String(format: "%.5f", channel.frequency),
                "", // Duplex - пусто для симплекса
                "", // Offset - пусто
                toneTypeForCHIRP(channel.rxTone, channel.txTone),
                toneFrequencyForCHIRP(channel.rxTone),
                toneFrequencyForCHIRP(channel.txTone),
                dcsCodeForCHIRP(channel.rxTone, channel.txTone),
                "NN", // DCS Polarity
                "FM", // Mode
                "5.00", // TStep
                "", // Skip
                "", // Comment
                "", // URCALL
                "", // RPT1CALL
                ""  // RPT2CALL
            ].joined(separator: ",")
            
            chirpContent += row + "\n"
        }
        
        try chirpContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Валидация каналов
    
    static func validateChannel(_ channel: K5Channel) -> [String] {
        var errors: [String] = []
        
        // Проверка частоты
        if channel.frequency < 136.0 || channel.frequency > 174.0 {
            errors.append("Частота должна быть в диапазоне 136-174 MHz")
        }
        
        // Проверка имени
        if channel.name.count > 7 {
            errors.append("Имя канала не должно превышать 7 символов")
        }
        
        // Проверка мощности
        if channel.txPower < 0 || channel.txPower > 2 {
            errors.append("Мощность передачи должна быть 0, 1 или 2")
        }
        
        // Проверка тонов
        if case .ctcss(let freq) = channel.rxTone {
            if freq < 67.0 || freq > 254.1 {
                errors.append("Частота CTCSS RX должна быть в диапазоне 67.0-254.1 Hz")
            }
        }
        
        if case .ctcss(let freq) = channel.txTone {
            if freq < 67.0 || freq > 254.1 {
                errors.append("Частота CTCSS TX должна быть в диапазоне 67.0-254.1 Hz")
            }
        }
        
        return errors
    }
    
    static func validateChannels(_ channels: [K5Channel]) -> [String: [String]] {
        var allErrors: [String: [String]] = [:]
        
        for channel in channels {
            let errors = validateChannel(channel)
            if !errors.isEmpty {
                allErrors["Канал \(channel.index + 1)"] = errors
            }
        }
        
        return allErrors
    }
    
    // MARK: - Приватные методы
    
    private static func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false
        var i = line.startIndex
        
        while i < line.endIndex {
            let char = line[i]
            
            if char == "\"" {
                if inQuotes && i < line.index(before: line.endIndex) && line[line.index(after: i)] == "\"" {
                    currentField += "\""
                    i = line.index(after: i)
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField += String(char)
            }
            
            i = line.index(after: i)
        }
        
        fields.append(currentField)
        return fields
    }
    
    private static func toneToString(_ tone: K5Tone) -> String {
        switch tone {
        case .none:
            return "None"
        case .ctcss(let freq):
            return String(format: "CTCSS %.1f", freq)
        case .dcs(let code):
            return "DCS \(code)"
        }
    }
    
    private static func stringToTone(_ string: String) -> K5Tone {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        
        if trimmed.lowercased() == "none" || trimmed.isEmpty {
            return .none
        } else if trimmed.lowercased().hasPrefix("ctcss") {
            let freqString = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if let freq = Double(freqString) {
                return .ctcss(freq)
            }
        } else if trimmed.lowercased().hasPrefix("dcs") {
            let codeString = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
            if let code = Int(codeString) {
                return .dcs(code)
            }
        }
        
        return .none
    }
    
    private static func toneTypeForCHIRP(_ rxTone: K5Tone, _ txTone: K5Tone) -> String {
        switch (rxTone, txTone) {
        case (.none, .none):
            return ""
        case (.ctcss, .ctcss):
            return "Tone"
        case (.ctcss, .none):
            return "TSQL"
        case (.dcs, .dcs):
            return "DTCS"
        default:
            return "Cross"
        }
    }
    
    private static func toneFrequencyForCHIRP(_ tone: K5Tone) -> String {
        if case .ctcss(let freq) = tone {
            return String(format: "%.1f", freq)
        }
        return "88.5"
    }
    
    private static func dcsCodeForCHIRP(_ rxTone: K5Tone, _ txTone: K5Tone) -> String {
        if case .dcs(let code) = rxTone {
            return String(format: "%03d", code)
        }
        if case .dcs(let code) = txTone {
            return String(format: "%03d", code)
        }
        return "023"
    }
}

// MARK: - Структуры данных для экспорта

struct K5ChannelExport: Codable {
    let version: String
    let deviceModel: String
    let exportDate: Date
    let channels: [K5Channel]
}

// MARK: - Расширения для Codable

extension K5Channel: Codable {
    enum CodingKeys: String, CodingKey {
        case index, frequency, name, txPower, bandwidth, scrambler, rxTone, txTone
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        index = try container.decode(Int.self, forKey: .index)
        frequency = try container.decode(Double.self, forKey: .frequency)
        name = try container.decode(String.self, forKey: .name)
        txPower = try container.decode(Int.self, forKey: .txPower)
        bandwidth = try container.decode(K5Bandwidth.self, forKey: .bandwidth)
        scrambler = try container.decode(Bool.self, forKey: .scrambler)
        rxTone = try container.decode(K5Tone.self, forKey: .rxTone)
        txTone = try container.decode(K5Tone.self, forKey: .txTone)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(index, forKey: .index)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(name, forKey: .name)
        try container.encode(txPower, forKey: .txPower)
        try container.encode(bandwidth, forKey: .bandwidth)
        try container.encode(scrambler, forKey: .scrambler)
        try container.encode(rxTone, forKey: .rxTone)
        try container.encode(txTone, forKey: .txTone)
    }
}

extension K5Bandwidth: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "narrow":
            self = .narrow
        case "wide":
            self = .wide
        default:
            self = .narrow
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .narrow:
            try container.encode("narrow")
        case .wide:
            try container.encode("wide")
        }
    }
}

extension K5Tone: Codable {
    enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "none":
            self = .none
        case "ctcss":
            let freq = try container.decode(Double.self, forKey: .value)
            self = .ctcss(freq)
        case "dcs":
            let code = try container.decode(Int.self, forKey: .value)
            self = .dcs(code)
        default:
            self = .none
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .none:
            try container.encode("none", forKey: .type)
        case .ctcss(let freq):
            try container.encode("ctcss", forKey: .type)
            try container.encode(freq, forKey: .value)
        case .dcs(let code):
            try container.encode("dcs", forKey: .type)
            try container.encode(code, forKey: .value)
        }
    }
}

// MARK: - Ошибки

enum K5UtilitiesError: Error, LocalizedError {
    case invalidCSVFormat
    case invalidChannelData
    case fileNotFound
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidCSVFormat:
            return "Неверный формат CSV файла"
        case .invalidChannelData:
            return "Неверные данные канала"
        case .fileNotFound:
            return "Файл не найден"
        case .encodingError:
            return "Ошибка кодирования данных"
        }
    }
}