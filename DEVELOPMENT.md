# Руководство по разработке Quansheng K5 Tool

## 🚀 Быстрый старт

### Требования
- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Swift 5.0+
- Git

### Установка
```bash
git clone https://github.com/iwizard7/Quansheng_k5_flasher
cd Quansheng_k5_flasher
./build_and_test.sh build
```

## 🏗️ Архитектура

### Паттерны проектирования
- **MVVM**: Model-View-ViewModel для разделения логики
- **ObservableObject**: Реактивное программирование с SwiftUI
- **Dependency Injection**: Внедрение зависимостей через инициализаторы
- **Strategy Pattern**: Различные стратегии для работы с файлами

### Структура кода
```
QuanshengK5Tool/
├── App/                    # Конфигурация приложения
├── Views/                  # SwiftUI представления
├── Models/                 # Модели данных
├── Managers/              # Бизнес-логика
├── Protocols/             # Протоколы и интерфейсы
├── Extensions/            # Расширения
├── Utils/                 # Утилиты
└── Resources/             # Ресурсы
```

## 📝 Стандарты кодирования

### Swift Style Guide
Следуем [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

#### Именование
```swift
// ✅ Хорошо
func connectToDevice(port: SerialPort) async -> Bool
var isConnected: Bool
let maxRetryCount = 3

// ❌ Плохо
func connect_to_device(p: SerialPort) async -> Bool
var connected: Bool
let MAX_RETRY_COUNT = 3
```

#### Структура файлов
```swift
import Foundation
import SwiftUI

// MARK: - Main Class/Struct

class ExampleManager: ObservableObject {
    // MARK: - Properties
    @Published var isLoading = false
    private let configuration: Configuration
    
    // MARK: - Initialization
    init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    func performAction() async {
        // Implementation
    }
    
    // MARK: - Private Methods
    private func helperMethod() {
        // Implementation
    }
}

// MARK: - Extensions

extension ExampleManager {
    // Additional functionality
}
```

### Комментарии и документация
```swift
/// Управляет подключением к устройству Quansheng K5
/// 
/// Этот класс обеспечивает:
/// - Обнаружение USB устройств
/// - Установку соединения
/// - Обмен данными по протоколу K5
class USBCommunicationManager: ObservableObject {
    
    /// Подключается к указанному порту
    /// - Parameter port: Серийный порт для подключения
    /// - Returns: `true` если подключение успешно
    func connectToK5(port: SerialPort) async -> Bool {
        // Implementation
    }
}
```

## 🧪 Тестирование

### Запуск тестов
```bash
./build_and_test.sh test
```

### Написание тестов
```swift
// Добавление нового теста
let test = Test(name: "Тест валидации частоты") {
    let channel = K5Channel(frequency: 145.0)
    let errors = K5Utilities.validateChannel(channel)
    
    if !errors.isEmpty {
        throw TestError.validationFailed("Частота должна быть валидной")
    }
}

testRunner.addTest(test)
```

### Покрытие тестами
- [ ] USBCommunicationManager
- [x] K5Utilities (частично)
- [x] Configuration
- [ ] CalibrationManager
- [ ] LogManager

## 🔧 Отладка

### Логирование
```swift
// Использование LogManager
logManager.log("Подключение к устройству", level: .info)
logManager.log("Ошибка чтения данных", level: .error)
logManager.log("Операция завершена успешно", level: .success)
```

### Отладка USB коммуникации
```bash
# Мониторинг USB событий
log stream --predicate 'subsystem == "com.apple.iokit.usb"'

# Отладка серийных портов
ls -la /dev/cu.*
ls -la /dev/tty.*
```

### Профилирование
- Используйте Instruments для анализа производительности
- Мониторьте использование памяти при работе с большими файлами
- Проверяйте утечки памяти в USB коммуникации

## 📦 Сборка и развертывание

### Локальная сборка
```bash
# Полная сборка
./build_and_test.sh all

# Только сборка
./build_and_test.sh build

# Создание DMG
./build_and_test.sh dmg
```

### Конфигурации сборки
- **Debug**: Для разработки, включает отладочную информацию
- **Release**: Для распространения, оптимизированная версия

### Подписание кода
```bash
# Подписание приложения
codesign --force --deep --sign "Developer ID Application: Your Name" QuanshengK5Tool.app

# Проверка подписи
codesign -v QuanshengK5Tool.app
```

## 🔒 Безопасность

### Права доступа (Entitlements)
```xml
<key>com.apple.security.device.usb</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.app-sandbox</key>
<true/>
```

### Валидация данных
- Всегда валидируйте входные данные
- Проверяйте размеры файлов перед загрузкой
- Используйте безопасные методы парсинга

## 🐛 Отладка проблем

### Частые проблемы

#### Устройство не обнаруживается
1. Проверьте USB кабель
2. Убедитесь, что устройство в режиме программирования
3. Проверьте права доступа к USB

#### Ошибки компиляции
1. Очистите проект: `./build_and_test.sh clean`
2. Проверьте версию Xcode
3. Обновите зависимости

#### Проблемы с производительностью
1. Используйте Instruments для профилирования
2. Проверьте утечки памяти
3. Оптимизируйте работу с UI в главном потоке

## 📚 Ресурсы

### Документация
- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Quansheng K5 Protocol](K5_Protocol_Documentation.md)

### Инструменты
- [SwiftLint](https://github.com/realm/SwiftLint) - Линтер для Swift
- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) - Форматирование кода
- [Instruments](https://developer.apple.com/xcode/features/) - Профилирование

## 🤝 Вклад в проект

### Процесс разработки
1. Создайте ветку для новой функции
2. Напишите код следуя стандартам
3. Добавьте тесты
4. Обновите документацию
5. Создайте Pull Request

### Код ревью
- Проверьте соответствие стандартам кодирования
- Убедитесь в наличии тестов
- Проверьте производительность
- Обновите документацию при необходимости

## 📋 TODO

### Высокий приоритет
- [ ] Реализация реального USB протокола
- [ ] Добавление unit тестов
- [ ] Улучшение обработки ошибок

### Средний приоритет
- [ ] Поддержка других моделей Quansheng
- [ ] Автоматическое обновление прошивки
- [ ] Экспорт в формат CHIRP

### Низкий приоритет
- [ ] Темная тема
- [ ] Локализация на другие языки
- [ ] Плагины для расширения функциональности