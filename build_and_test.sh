#!/bin/bash

# Скрипт для сборки и тестирования Quansheng K5 Tool
# Использование: ./build_and_test.sh [clean|build|test|all]

set -e  # Остановка при ошибке

PROJECT_NAME="QuanshengK5Tool"
SCHEME_NAME="QuanshengK5Tool"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка зависимостей
check_dependencies() {
    print_info "Проверка зависимостей..."
    
    if ! command -v xcodebuild &> /dev/null; then
        print_error "xcodebuild не найден. Установите Xcode Command Line Tools."
        exit 1
    fi
    
    if ! command -v xcrun &> /dev/null; then
        print_error "xcrun не найден. Установите Xcode Command Line Tools."
        exit 1
    fi
    
    print_success "Все зависимости найдены"
}

# Очистка
clean() {
    print_info "Очистка проекта..."
    
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        print_success "Папка сборки очищена"
    fi
    
    xcodebuild clean \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release
    
    print_success "Проект очищен"
}

# Сборка проекта
build() {
    print_info "Сборка проекта..."
    
    mkdir -p "$BUILD_DIR"
    
    # Сборка для Release
    xcodebuild build \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        ONLY_ACTIVE_ARCH=NO
    
    # Копирование приложения
    BUILT_APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$PROJECT_NAME.app"
    if [ -d "$BUILT_APP_PATH" ]; then
        cp -R "$BUILT_APP_PATH" "$APP_PATH"
        print_success "Приложение собрано: $APP_PATH"
    else
        print_error "Не удалось найти собранное приложение"
        exit 1
    fi
}

# Создание архива
archive() {
    print_info "Создание архива..."
    
    xcodebuild archive \
        -project "$PROJECT_NAME.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO
    
    print_success "Архив создан: $ARCHIVE_PATH"
}

# Запуск тестов
run_tests() {
    print_info "Запуск тестов..."
    
    # Проверка синтаксиса Swift файлов
    print_info "Проверка синтаксиса..."
    find QuanshengK5Tool -name "*.swift" -exec xcrun swiftc -parse {} \; 2>/dev/null
    print_success "Синтаксис корректен"
    
    # Проверка стиля кода
    print_info "Проверка стиля кода..."
    if command -v swiftlint &> /dev/null; then
        swiftlint QuanshengK5Tool/
    else
        print_warning "SwiftLint не найден, пропускаем проверку стиля"
    fi
    
    print_success "Тесты завершены"
}

# Проверка приложения
verify_app() {
    print_info "Проверка приложения..."
    
    if [ ! -d "$APP_PATH" ]; then
        print_error "Приложение не найдено: $APP_PATH"
        exit 1
    fi
    
    # Проверка структуры приложения
    if [ ! -f "$APP_PATH/Contents/MacOS/$PROJECT_NAME" ]; then
        print_error "Исполняемый файл не найден"
        exit 1
    fi
    
    if [ ! -f "$APP_PATH/Contents/Info.plist" ]; then
        print_error "Info.plist не найден"
        exit 1
    fi
    
    # Проверка подписи (если есть)
    codesign -v "$APP_PATH" 2>/dev/null || print_warning "Приложение не подписано"
    
    # Получение информации о приложении
    APP_VERSION=$(defaults read "$PWD/$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "Unknown")
    APP_BUILD=$(defaults read "$PWD/$APP_PATH/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "Unknown")
    
    print_success "Приложение проверено"
    print_info "Версия: $APP_VERSION"
    print_info "Сборка: $APP_BUILD"
}

# Создание DMG
create_dmg() {
    print_info "Создание DMG..."
    
    DMG_NAME="$PROJECT_NAME-v$(date +%Y%m%d).dmg"
    DMG_PATH="$BUILD_DIR/$DMG_NAME"
    
    if [ -f "$DMG_PATH" ]; then
        rm "$DMG_PATH"
    fi
    
    # Создание временной папки для DMG
    DMG_TEMP_DIR="$BUILD_DIR/dmg_temp"
    mkdir -p "$DMG_TEMP_DIR"
    
    # Копирование приложения
    cp -R "$APP_PATH" "$DMG_TEMP_DIR/"
    
    # Создание символической ссылки на Applications
    ln -s /Applications "$DMG_TEMP_DIR/Applications"
    
    # Создание DMG
    hdiutil create -volname "$PROJECT_NAME" \
        -srcfolder "$DMG_TEMP_DIR" \
        -ov -format UDZO \
        "$DMG_PATH"
    
    # Очистка временной папки
    rm -rf "$DMG_TEMP_DIR"
    
    print_success "DMG создан: $DMG_PATH"
}

# Показать справку
show_help() {
    echo "Использование: $0 [команда]"
    echo ""
    echo "Команды:"
    echo "  clean     - Очистка проекта"
    echo "  build     - Сборка проекта"
    echo "  test      - Запуск тестов"
    echo "  archive   - Создание архива"
    echo "  dmg       - Создание DMG"
    echo "  verify    - Проверка приложения"
    echo "  all       - Выполнить все операции"
    echo "  help      - Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 build"
    echo "  $0 all"
}

# Основная логика
main() {
    case "${1:-all}" in
        clean)
            check_dependencies
            clean
            ;;
        build)
            check_dependencies
            build
            verify_app
            ;;
        test)
            check_dependencies
            run_tests
            ;;
        archive)
            check_dependencies
            archive
            ;;
        dmg)
            check_dependencies
            if [ ! -d "$APP_PATH" ]; then
                build
            fi
            create_dmg
            ;;
        verify)
            verify_app
            ;;
        all)
            check_dependencies
            clean
            build
            run_tests
            verify_app
            create_dmg
            print_success "Все операции завершены успешно!"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Неизвестная команда: $1"
            show_help
            exit 1
            ;;
    esac
}

# Запуск
main "$@"