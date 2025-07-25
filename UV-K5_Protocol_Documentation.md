# Протокол Quansheng UV-K5

## Обзор

Quansheng UV-K5 использует специфичный протокол связи через USB-серийный порт. Этот документ описывает правильные команды и последовательности для работы с устройством.

## Основные характеристики

- **Скорость порта**: 38400 бод
- **Формат данных**: 8N1 (8 бит данных, без четности, 1 стоп-бит)
- **Управление потоком**: Нет
- **Magic bytes**: `AB CD EF AB CD EF AB CD` (используются в некоторых командах)

## Последовательность подключения

### 1. Тестирование связи
Перед выполнением handshake рекомендуется протестировать базовую связь:

```
Команды тестирования:
- Пустая команда: []
- Одиночный байт: [00]
- ACK: [06]
- Простое Hello: [48 65 6C 6C 6F] ("Hello")
- UV-K5 Magic: [AB CD EF AB]
- Запрос статуса: [05]
```

### 2. Handshake последовательность

#### Метод 1: Hello команда
```
Отправка: AB CD EF AB CD EF AB CD 14
Ожидаемый ответ: 18 05 ...
```

#### Метод 2: Вход в режим программирования
```
Отправка: AB CD EF AB CD EF AB CD 18 05 20 15 01 17 25 01
Ожидаемый ответ: 18 xx или 06 xx
```

#### Метод 3: Команда идентификации
```
Отправка: AB CD EF AB CD EF AB CD 05
Ожидаемый ответ: любые данные (не пустой ответ)
```

## Команды чтения данных

### Чтение EEPROM
```
Формат: AB CD EF AB CD EF AB CD 1B [адрес_low] [адрес_high] [длина]
Пример: AB CD EF AB CD EF AB CD 1B C0 1E 10
```

### Чтение памяти (альтернативный метод)
```
Формат: AB CD EF AB CD EF AB CD 1A [адрес_low] [адрес_high] [длина]
Пример: AB CD EF AB CD EF AB CD 1A C8 1E 02
```

### Простое чтение (без magic bytes)
```
Формат: 1B [адрес_low] [адрес_high] [длина]
Пример: 1B C8 1E 02
```

## Адреса памяти UV-K5

### Калибровочные данные
- **Калибровка батареи**: `0x1EC0` (16 байт)
- **Текущий вольтаж батареи**: `0x1EC8` (2 байта)
- **Калибровка RSSI**: `0x1F80`
- **Калибровка передатчика**: `0x1F40`
- **Калибровка приемника**: `0x1F60`

### Настройки и конфигурация
- **Информация об устройстве**: `0x0000`
- **Версия прошивки**: `0x2000`
- **Основные настройки**: `0x0E70`
- **Настройки меню**: `0x0F50`

### Каналы памяти
- **Начало каналов**: `0x0F30`
- **Размер канала**: 16 байт
- **Максимальное количество**: 200 каналов

## Чтение вольтажа батареи

### Команды для чтения вольтажа
1. **UV-K5 Battery ADC**: `AB CD EF AB CD EF AB CD 1B C8 1E 02`
2. **Прямое чтение**: `1B C8 1E 02`
3. **Статус устройства**: `AB CD EF AB CD EF AB CD 05`
4. **Альтернативное чтение**: `AB CD EF AB CD EF AB CD 1A C8 1E 04`

### Конвертация значений
UV-K5 использует 12-bit ADC с делителем напряжения:

```
Стандартный коэффициент: voltage = raw_value * 7.6 / 4096.0
Альтернативные коэффициенты:
- voltage = raw_value * 3.3 / 1024.0  (10-bit ADC)
- voltage = raw_value * 3.3 / 4096.0  (12-bit ADC)
- voltage = raw_value * 0.00806       (эмпирический)
- voltage = raw_value * 0.01611       (альтернативный)
```

Диапазон Li-ion батареи: 2.5V - 4.5V

## Обработка ошибок

### Типы ошибок
- `deviceNotConnected`: Устройство не подключено
- `communicationError`: Ошибка связи
- `invalidResponse`: Неверный ответ
- `checksumError`: Ошибка контрольной суммы
- `timeout`: Таймаут операции
- `unsupportedOperation`: Неподдерживаемая операция

### Стратегия повторных попыток
- Максимальное количество попыток: 3
- Задержка между попытками: 100ms, 200ms, 300ms
- Очистка буфера перед каждой попыткой
- Дополнительная пауза после отправки: 50ms

## Диагностика

### Проверка связи
1. Проверить подключение USB-порта
2. Проверить скорость порта (38400)
3. Выполнить тестовые команды
4. Проверить ответы устройства
5. Анализировать логи с детальной информацией

### Логирование
Используются эмодзи для лучшей читаемости:
- 🔄 Процесс выполнения
- ✅ Успешная операция
- ❌ Ошибка
- ⚠️ Предупреждение
- 🔧 Диагностическая информация
- 📡 Отправка команды
- 📥 Получение ответа
- 🧪 Тестирование

## Примеры использования

### Полная последовательность чтения вольтажа
```swift
// 1. Тестирование связи
let communicationWorks = try await testCommunication(interface: interface)

// 2. Handshake
try await performHandshake(interface: interface)

// 3. Чтение вольтажа
let voltage = try await readBatteryVoltage(interface: interface)
```

### Обработка ошибок
```swift
do {
    let voltage = try await readBatteryVoltage(interface: interface)
    print("Вольтаж: \(voltage)V")
} catch let error as K5ProtocolError {
    switch error {
    case .deviceNotConnected:
        print("Устройство не подключено")
    case .communicationError:
        print("Ошибка связи")
    // ... другие ошибки
    }
}
```

## Заключение

Этот протокол основан на реверс-инжиниринге и анализе сообщества UV-K5. Некоторые команды могут работать не на всех версиях прошивки. Рекомендуется всегда тестировать связь перед выполнением операций и использовать детальное логирование для диагностики проблем.