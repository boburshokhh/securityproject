#!/bin/bash
# Быстрое исправление проблемы с PATH в systemd

echo "=========================================="
echo "  Исправление PATH в systemd сервисе"
echo "=========================================="

SERVICE_FILE="/etc/systemd/system/mygov-backend.service"

if [ ! -f "$SERVICE_FILE" ]; then
    echo "✗ Файл сервиса не найден: $SERVICE_FILE"
    exit 1
fi

echo ""
echo "1. Создание резервной копии..."
sudo cp "$SERVICE_FILE" "${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✓ Резервная копия создана"

echo ""
echo "2. Обновление PATH в systemd файле..."

# Обновляем PATH, добавляя стандартные системные пути
sudo sed -i 's|Environment="PATH=.*venv/bin"|Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/var/www/mygov-backend/venv/bin"|g' "$SERVICE_FILE"

# Если не сработало, пробуем другой вариант
if ! grep -q "/usr/bin:/sbin:/bin" "$SERVICE_FILE"; then
    echo "Используем альтернативный метод..."
    sudo sed -i 's|Environment="PATH=/var/www/mygov-backend/venv/bin"|Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/var/www/mygov-backend/venv/bin"|g' "$SERVICE_FILE"
fi

echo "✓ PATH обновлен"

echo ""
echo "3. Проверка изменений..."
echo "Текущий PATH:"
grep "Environment=\"PATH" "$SERVICE_FILE"

echo ""
echo "4. Перезагрузка systemd..."
sudo systemctl daemon-reload
echo "✓ Systemd перезагружен"

echo ""
echo "5. Перезапуск сервиса..."
sudo systemctl restart mygov-backend
sleep 2

echo ""
echo "6. Проверка статуса..."
sudo systemctl status mygov-backend --no-pager -l | head -20

echo ""
echo "=========================================="
echo "  Готово!"
echo "=========================================="
echo ""
echo "Проверьте логи:"
echo "  sudo journalctl -u mygov-backend -f"

