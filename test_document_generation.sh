#!/bin/bash
# Тест генерации документа с подробным логированием

echo "=========================================="
echo "  Тест генерации документа"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"

cd "$PROJECT_DIR"
source venv/bin/activate

echo ""
echo "Запуск теста генерации документа..."
echo "Логи будут отображаться ниже:"
echo ""

python3 << 'PYTHON_EOF'
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.services.document import generate_document
from app.services.database import db_query
from app.utils.logger import logger

app = create_app()

# Получаем первого пользователя
print("\n=== Поиск пользователя ===")
query = """
    SELECT id, username, role 
    FROM users 
    WHERE role IN ('mygov_admin', 'super_admin') AND is_active = TRUE
    LIMIT 1
"""
user = db_query(query, fetch_one=True)

if not user:
    print("✗ Пользователь не найден")
    sys.exit(1)

print(f"✓ Пользователь: {user['username']} (ID: {user['id']})")

# Тестовые данные
test_data = {
    'patient_name': 'Тестовый Пациент',
    'gender': 'M',
    'age': 30,
    'jshshir': '12345678901234',
    'address': 'Тестовый адрес',
    'organization': 'Тестовая Организация',
    'diagnosis': 'Тестовый диагноз',
    'doctor_name': 'Тестовый Доктор',
    'doctor_position': 'Врач',
    'issue_date': '2025-11-30',
    'days_off_from': '2025-11-30',
    'days_off_to': '2025-12-05',
    'created_by': user['id']
}

print("\n=== Генерация документа ===")
print("Смотрите логи выше для деталей...")
print("")

result = generate_document(test_data, app)

if result:
    print("\n" + "="*50)
    print("✓ УСПЕШНО! Документ создан")
    print("="*50)
    print(f"ID документа: {result.get('id')}")
    print(f"Номер документа: {result.get('mygov_doc_number')}")
    print(f"UUID: {result.get('uuid')}")
    print(f"PIN-код: {result.get('pin_code')}")
    print(f"DOCX путь: {result.get('docx_path')}")
    print(f"PDF путь: {result.get('pdf_path')}")
else:
    print("\n" + "="*50)
    print("✗ ОШИБКА: Документ не был создан")
    print("="*50)
    print("Проверьте логи выше для деталей ошибки")
PYTHON_EOF

echo ""
echo "=========================================="
echo "  Тест завершен"
echo "=========================================="

