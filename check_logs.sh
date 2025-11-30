#!/bin/bash

echo "======================================================="
echo "   🔍 ДИАГНОСТИКА И МОНИТОРИНГ MYGOV BACKEND"
echo "======================================================="
SERVICE="mygov-backend"

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

# 2. Проверка последних ошибок
echo ""
echo "2. ПОСЛЕДНИЕ ОШИБКИ (за 1 час):"
ERR_LOGS=$(sudo journalctl -u $SERVICE --since "1 hour ago" -p err --no-pager)
if [ -z "$ERR_LOGS" ]; then
    echo "   ✅ Ошибок не найдено"
else
    echo "$ERR_LOGS" | tail -n 10
fi

# 3. Проверка статистики
echo ""
echo "3. СТАТИСТИКА (за 1 час):"
REQ_COUNT=$(sudo journalctl -u $SERVICE --since "1 hour ago" | grep "API:REQUEST" | wc -l)
DOC_SUCCESS=$(sudo journalctl -u $SERVICE --since "1 hour ago" | grep "DOC_GEN:SUCCESS" | wc -l)
PDF_SUCCESS=$(sudo journalctl -u $SERVICE --since "1 hour ago" | grep "PDF_CONV:SUCCESS" | wc -l)

echo "   - API запросов: $REQ_COUNT"
echo "   - Сгенерировано документов: $DOC_SUCCESS"
echo "   - Сконвертировано PDF: $PDF_SUCCESS"

# 4. Запуск мониторинга
echo ""
echo "======================================================="
echo "   👀 ЗАПУСК РЕЖИМА ПРОСМОТРА ЛОГОВ (Real-time)"
echo "   Нажмите Ctrl+C чтобы выйти"
echo "======================================================="
echo "Фильтр: Отображаются все сообщения. Ищите теги:"
echo "   [API]      - Запросы к API"
echo "   [DOC_GEN]  - Генерация документов"
echo "   [PDF_CONV] - Конвертация PDF"
echo "   [ERROR]    - Ошибки"
echo "======================================================="
sleep 2

# Запускаем просмотр логов
sudo journalctl -u $SERVICE -f -n 100
