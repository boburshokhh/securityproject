#!/bin/bash
# Скрипт для обновления systemd сервиса с правильными настройками

echo "=========================================="
echo "  Обновление systemd сервиса"
echo "=========================================="

SERVICE_FILE="/etc/systemd/system/mygov-backend.service"
PROJECT_DIR="/var/www/mygov-backend"
BACKUP_FILE="/etc/systemd/system/mygov-backend.service.backup.$(date +%Y%m%d_%H%M%S)"

echo ""
echo "1. Создание резервной копии текущего файла..."
if [ -f "$SERVICE_FILE" ]; then
    sudo cp "$SERVICE_FILE" "$BACKUP_FILE"
    echo "✓ Резервная копия создана: $BACKUP_FILE"
else
    echo "⚠ Файл не найден, будет создан новый"
fi

echo ""
echo "2. Проверка текущего файла..."
if [ -f "$SERVICE_FILE" ]; then
    echo "Текущий ExecStart:"
    grep "ExecStart" "$SERVICE_FILE"
    echo ""
    echo "Текущие Environment:"
    grep "Environment" "$SERVICE_FILE" || echo "  Нет переменных окружения"
fi

echo ""
echo "3. Создание нового файла сервиса..."

sudo tee "$SERVICE_FILE" > /dev/null << 'EOF'
[Unit]
Description=MyGov Backend Gunicorn Application Server
After=network.target postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/mygov-backend
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/var/www/mygov-backend/venv/bin"
Environment="HOME=/var/www"
Environment="TMPDIR=/tmp"
Environment="TMP=/tmp"
Environment="TEMP=/tmp"
Environment="XDG_CACHE_HOME=/var/www/.cache"
Environment="XDG_CONFIG_HOME=/var/www/.config"
Environment="XDG_DATA_HOME=/var/www/.local/share"
ExecStart=/var/www/mygov-backend/venv/bin/gunicorn \
    --workers 4 \
    --bind 0.0.0.0:8000 \
    --timeout 300 \
    --access-logfile /var/log/mygov-backend/access.log \
    --error-logfile /var/log/mygov-backend/error.log \
    --log-level info \
    --capture-output \
    --enable-stdio-inheritance \
    --chdir /var/www/mygov-backend \
    run:app

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Новый файл создан"

echo ""
echo "4. Создание директорий для логов..."
sudo mkdir -p /var/log/mygov-backend
sudo chown -R www-data:www-data /var/log/mygov-backend
sudo chmod -R 755 /var/log/mygov-backend
echo "✓ Директории созданы"

echo ""
echo "5. Перезагрузка systemd..."
sudo systemctl daemon-reload
echo "✓ Systemd перезагружен"

echo ""
echo "6. Проверка нового файла..."
echo "Environment переменные:"
grep "Environment" "$SERVICE_FILE"

echo ""
echo "7. Перезапуск сервиса..."
sudo systemctl restart mygov-backend
sleep 2

echo ""
echo "8. Проверка статуса..."
sudo systemctl status mygov-backend --no-pager -l | head -30

echo ""
echo "=========================================="
echo "  Готово!"
echo "=========================================="
echo ""
echo "Проверьте логи:"
echo "  sudo journalctl -u mygov-backend -f"
echo ""
echo "Или файлы логов:"
echo "  tail -f /var/log/mygov-backend/error.log"
echo "  tail -f /var/log/mygov-backend/access.log"

