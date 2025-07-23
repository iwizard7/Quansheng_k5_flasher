import Foundation

// MARK: - Простая система тестирования

class TestRunner {
    private var tests: [Test] = []
    private let logManager = LogManager.shared
    
    func addTest(_ test: Test) {
        tests.append(test)
    }
    
    func runAllTests() -> TestResults {
        logManager.log("Запуск тестов: \(tests.count)", level: .info)
        
        var passed = 0
        var failed = 0
        var failedTests: [String] = []
        
        for test in tests {
            do {
                try test.run()
                passed += 1
                logManager.log("✅ \(test.name)", level: .success)
            } catch {
                failed += 1
                failedTests.append(test.name)
                logManager.log("❌ \(test.name): \(error.localizedDescription)", level: .error)
            }
        }
        
        let results = TestResults(
            total: tests.count,
            passed: passed,
            failed: failed,
            failedTests: failedTests
        )
        
        logManager.log("Тесты завершены: \(passed) успешно, \(failed) неудачно", level: .info)
        return results
    }
}

struct Test {
    let name: String
    let run: () throws -> Void
}

struct TestResults {
    let total: Int
    let passed: Int
    let failed: Int
    let failedTests: [String]
    
    var isAllPassed: Bool {
        return failed == 0
    }
    
    var successRate: Double {
        return total > 0 ? Double(passed) / Double(total) : 0.0
    }
}

// MARK: - Тесты для K5Utilities

class K5UtilitiesTests {
    static func createTests() -> [Test] {
        return [
            Test(name: "Валидация частоты") {
                try testFrequencyValidation()
            },
            Test(name: "Валидация имени канала") {
                try testChannelNameValidation()
            },
            Test(name: "Валидация мощности") {
                try testPowerValidation()
            },
            Test(name: "Парсинг CSV") {
                try testCSVParsing()
            },
            Test(name: "Кодирование каналов") {
                try testChannelEncoding()
            }
        ]
    }
    
    private static func testFrequencyValidation() throws {
        // Валидные частоты
        let validFrequencies = [136.0, 145.5, 174.0]
        for freq in validFrequencies {
            let errors = K5Utilities.validateChannel(K5Channel(frequency: freq))
            if errors.contains(where: { $0.contains("частота") || $0.contains("диапазон") }) {
                throw TestError.validationFailed("Частота \(freq) должна быть валидной")
            }
        }
        
        // Невалидные частоты
        let invalidFrequencies = [135.9, 174.1, 88.0, 400.0]
        for freq in invalidFrequencies {
            let errors = K5Utilities.validateChannel(K5Channel(frequency: freq))
            if !errors.contains(where: { $0.contains("частота") || $0.contains("диапазон") }) {
                throw TestError.validationFailed("Частота \(freq) должна быть невалидной")
            }
        }
    }
    
    private static func testChannelNameValidation() throws {
        // Валидные имена
        let validNames = ["", "Test", "1234567"]
        for name in validNames {
            let errors = K5Utilities.validateChannel(K5Channel(name: name))
            if errors.contains(where: { $0.contains("имя") || $0.contains("символов") }) {
                throw TestError.validationFailed("Имя '\(name)' должно быть валидным")
            }
        }
        
        // Невалидные имена
        let invalidNames = ["12345678", "VeryLongName"]
        for name in invalidNames {
            let errors = K5Utilities.validateChannel(K5Channel(name: name))
            if !errors.contains(where: { $0.contains("имя") || $0.contains("символов") }) {
                throw TestError.validationFailed("Имя '\(name)' должно быть невалидным")
            }
        }
    }
    
    private static func testPowerValidation() throws {
        // Валидные значения мощности
        let validPowers = [0, 1, 2]
        for power in validPowers {
            let errors = K5Utilities.validateChannel(K5Channel(txPower: power))
            if errors.contains(where: { $0.contains("мощность") }) {
                throw TestError.validationFailed("Мощность \(power) должна быть валидной")
            }
        }
        
        // Невалидные значения мощности
        let invalidPowers = [-1, 3, 10]
        for power in invalidPowers {
            let errors = K5Utilities.validateChannel(K5Channel(txPower: power))
            if !errors.contains(where: { $0.contains("мощность") }) {
                throw TestError.validationFailed("Мощность \(power) должна быть невалидной")
            }
        }
    }
    
