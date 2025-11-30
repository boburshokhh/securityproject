#!/bin/bash
# Тест реальной генерации документа с просмотром логов

cd /var/www/mygov-backend
source venv/bin/activate

echo "=========================================="
echo "  Тест реальной генерации документа"
echo "=========================================="

echo ""
echo "Создаю тестовый документ..."
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

# Тестовые данные с полными полями
test_data = {
    'patient_name': 'ТЕСТОВЫЙ ПАЦИЕНТ ИВАНОВ',
    'gender': 'M',
    'age': 30,
    'jshshir': '12345678901234',
    'address': 'Город Ташкент, улица Тестовая, дом 1',
    'attached_medical_institution': 'Тестовая Медицинская Организация',
    'organization': 'Тестовая Организация',
    'diagnosis': 'Тестовый диагноз',
    'diagnosis_icd10_code': 'Z00.0',
    'final_diagnosis': 'Финальный диагноз',
    'final_diagnosis_icd10_code': 'Z00.1',
    'doctor_name': 'ТЕСТОВЫЙ ДОКТОР ПЕТРОВ',
    'doctor_position': 'Врач-терапевт',
    'department_head_name': 'ТЕСТОВЫЙ ЗАВЕДУЮЩИЙ СИДОРОВ',
    'days_off_from': '2025-11-30',
    'days_off_to': '2025-12-05',
    'issue_date': '2025-11-30',
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
    
    # Проверяем, что данные вставились
    print("\n=== Проверка заполнения ===")
    if result.get('docx_path'):
        print(f"✓ DOCX создан: {result.get('docx_path')}")
    if result.get('pdf_path'):
        print(f"✓ PDF создан: {result.get('pdf_path')}")
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
echo ""
echo "Проверьте логи выше для деталей заполнения шаблона"
echo "Ищите строки с [DOCX_TEMPLATE] и [DOCX_REPLACE]"

