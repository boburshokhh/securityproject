#!/bin/bash
# Быстрая диагностика ошибки 500

echo "=========================================="
echo "  Диагностика ошибки 500"
echo "=========================================="

echo ""
echo "1. Последние ошибки в логах (последние 50 строк):"
echo "=========================================="
sudo journalctl -u mygov-backend -n 50 --no-pager | grep -i -E "error|exception|traceback|failed" | tail -20

echo ""
echo "2. Логи генерации документов (последние 30 строк):"
echo "=========================================="
sudo journalctl -u mygov-backend --since "10 minutes ago" | grep "\[DOC_GEN:" | tail -30

echo ""
echo "3. Логи конвертации PDF (последние 30 строк):"
echo "=========================================="
sudo journalctl -u mygov-backend --since "10 minutes ago" | grep "\[PDF_CONV:" | tail -30

echo ""
echo "4. Полные логи последнего запроса (если есть):"
echo "=========================================="
sudo journalctl -u mygov-backend --since "10 minutes ago" | tail -50

echo ""
echo "5. Проверка файлов логов Gunicorn:"
echo "=========================================="
if [ -f "/var/log/mygov-backend/error.log" ]; then
    echo "Последние 30 строк error.log:"
    tail -30 /var/log/mygov-backend/error.log
else
    echo "⚠ Файл error.log не найден"
fi

echo ""
echo "=========================================="
echo "  Для просмотра логов в реальном времени:"
echo "  sudo journalctl -u mygov-backend -f"
echo ""
echo "  Или только ошибки:"
echo "  sudo journalctl -u mygov-backend -f | grep -i error"
echo "=========================================="

