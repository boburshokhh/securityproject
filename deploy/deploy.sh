#!/bin/bash
# Скрипт деплоя MyGov Backend на Ubuntu сервер

set -e  # Остановка при ошибке

echo "=========================================="
echo "  MyGov Backend - Деплой на Ubuntu"
echo "=========================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Переменные
PROJECT_DIR="/var/www/my-gov-backend"
SERVICE_NAME="mygov-backend"
LOG_DIR="/var/log/mygov-backend"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Ошибка: Запустите скрипт с правами root (sudo)${NC}"
    exit 1
fi

echo -e "${GREEN}[1/8] Создание директорий...${NC}"
mkdir -p "$PROJECT_DIR"
mkdir -p "$PROJECT_DIR/uploads/documents"
mkdir -p "$PROJECT_DIR/templates"
mkdir -p "$LOG_DIR"
mkdir -p /var/www/.cache/dconf
mkdir -p /var/www/.config
mkdir -p /var/www/.local/share
chown -R www-data:www-data "$PROJECT_DIR"
chown -R www-data:www-data "$LOG_DIR"
chown -R www-data:www-data /var/www/.cache
chown -R www-data:www-data /var/www/.config
chown -R www-data:www-data /var/www/.local
chmod -R 755 "$PROJECT_DIR"
chmod -R 775 "$PROJECT_DIR/uploads"
chmod 1777 /tmp
chmod 1777 /var/tmp

echo -e "${GREEN}[2/8] Копирование файлов проекта...${NC}"
# Копируем все файлы кроме venv, __pycache__, .env
rsync -av --exclude='venv' --exclude='__pycache__' --exclude='.env' --exclude='*.pyc' \
    --exclude='uploads' --exclude='.git' \
    ./ "$PROJECT_DIR/"

echo -e "${GREEN}[3/8] Создание виртуального окружения...${NC}"
cd "$PROJECT_DIR"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

echo -e "${GREEN}[4/8] Установка зависимостей...${NC}"
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo -e "${YELLOW}[5/8] Настройка .env файла...${NC}"
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "Создайте файл .env в $PROJECT_DIR"
    echo "Пример содержимого:"
    echo "DB_HOST=45.138.159.141"
    echo "DB_PORT=5432"
    echo "DB_NAME=dmed"
    echo "DB_USER=dmed_app"
    echo "DB_PASSWORD=your_password_here"
    echo "SECRET_KEY=$(openssl rand -hex 32)"
    echo "DEBUG=False"
    echo "PORT=5001"
    echo "MINIO_ENDPOINT=localhost:9000"
    echo "MINIO_ACCESS_KEY=minioadmin"
    echo "MINIO_SECRET_KEY=minioadmin"
    echo "MINIO_BUCKET_NAME=mygov-documents"
    echo "FRONTEND_URL=https://mygov.dmed.uz"
    echo ""
    read -p "Нажмите Enter после создания .env файла..."
fi

echo -e "${GREEN}[6/8] Установка systemd сервиса...${NC}"

# Определяем модуль приложения
if [ -f "$PROJECT_DIR/run.py" ]; then
    APP_MODULE="run:app"
    BIND_ADDRESS="0.0.0.0:8000"
else
    APP_MODULE="app:app"
    BIND_ADDRESS="127.0.0.1:5001"
fi

# Обновляем systemd файл с правильными настройками
tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << EOF
[Unit]
Description=MyGov Backend Gunicorn Application Server
After=network.target postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=$PROJECT_DIR
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PROJECT_DIR/venv/bin"
Environment="HOME=/var/www"
Environment="TMPDIR=/tmp"
Environment="TMP=/tmp"
Environment="TEMP=/tmp"
Environment="XDG_CACHE_HOME=/var/www/.cache"
Environment="XDG_CONFIG_HOME=/var/www/.config"
Environment="XDG_DATA_HOME=/var/www/.local/share"
ExecStart=$PROJECT_DIR/venv/bin/gunicorn \\
    --workers 4 \\
    --bind $BIND_ADDRESS \\
    --timeout 300 \\
    --access-logfile $LOG_DIR/access.log \\
    --error-logfile $LOG_DIR/error.log \\
    --log-level info \\
    --capture-output \\
    --enable-stdio-inheritance \\
    --chdir $PROJECT_DIR \\
    $APP_MODULE

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $SERVICE_NAME.service

echo -e "${GREEN}[7/8] Установка прав доступа...${NC}"
chown -R www-data:www-data "$PROJECT_DIR"
chmod +x "$PROJECT_DIR/run.py"

echo -e "${GREEN}[8/8] Запуск сервиса...${NC}"
systemctl restart $SERVICE_NAME.service
systemctl status $SERVICE_NAME.service --no-pager

echo ""
echo -e "${GREEN}=========================================="
echo "  Деплой завершен успешно!"
echo "==========================================${NC}"
echo ""
echo "Полезные команды:"
echo "  Проверить статус:  sudo systemctl status $SERVICE_NAME"
echo "  Посмотреть логи:   sudo journalctl -u $SERVICE_NAME -f"
echo "  Перезапустить:     sudo systemctl restart $SERVICE_NAME"
echo "  Остановить:        sudo systemctl stop $SERVICE_NAME"
echo ""
echo "API доступен на: http://localhost:5001/api"
echo "Health check:    http://localhost:5001/health"
echo ""

