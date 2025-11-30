#!/bin/bash
# Скрипт для исправления проблем с LibreOffice

echo "=========================================="
echo "  Исправление проблем с LibreOffice"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"
SERVICE_USER="www-data"

echo ""
echo "1. Установка LibreOffice (если не установлен)..."
if ! command -v libreoffice &> /dev/null; then
    echo "Установка LibreOffice..."
    sudo apt-get update
    sudo apt-get install -y libreoffice
else
    echo "✓ LibreOffice уже установлен"
fi

echo ""
echo "2. Установка необходимых зависимостей..."
sudo apt-get install -y \
    libreoffice \
    libreoffice-writer \
    libreoffice-core \
    fonts-liberation \
    fonts-dejavu \
    libcairo2 \
    libx11-6 \
    libxext6 \
    libxrender1

echo ""
echo "3. Проверка и создание HOME директории для www-data..."
if [ ! -d "/var/www" ]; then
    sudo mkdir -p /var/www
fi

# Создаем .config директорию для LibreOffice
sudo -u $SERVICE_USER mkdir -p /var/www/.config
sudo chown -R $SERVICE_USER:$SERVICE_USER /var/www/.config

echo ""
echo "4. Установка прав на временные директории..."
sudo chmod 1777 /tmp
sudo chmod 1777 /var/tmp

echo ""
echo "5. Проверка прав на директорию проекта..."
sudo chown -R $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR"
sudo chmod -R 755 "$PROJECT_DIR"
sudo chmod -R 775 "$PROJECT_DIR/uploads"

echo ""
echo "6. Тест запуска LibreOffice от www-data..."
sudo -u $SERVICE_USER libreoffice --headless --version 2>&1
if [ $? -eq 0 ]; then
    echo "✓ LibreOffice работает от www-data"
else
    echo "✗ Проблемы с запуском LibreOffice от www-data"
    echo "  Попробуйте установить переменные окружения:"
    echo "  export HOME=/var/www"
    echo "  в systemd сервисе"
fi

echo ""
echo "7. Проверка systemd сервиса..."
if [ -f "/etc/systemd/system/mygov-backend.service" ]; then
    echo "Текущая конфигурация:"
    grep -E "Environment|ExecStart" /etc/systemd/system/mygov-backend.service
    
    echo ""
    echo "Если нужно добавить переменные окружения, отредактируйте:"
    echo "  sudo nano /etc/systemd/system/mygov-backend.service"
    echo ""
    echo "Добавьте после [Service]:"
    echo "  Environment=\"HOME=/var/www\""
    echo "  Environment=\"TMPDIR=/tmp\""
    echo ""
    echo "Затем выполните:"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl restart mygov-backend"
fi

echo ""
echo "=========================================="
echo "  Готово!"
echo "=========================================="


