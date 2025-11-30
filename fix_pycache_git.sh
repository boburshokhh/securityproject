#!/bin/bash
# Исправление проблемы с __pycache__ при git pull

echo "=========================================="
echo "  Исправление __pycache__ конфликта"
echo "=========================================="

cd /var/www/mygov-backend

echo ""
echo "1. Удаление __pycache__ из Git индекса..."
git rm -r --cached app/services/__pycache__/ 2>/dev/null || true
git rm -r --cached app/__pycache__/ 2>/dev/null || true
git rm -r --cached app/routes/__pycache__/ 2>/dev/null || true
git rm -r --cached app/utils/__pycache__/ 2>/dev/null || true

echo ""
echo "2. Проверка .gitignore..."
if ! grep -q "__pycache__" .gitignore 2>/dev/null; then
    echo "Добавление __pycache__ в .gitignore..."
    echo "" >> .gitignore
    echo "# Python cache" >> .gitignore
    echo "__pycache__/" >> .gitignore
    echo "*.pyc" >> .gitignore
    echo "*.pyo" >> .gitignore
    echo "*.pyd" >> .gitignore
    echo ".Python" >> .gitignore
fi

echo ""
echo "3. Обновление кода..."
git pull origin main

echo ""
echo "✓ Код обновлен"
echo ""
echo "Теперь можно перезапустить сервис:"
echo "  sudo systemctl restart mygov-backend"

