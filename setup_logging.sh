#!/bin/bash
# Настройка подробного логирования

echo "=========================================="
echo "  Настройка подробного логирования"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"

echo ""
echo "1. Проверка директории логов..."
sudo mkdir -p /var/log/mygov-backend
sudo chown -R www-data:www-data /var/log/mygov-backend
sudo chmod -R 755 /var/log/mygov-backend
echo "✓ Директория логов создана"

echo ""
echo "2. Проверка systemd конфигурации..."
if grep -q "capture-output" /etc/systemd/system/mygov-backend.service; then
    echo "✓ --capture-output настроен"
else
    echo "⚠ --capture-output не найден в systemd файле"
    echo "  Добавьте --capture-output в ExecStart"
fi

if grep -q "enable-stdio-inheritance" /etc/systemd/system/mygov-backend.service; then
    echo "✓ --enable-stdio-inheritance настроен"
else
    echo "⚠ --enable-stdio-inheritance не найден"
    echo "  Добавьте --enable-stdio-inheritance в ExecStart"
fi

echo ""
echo "3. Проверка кода логирования..."
if [ -f "$PROJECT_DIR/app/utils/logger.py" ]; then
    echo "✓ Модуль logger.py существует"
else
    echo "✗ Модуль logger.py не найден"
fi

echo ""
echo "4. Тест логирования..."
cd "$PROJECT_DIR"
source venv/bin/activate

python3 << 'PYTHON_EOF'
import sys
sys.path.insert(0, '/var/www/mygov-backend')

try:
    from app.utils.logger import logger, log_document_generation, log_pdf_conversion
    
    print("✓ Импорт logger успешен")
    
    # Тест логирования
    logger.info("Тест логирования: INFO уровень")
    logger.debug("Тест логирования: DEBUG уровень")
    logger.warning("Тест логирования: WARNING уровень")
    
    log_document_generation("TEST", "Тест логирования генерации", test=True)
    log_pdf_conversion("TEST", "Тест логирования конвертации", test=True)
    
    print("✓ Логирование работает")
except Exception as e:
    print(f"✗ Ошибка: {e}")
    import traceback
    traceback.print_exc()
PYTHON_EOF

echo ""
echo "5. Перезапуск сервиса для применения изменений..."
sudo systemctl restart mygov-backend
sleep 2

echo ""
echo "6. Проверка статуса..."
sudo systemctl status mygov-backend --no-pager -l | head -15

echo ""
echo "=========================================="
echo "  Готово!"
echo "=========================================="
echo ""
echo "Просмотр логов:"
echo "  sudo journalctl -u mygov-backend -f"
echo ""
echo "Структурированные логи:"
echo "  chmod +x view_structured_logs.sh"
echo "  ./view_structured_logs.sh"
echo ""
echo "Документация:"
echo "  cat LOGGING_GUIDE.md"

