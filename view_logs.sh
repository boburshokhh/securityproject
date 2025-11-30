#!/bin/bash
# Скрипт для просмотра логов в реальном времени

echo "=========================================="
echo "  Просмотр логов MyGov Backend"
echo "=========================================="
echo ""
echo "Выберите действие:"
echo "1. Логи systemd в реальном времени (journalctl -f)"
echo "2. Последние 100 строк логов systemd"
echo "3. Логи Gunicorn error.log (если существует)"
echo "4. Логи Gunicorn access.log (если существует)"
echo "5. Все логи (systemd + файлы)"
echo ""
read -p "Выберите опцию (1-5): " choice

case $choice in
    1)
        echo "Запуск мониторинга логов в реальном времени..."
        echo "Нажмите Ctrl+C для выхода"
        echo ""
        sudo journalctl -u mygov-backend -f
        ;;
    2)
        echo "Последние 100 строк логов systemd:"
        echo ""
        sudo journalctl -u mygov-backend -n 100 --no-pager
        ;;
    3)
        if [ -f "/var/log/mygov-backend/error.log" ]; then
            echo "Последние 100 строк error.log:"
            echo ""
            tail -n 100 /var/log/mygov-backend/error.log
        else
            echo "Файл /var/log/mygov-backend/error.log не найден"
        fi
        ;;
    4)
        if [ -f "/var/log/mygov-backend/access.log" ]; then
            echo "Последние 100 строк access.log:"
            echo ""
            tail -n 100 /var/log/mygov-backend/access.log
        else
            echo "Файл /var/log/mygov-backend/access.log не найден"
        fi
        ;;
    5)
        echo "=== Systemd логи (последние 50 строк) ==="
        sudo journalctl -u mygov-backend -n 50 --no-pager
        echo ""
        echo "=== Error.log (если существует) ==="
        if [ -f "/var/log/mygov-backend/error.log" ]; then
            tail -n 50 /var/log/mygov-backend/error.log
        else
            echo "Файл не найден"
        fi
        echo ""
        echo "=== Access.log (если существует) ==="
        if [ -f "/var/log/mygov-backend/access.log" ]; then
            tail -n 50 /var/log/mygov-backend/access.log
        else
            echo "Файл не найден"
        fi
        ;;
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac


