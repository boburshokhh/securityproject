#!/bin/bash
# Скрипт для диагностики проблем с генерацией документов и логированием

echo "=========================================="
echo "  Диагностика генерации документов"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"

echo ""
echo "1. Проверка статуса сервиса..."
sudo systemctl status mygov-backend --no-pager -l | head -20

echo ""
echo "2. Проверка конфигурации systemd (переменные окружения)..."
if [ -f "/etc/systemd/system/mygov-backend.service" ]; then
    echo "Переменные окружения:"
    grep "Environment" /etc/systemd/system/mygov-backend.service || echo "  Переменные окружения не найдены"
    echo ""
    echo "ExecStart:"
    grep "ExecStart" /etc/systemd/system/mygov-backend.service
else
    echo "✗ Файл systemd не найден"
fi

echo ""
echo "3. Проверка логов за последние 5 минут..."
echo "Последние 50 строк:"
sudo journalctl -u mygov-backend --since "5 minutes ago" -n 50 --no-pager

echo ""
echo "4. Поиск ошибок в логах..."
echo "Ошибки за последний час:"
sudo journalctl -u mygov-backend --since "1 hour ago" | grep -i -E "error|exception|traceback|failed|permission" | tail -20

echo ""
echo "5. Поиск DEBUG сообщений..."
echo "DEBUG сообщения за последний час:"
sudo journalctl -u mygov-backend --since "1 hour ago" | grep "\[DEBUG\]" | tail -20

echo ""
echo "6. Проверка файлов логов Gunicorn..."
if [ -f "/var/log/mygov-backend/error.log" ]; then
    echo "Последние 20 строк error.log:"
    tail -20 /var/log/mygov-backend/error.log
else
    echo "⚠ Файл /var/log/mygov-backend/error.log не найден"
    echo "  Проверьте конфигурацию systemd (--error-logfile)"
fi

if [ -f "/var/log/mygov-backend/access.log" ]; then
    echo ""
    echo "Последние 10 строк access.log:"
    tail -10 /var/log/mygov-backend/access.log
else
    echo "⚠ Файл /var/log/mygov-backend/access.log не найден"
fi

echo ""
echo "7. Проверка кода на наличие print/logging..."
echo "Проверка app/services/document.py:"
if [ -f "$PROJECT_DIR/app/services/document.py" ]; then
    echo "  Количество print/DEBUG в generate_document:"
    grep -c "print\|DEBUG" "$PROJECT_DIR/app/services/document.py" || echo "  0"
    echo "  Примеры print в коде:"
    grep -n "print\|DEBUG" "$PROJECT_DIR/app/services/document.py" | head -5
else
    echo "  ✗ Файл не найден"
fi

echo ""
echo "8. Тест прямого вызова функции генерации..."
cd "$PROJECT_DIR"
source venv/bin/activate

python3 << 'PYTHON_EOF'
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

print("\n=== Тест импорта модулей ===")
try:
    from app import create_app
    print("✓ app импортирован")
    
    from app.services.document import generate_document
    print("✓ generate_document импортирован")
    
    from app.services.database import db_query
    print("✓ db_query импортирован")
    
    app = create_app()
    print("✓ Приложение создано")
    
    # Проверяем наличие пользователя
    query = "SELECT id, username, role FROM users WHERE role IN ('mygov_admin', 'super_admin') AND is_active = TRUE LIMIT 1"
    user = db_query(query, fetch_one=True)
    
    if user:
        print(f"✓ Пользователь найден: {user['username']} (ID: {user['id']})")
        
        # Тестовые данные
        test_data = {
            'patient_name': 'Тест',
            'gender': 'M',
            'age': 30,
            'organization': 'Тест',
            'diagnosis': 'Тест',
            'doctor_name': 'Тест',
            'issue_date': '2025-11-29',
            'created_by': user['id']
        }
        
        print("\n=== Попытка генерации документа ===")
        result = generate_document(test_data, app)
        
        if result:
            print(f"✓ Документ создан! ID: {result.get('id')}")
        else:
            print("✗ Документ не был создан (вернул None)")
            print("  Проверьте логи выше для деталей")
    else:
        print("✗ Пользователь с нужной ролью не найден")
        print("  Создайте пользователя через API или напрямую в БД")
        
except Exception as e:
    print(f"✗ Ошибка: {e}")
    import traceback
    traceback.print_exc()
PYTHON_EOF

echo ""
echo "9. Проверка прав на запись..."
echo "Тест записи в uploads/documents:"
sudo -u www-data touch "$PROJECT_DIR/uploads/documents/test_write_$$.txt" 2>&1
if [ $? -eq 0 ]; then
    echo "✓ Запись возможна"
    sudo -u www-data rm "$PROJECT_DIR/uploads/documents/test_write_$$.txt"
else
    echo "✗ Ошибка записи!"
fi

echo ""
echo "10. Проверка подключения к БД..."
python3 << 'PYTHON_EOF'
from app.services.database import init_db_pool, db_query
try:
    pool = init_db_pool()
    if pool:
        print("✓ Подключение к БД установлено")
        # Тестовый запрос
        result = db_query("SELECT 1 as test", fetch_one=True)
        if result:
            print("✓ Тестовый запрос выполнен успешно")
        else:
            print("✗ Тестовый запрос не вернул результат")
    else:
        print("✗ Не удалось установить подключение к БД")
except Exception as e:
    print(f"✗ Ошибка БД: {e}")
PYTHON_EOF

echo ""
echo "=========================================="
echo "  Диагностика завершена"
echo "=========================================="
echo ""
echo "Для просмотра логов в реальном времени:"
echo "  sudo journalctl -u mygov-backend -f"
echo ""
echo "Для просмотра только ошибок:"
echo "  sudo journalctl -u mygov-backend -f | grep -i error"

