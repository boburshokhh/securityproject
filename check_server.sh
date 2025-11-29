#!/bin/bash
# Скрипт для диагностики проблем на сервере

echo "=========================================="
echo "  Диагностика MyGov Backend"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"

echo ""
echo "1. Проверка статуса сервиса..."
sudo systemctl status mygov-backend --no-pager -l

echo ""
echo "2. Последние 50 строк логов systemd..."
sudo journalctl -u mygov-backend -n 50 --no-pager

echo ""
echo "3. Последние 50 строк error.log..."
if [ -f "/var/log/mygov-backend/error.log" ]; then
    tail -n 50 /var/log/mygov-backend/error.log
else
    echo "Файл error.log не найден"
fi

echo ""
echo "4. Проверка наличия шаблона..."
if [ -f "$PROJECT_DIR/templates/template_mygov.docx" ]; then
    echo "✓ Шаблон найден"
    ls -lh "$PROJECT_DIR/templates/template_mygov.docx"
else
    echo "✗ Шаблон НЕ найден: $PROJECT_DIR/templates/template_mygov.docx"
fi

echo ""
echo "5. Проверка .env файла..."
if [ -f "$PROJECT_DIR/.env" ]; then
    echo "✓ .env файл существует"
    echo "Проверка ключевых переменных:"
    grep -E "^DB_|^MINIO_|^FRONTEND_URL" "$PROJECT_DIR/.env" | sed 's/=.*/=***/' 
else
    echo "✗ .env файл НЕ найден"
fi

echo ""
echo "6. Проверка LibreOffice..."
if command -v libreoffice &> /dev/null; then
    echo "✓ LibreOffice установлен: $(which libreoffice)"
    libreoffice --version
else
    echo "✗ LibreOffice НЕ установлен"
fi

echo ""
echo "7. Проверка подключения к БД..."
cd "$PROJECT_DIR"
source venv/bin/activate
python3 -c "
from app.config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
import psycopg2
try:
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        sslmode='prefer',
        connect_timeout=5
    )
    print('✓ Подключение к БД успешно')
    conn.close()
except Exception as e:
    print(f'✗ Ошибка подключения к БД: {e}')
"

echo ""
echo "8. Проверка MinIO..."
python3 -c "
from app.services.storage import storage_manager
try:
    if storage_manager.use_minio:
        print('✓ MinIO включен')
        print(f'  Endpoint: {storage_manager.endpoint}')
        print(f'  Bucket: {storage_manager.bucket_name}')
        # Пробуем проверить доступ
        if storage_manager.minio_client:
            buckets = storage_manager.minio_client.list_buckets()
            print('✓ MinIO доступен')
        else:
            print('✗ MinIO клиент не инициализирован')
    else:
        print('⚠ MinIO отключен, используется локальное хранилище')
except Exception as e:
    print(f'✗ Ошибка MinIO: {e}')
"

echo ""
echo "9. Проверка прав доступа..."
ls -la "$PROJECT_DIR" | head -5
ls -la "$PROJECT_DIR/uploads" 2>/dev/null || echo "Директория uploads не существует"

echo ""
echo "=========================================="
echo "  Диагностика завершена"
echo "=========================================="

