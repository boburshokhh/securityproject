#!/bin/bash

echo "======================================================="
echo "   🔍 ДИАГНОСТИКА И МОНИТОРИНГ MYGOV BACKEND"
echo "======================================================="
SERVICE="mygov-backend"
LOG_DIR="/var/log/mygov-backend"
ACCESS_LOG="$LOG_DIR/access.log"
ERROR_LOG="$LOG_DIR/error.log"

# 1. Проверка статуса службы
echo ""
echo "1. СТАТУС СЛУЖБЫ:"
if systemctl is-active --quiet $SERVICE; then
    echo "   ✅ Сервис активен (running)"
    sudo systemctl status $SERVICE --no-pager | grep "Active:"
else
    echo "   ❌ Сервис НЕ АКТИВЕН"
    sudo systemctl status $SERVICE --no-pager
fi

# 2. Проверка лог-файлов
echo ""
echo "2. ПРОВЕРКА ЛОГ-ФАЙЛОВ:"
if [ -d "$LOG_DIR" ]; then
    echo "   ✅ Директория логов существует: $LOG_DIR"
    if [ -f "$ACCESS_LOG" ]; then
        ACCESS_SIZE=$(du -h "$ACCESS_LOG" | cut -f1)
        ACCESS_LINES=$(wc -l < "$ACCESS_LOG" 2>/dev/null || echo "0")
        echo "   ✅ Access log: $ACCESS_LOG ($ACCESS_SIZE, $ACCESS_LINES строк)"
    else
        echo "   ⚠️  Access log не найден: $ACCESS_LOG"
    fi
    if [ -f "$ERROR_LOG" ]; then
        ERROR_SIZE=$(du -h "$ERROR_LOG" | cut -f1)
        ERROR_LINES=$(wc -l < "$ERROR_LOG" 2>/dev/null || echo "0")
        echo "   ✅ Error log: $ERROR_LOG ($ERROR_SIZE, $ERROR_LINES строк)"
    else
        echo "   ⚠️  Error log не найден: $ERROR_LOG"
    fi
else
    echo "   ⚠️  Директория логов не существует: $LOG_DIR"
    echo "   Попытка создать..."
    sudo mkdir -p "$LOG_DIR"
    sudo chown www-data:www-data "$LOG_DIR"
    sudo chmod 755 "$LOG_DIR"
fi

# 3. Проверка последних ошибок из файлов
echo ""
echo "3. ПОСЛЕДНИЕ ОШИБКИ (за 1 час, из error.log):"
if [ -f "$ERROR_LOG" ]; then
    ERROR_RECENT=$(tail -n 50 "$ERROR_LOG" | grep -i -E "error|exception|traceback|failed|fail" | tail -n 10)
    if [ -z "$ERROR_RECENT" ]; then
        echo "   ✅ Критических ошибок не найдено"
        echo "   Последние 5 строк error.log:"
        tail -n 5 "$ERROR_LOG" | sed 's/^/   /'
    else
        echo "$ERROR_RECENT" | sed 's/^/   /'
    fi
else
    echo "   ⚠️  Файл error.log не найден"
fi

# 4. Проверка статистики из лог-файлов
echo ""
echo "4. СТАТИСТИКА (за 1 час, из error.log):"
if [ -f "$ERROR_LOG" ]; then
    # Ищем логи приложения в error.log (там идут все логи через capture-output)
    DOC_SUCCESS=$(grep "DOC_GEN:SUCCESS" "$ERROR_LOG" 2>/dev/null | wc -l)
    PDF_SUCCESS=$(grep "PDF_CONV:SUCCESS" "$ERROR_LOG" 2>/dev/null | wc -l)
    API_REQUESTS=$(grep -E "\[API:" "$ERROR_LOG" 2>/dev/null | wc -l)
    
    echo "   - API запросов (в логах): $API_REQUESTS"
    echo "   - Сгенерировано документов: $DOC_SUCCESS"
    echo "   - Сконвертировано PDF: $PDF_SUCCESS"
    
    # Также проверяем access.log
    if [ -f "$ACCESS_LOG" ]; then
        ACCESS_COUNT=$(wc -l < "$ACCESS_LOG" 2>/dev/null || echo "0")
        echo "   - HTTP запросов (access.log): $ACCESS_COUNT"
    fi
else
    echo "   ⚠️  Файл error.log не найден, статистика недоступна"
fi

# 5. Последние логи приложения
echo ""
echo "5. ПОСЛЕДНИЕ ЛОГИ ПРИЛОЖЕНИЯ (последние 20 строк):"
if [ -f "$ERROR_LOG" ]; then
    echo "   Из $ERROR_LOG:"
    tail -n 20 "$ERROR_LOG" | sed 's/^/   /'
else
    echo "   ⚠️  Файл error.log не найден"
fi

# 6. Запуск мониторинга
echo ""
echo "======================================================="
echo "   👀 ЗАПУСК РЕЖИМА ПРОСМОТРА ЛОГОВ (Real-time)"
echo "   Нажмите Ctrl+C чтобы выйти"
echo "======================================================="
echo "Мониторинг error.log (все логи приложения):"
echo "   Ищите теги:"
echo "   [API]      - Запросы к API"
echo "   [DOC_GEN]  - Генерация документов"
echo "   [PDF_CONV] - Конвертация PDF"
echo "   [ERROR]    - Ошибки"
echo "======================================================="
sleep 2

# Запускаем просмотр логов из файла
if [ -f "$ERROR_LOG" ]; then
    tail -f "$ERROR_LOG"
else
    echo "⚠️  Файл $ERROR_LOG не найден. Показываем systemd journal:"
    sudo journalctl -u $SERVICE -f -n 100
fi
