#!/bin/bash
# Полная настройка mygov-backend как dmed для Ubuntu сервера
# Этот скрипт настраивает все необходимое для работы генерации документов

set -e  # Остановка при ошибке

echo "=========================================="
echo "  Настройка MyGov Backend как dmed"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"
SERVICE_NAME="mygov-backend"
SERVICE_USER="www-data"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo ""
echo -e "${GREEN}[1/10] Установка системных зависимостей...${NC}"

# Обновление пакетов
sudo apt-get update -qq

# Установка LibreOffice и зависимостей
echo "Установка LibreOffice..."
sudo apt-get install -y \
    libreoffice \
    libreoffice-writer \
    libreoffice-core \
    fonts-liberation \
    fonts-dejavu \
    libcairo2 \
    libx11-6 \
    libxext6 \
    libxrender1 \
    python3-pip \
    python3-venv \
    postgresql-client

echo -e "${GREEN}✓ Зависимости установлены${NC}"

echo ""
echo -e "${GREEN}[2/10] Создание директорий...${NC}"

# Создание директорий
sudo mkdir -p "$PROJECT_DIR"
sudo mkdir -p "$PROJECT_DIR/uploads/documents"
sudo mkdir -p "$PROJECT_DIR/templates"
sudo mkdir -p /var/log/mygov-backend
sudo mkdir -p /var/www/.cache/dconf
sudo mkdir -p /var/www/.config
sudo mkdir -p /var/www/.local/share

echo -e "${GREEN}✓ Директории созданы${NC}"

echo ""
echo -e "${GREEN}[3/10] Установка прав доступа...${NC}"

# Установка прав
sudo chown -R $SERVICE_USER:$SERVICE_USER "$PROJECT_DIR"
sudo chown -R $SERVICE_USER:$SERVICE_USER /var/log/mygov-backend
sudo chown -R $SERVICE_USER:$SERVICE_USER /var/www/.cache
sudo chown -R $SERVICE_USER:$SERVICE_USER /var/www/.config
sudo chown -R $SERVICE_USER:$SERVICE_USER /var/www/.local

# Права на директории
sudo chmod -R 755 "$PROJECT_DIR"
sudo chmod -R 775 "$PROJECT_DIR/uploads"
sudo chmod -R 755 /var/log/mygov-backend
sudo chmod -R 755 /var/www/.cache
sudo chmod -R 755 /var/www/.config
sudo chmod -R 755 /var/www/.local

# Права на временные директории
sudo chmod 1777 /tmp
sudo chmod 1777 /var/tmp

echo -e "${GREEN}✓ Права установлены${NC}"

echo ""
echo -e "${GREEN}[4/10] Проверка виртуального окружения...${NC}"

if [ ! -d "$PROJECT_DIR/venv" ]; then
    echo "Создание виртуального окружения..."
    cd "$PROJECT_DIR"
    sudo -u $SERVICE_USER python3 -m venv venv
    echo -e "${GREEN}✓ Виртуальное окружение создано${NC}"
else
    echo -e "${GREEN}✓ Виртуальное окружение существует${NC}"
fi

echo ""
echo -e "${GREEN}[5/10] Установка Python зависимостей...${NC}"

cd "$PROJECT_DIR"
sudo -u $SERVICE_USER "$PROJECT_DIR/venv/bin/pip" install --upgrade pip --quiet
sudo -u $SERVICE_USER "$PROJECT_DIR/venv/bin/pip" install -r requirements.txt --quiet

echo -e "${GREEN}✓ Зависимости установлены${NC}"

echo ""
echo -e "${YELLOW}[6/10] Проверка .env файла...${NC}"

if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo -e "${YELLOW}⚠ .env файл не найден${NC}"
    echo "Создайте файл .env с настройками:"
    echo ""
    echo "DB_HOST=45.138.159.141"
    echo "DB_PORT=5432"
    echo "DB_NAME=dmed"
    echo "DB_USER=dmed_app"
    echo "DB_PASSWORD=your_password_here"
    echo "DB_SSLMODE=prefer"
    echo "SECRET_KEY=$(openssl rand -hex 32)"
    echo "DEBUG=False"
    echo "PORT=5001"
    echo "MINIO_ENABLED=True"
    echo "MINIO_ENDPOINT=minio.dmed.gubkin.uz"
    echo "MINIO_ACCESS_KEY=your_access_key"
    echo "MINIO_SECRET_KEY=your_secret_key"
    echo "MINIO_SECURE=True"
    echo "MINIO_BUCKET_NAME=dmed"
    echo "FRONTEND_URL=https://repositorymygov.netlify.app"
    echo "JWT_EXPIRATION_HOURS=24"
    echo ""
    read -p "Нажмите Enter после создания .env файла..."
else
    echo -e "${GREEN}✓ .env файл существует${NC}"
fi

echo ""
echo -e "${GREEN}[7/10] Создание systemd сервиса...${NC}"

# Определяем, какой модуль использовать (run:app или app:app)
if [ -f "$PROJECT_DIR/run.py" ]; then
    APP_MODULE="run:app"
    BIND_ADDRESS="0.0.0.0:8000"
    echo "Используется run:app на порту 8000"
else
    APP_MODULE="app:app"
    BIND_ADDRESS="127.0.0.1:5001"
    echo "Используется app:app на порту 5001"
fi

# Создание systemd файла
sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null << EOF
[Unit]
Description=MyGov Backend Gunicorn Application Server
After=network.target postgresql.service

[Service]
User=$SERVICE_USER
Group=$SERVICE_USER
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
    --access-logfile /var/log/mygov-backend/access.log \\
    --error-logfile /var/log/mygov-backend/error.log \\
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

echo -e "${GREEN}✓ Systemd сервис создан${NC}"

echo ""
echo -e "${GREEN}[8/10] Перезагрузка systemd...${NC}"

sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME.service

echo -e "${GREEN}✓ Systemd перезагружен${NC}"

echo ""
echo -e "${GREEN}[9/10] Проверка LibreOffice...${NC}"

# Проверка LibreOffice
if command -v libreoffice &> /dev/null; then
    echo "✓ LibreOffice установлен: $(which libreoffice)"
    libreoffice --version | head -1
    
    # Тест от www-data
    echo "Тест запуска от www-data..."
    if sudo -u $SERVICE_USER libreoffice --headless --version &> /dev/null; then
        echo -e "${GREEN}✓ LibreOffice работает от www-data${NC}"
    else
        echo -e "${YELLOW}⚠ Предупреждение: LibreOffice может иметь проблемы от www-data${NC}"
    fi
else
    echo -e "${RED}✗ LibreOffice не найден${NC}"
fi

echo ""
echo -e "${GREEN}[10/10] Запуск сервиса...${NC}"

sudo systemctl restart $SERVICE_NAME.service
sleep 3

# Проверка статуса
if sudo systemctl is-active --quiet $SERVICE_NAME.service; then
    echo -e "${GREEN}✓ Сервис запущен успешно${NC}"
else
    echo -e "${RED}✗ Ошибка запуска сервиса${NC}"
    sudo systemctl status $SERVICE_NAME.service --no-pager -l | head -20
    exit 1
fi

echo ""
echo -e "${GREEN}=========================================="
echo "  Настройка завершена!"
echo "==========================================${NC}"
echo ""
echo "Проверка статуса:"
sudo systemctl status $SERVICE_NAME.service --no-pager -l | head -15

echo ""
echo "Полезные команды:"
echo "  Статус:     sudo systemctl status $SERVICE_NAME"
echo "  Логи:       sudo journalctl -u $SERVICE_NAME -f"
echo "  Логи файлы: tail -f /var/log/mygov-backend/error.log"
echo "  Перезапуск: sudo systemctl restart $SERVICE_NAME"
echo ""
echo "Тестирование:"
echo "  cd $PROJECT_DIR"
echo "  source venv/bin/activate"
echo "  python3 test_generate.py"
echo ""

