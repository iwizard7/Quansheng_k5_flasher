#!/bin/bash

echo "=== Проверка доступных USB-портов ==="
echo

echo "Поиск USB-serial портов в /dev:"
ls -la /dev/ | grep -E "(tty\.usb|cu\.usb|tty\.SLAB|cu\.SLAB)" | head -10

echo
echo "Поиск всех tty устройств:"
ls -la /dev/tty* | grep usb | head -5

echo
echo "Поиск всех cu устройств:"
ls -la /dev/cu* | grep usb | head -5

echo
echo "Информация о USB устройствах:"
system_profiler SPUSBDataType | grep -A 5 -B 5 -i "serial\|ftdi\|cp210\|ch340\|prolific" | head -20

echo
echo "=== Конец проверки ==="