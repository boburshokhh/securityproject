#!/bin/bash
echo "=========================================="
echo "  Перезапуск сервиса и проверка"
echo "=========================================="

echo "1. Перезапуск службы mygov-backend..."
sudo systemctl restart mygov-backend

if [ $? -eq 0 ]; then
    echo "✓ Служба перезапущена"
else
    echo "✗ Ошибка при перезапуске службы"
    exit 1
fi

echo ""
echo "2. Статус службы:"
sudo systemctl status mygov-backend --no-pager | head -10

echo ""
echo "3. Ожидание готовности (5 сек)..."
sleep 5

echo ""
echo "4. Мониторинг логов (нажмите Ctrl+C для выхода)..."
echo "Попробуйте скачать документ сейчас через сайт/API."
echo "Смотрим логи в реальном времени..."
echo "=========================================="
sudo journalctl -u mygov-backend -f | grep --line-buffered -E "PDF_CONV|API:DOWNLOAD|ERROR"
