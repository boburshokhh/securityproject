#!/bin/bash
# Исправление проблемы с dconf для www-data

echo "=========================================="
echo "  Исправление проблемы с dconf"
echo "=========================================="

echo ""
echo "Создание необходимых директорий для www-data..."

# Создаем директории для кэша и конфигурации
sudo mkdir -p /var/www/.cache/dconf
sudo mkdir -p /var/www/.config
sudo mkdir -p /var/www/.local/share

# Устанавливаем права
sudo chown -R www-data:www-data /var/www/.cache
sudo chown -R www-data:www-data /var/www/.config
sudo chown -R www-data:www-data /var/www/.local

sudo chmod -R 755 /var/www/.cache
sudo chmod -R 755 /var/www/.config
sudo chmod -R 755 /var/www/.local

echo "✓ Директории созданы и права установлены"

echo ""
echo "Проверка..."
ls -la /var/www/ | grep -E "^\."

echo ""
echo "=========================================="
echo "  Готово!"
echo "=========================================="
echo ""
echo "Теперь предупреждение dconf должно исчезнуть"
echo "Перезапустите сервис:"
echo "  sudo systemctl restart mygov-backend"

