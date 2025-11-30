#!/bin/bash
# Разрешение конфликтов git

cd /var/www/mygov-backend

echo "Удаление конфликтующих локальных файлов..."
rm -f fix_git_pycache.sh quick_fix_git.sh fix_path_issue.sh 2>/dev/null || true

echo "Обновление с удаленного репозитория..."
git pull origin main

echo "✓ Готово!"

