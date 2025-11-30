#!/bin/bash
# Разрешение конфликта при git pull

echo "=========================================="
echo "  Разрешение конфликта git pull"
echo "=========================================="

cd /var/www/mygov-backend

echo ""
echo "Отмена локальных изменений в fix_missing_pdf_paths.sh..."
git checkout -- fix_missing_pdf_paths.sh

echo ""
echo "Обновление кода..."
git pull origin main

echo ""
echo "✓ Код обновлен"
echo ""
echo "Теперь можно перезапустить сервис:"
echo "  sudo systemctl restart mygov-backend"