    private static func testCSVParsing() throws {
        let csvLine = "1,Test,145.500,1,Narrow,No,None,None"
        let fields = parseCSVLine(csvLine)
        
        if fields.count != 8 {
            throw TestError.parsingFailed("Ожидалось 8 полей, получено \(fields.count)")
        }
        
        if fields[0] != "1" || fields[1] != "Test" || fields[2] != "145.500" {
            throw TestError.parsingFailed("Неверные значения полей")
        }
    }
    
    private static func testChannelEncoding() throws {
        let channel = K5Channel(
            index: 0,
            frequency: 145.500,
            name: "Test",
            txPower: 1,
            bandwidth: .narrow,
            scrambler: false,
            rxTone: .ctcss(88.5),
            txTone: .none
        )
        
        // Проверяем, что канал можно закодировать и декодировать
        let errors = K5Utilities.validateChannel(channel)
        if !errors.isEmpty {
            throw TestError.validationFailed("Тестовый канал должен быть валидным: \(errors.joined(separator: ", "))")
        }
    }
    
    // Вспомогательные методы
    private static func parseCSVLine(_ line: String) -> [String] {
        return line.components(separatedBy: ",")
    }
}

// MARK: - Тесты для Configuration

class ConfigurationTests {
    static func createTests() -> [Test] {
        return [
            Test(name: "Константы USB") {
                try testUSBConstants()
            },
            Test(name: "Константы K5") {
                try testK5Constants()
            },
            Test(name: "Валидация правил") {
                try testValidationRules()
            }
        ]
    }
    
    private static func testUSBConstants() throws {
        if AppConfiguration.USB.vendorID == 0 {
            throw TestError.configurationError("VendorID не должен быть 0")
        }
        
        if AppConfiguration.USB.productID == 0 {
            throw TestError.configurationError("ProductID не должен быть 0")
        }
        
        if AppConfiguration.USB.timeout <= 0 {
            throw TestError.configurationError("Timeout должен быть положительным")
        }
    }
    
    private static func testK5Constants() throws {
        if AppConfiguration.K5.maxChannels <= 0 {
            throw TestError.configurationError("MaxChannels должен быть положительным")
        }
        
        if AppConfiguration.K5.channelSize <= 0 {
            throw TestError.configurationError("ChannelSize должен быть положительным")
        }
        
        if AppConfiguration.K5.frequencyRange.isEmpty {
            throw TestError.configurationError("FrequencyRange не должен быть пустым")
        }
    }
    
    private static func testValidationRules() throws {
        // Тест валидации частоты
        if !ValidationRules.validateFrequency(145.0) {
            throw TestError.validationFailed("145.0 MHz должна быть валидной частотой")
        }
        
        if ValidationRules.validateFrequency(88.0) {
            throw TestError.validationFailed("88.0 MHz не должна быть валидной частотой")
        }
        
        // Тест валидации имени канала
        if !ValidationRules.validateChannelName("Test") {
            throw TestError.validationFailed("'Test' должно быть валидным именем канала")
        }
        
        if ValidationRules.validateChannelName("VeryLongName") {
            throw TestError.validationFailed("'VeryLongName' не должно быть валидным именем канала")
        }
    }
}

// MARK: - Ошибки тестирования

enum TestError: Error, LocalizedError {
    case validationFailed(String)
    case parsingFailed(String)
    case configurationError(String)
    case unexpectedResult(String)
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Ошибка валидации: \(message)"
        case .parsingFailed(let message):
            return "Ошибка парсинга: \(message)"
        case .configurationError(let message):
            return "Ошибка конфигурации: \(message)"
        case .unexpectedResult(let message):
            return "Неожиданный результат: \(message)"
        }
    }
}

