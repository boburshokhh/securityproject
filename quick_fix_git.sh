#!/bin/bash
# Быстрое исправление git проблем

cd /var/www/mygov-backend

echo "Удаление __pycache__ из git..."
git rm -r --cached app/__pycache__/ app/routes/__pycache__/ app/services/__pycache__/ 2>/dev/null || true

echo "Настройка git pull стратегии..."
git config pull.rebase false

echo "Обновление с удаленного репозитория..."
git fetch origin
git reset --hard origin/main

echo "✓ Готово! Код обновлен"

