#!/bin/bash

# Скрипт для запуска QuanshengK5Tool
echo "Запуск QuanshengK5Tool..."

# Проверяем, существует ли приложение
if [ -d "QuanshengK5Tool.app" ]; then
    echo "Найдено приложение QuanshengK5Tool.app"
    open QuanshengK5Tool.app
else
    echo "Ошибка: QuanshengK5Tool.app не найдено!"
    echo "Убедитесь, что вы находитесь в правильной директории."
    exit 1
fi