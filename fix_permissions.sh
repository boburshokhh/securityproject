#!/bin/bash
# Скрипт для исправления прав доступа

echo "=========================================="
echo "  Исправление прав доступа"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"

echo ""
echo "1. Проверка текущих прав..."
ls -la "$PROJECT_DIR" | grep -E "uploads|^d"

echo ""
echo "2. Установка прав на директорию проекта..."
sudo chown -R www-data:www-data "$PROJECT_DIR"

echo ""
echo "3. Установка прав на директорию uploads..."
sudo mkdir -p "$PROJECT_DIR/uploads/documents"
sudo chown -R www-data:www-data "$PROJECT_DIR/uploads"
sudo chmod -R 755 "$PROJECT_DIR/uploads"

echo ""
echo "4. Проверка прав после исправления..."
ls -la "$PROJECT_DIR" | grep uploads
ls -la "$PROJECT_DIR/uploads" 2>/dev/null || echo "Директория uploads не существует"

echo ""
echo "5. Тест записи от имени www-data..."
sudo -u www-data touch "$PROJECT_DIR/uploads/documents/test_write.txt" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Запись успешна!"
    sudo -u www-data rm "$PROJECT_DIR/uploads/documents/test_write.txt"
else
    echo "✗ Ошибка записи!"
fi

echo ""
echo "=========================================="
echo "  Готово! Перезапустите сервис:"
echo "  sudo systemctl restart mygov-backend"
echo "=========================================="

