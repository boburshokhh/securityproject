#!/bin/bash
# Принудительное обновление кода с сервера (удаляет все локальные изменения)

cd /var/www/mygov-backend

echo "=========================================="
echo "  Принудительное обновление кода"
echo "=========================================="

echo ""
echo "1. Удаление всех __pycache__ файлов..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.pyo" -delete 2>/dev/null || true
echo "✓ Файлы удалены"

echo ""
echo "2. Получение последних изменений..."
git fetch origin main

echo ""
echo "3. Сброс к состоянию origin/main (все локальные изменения будут потеряны)..."
git reset --hard origin/main

echo ""
echo "4. Очистка неотслеживаемых файлов..."
git clean -fd

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "  ✓ ГОТОВО! Код обновлен"
    echo "=========================================="
    echo ""
    echo "Перезапустите сервис:"
    echo "  sudo systemctl restart mygov-backend"
else
    echo ""
    echo "=========================================="
    echo "  ✗ ОШИБКА при обновлении кода"
    echo "=========================================="
    echo ""
    echo "Проверьте статус:"
    echo "  git status"
fi


