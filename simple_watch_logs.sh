#!/bin/bash
# Простой скрипт для просмотра логов

echo "Просмотр логов MyGov Backend в реальном времени"
echo "Нажмите Ctrl+C для выхода"
echo ""
echo "Фильтры:"
echo "  - Все логи"
echo "  - Ошибки (ERROR, Exception)"
echo "  - DEBUG сообщения"
echo ""

sudo journalctl -u mygov-backend -f

