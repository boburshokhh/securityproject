#!/usr/bin/env python3
"""
Тестовый скрипт для проверки генерации документа
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.services.document import generate_document
from app.services.database import db_query

app = create_app()

# Получаем первого пользователя с ролью mygov_admin или super_admin
print("Поиск тестового пользователя...")
query = """
    SELECT id, username, role 
    FROM users 
    WHERE role IN ('mygov_admin', 'super_admin') AND is_active = TRUE
    LIMIT 1
"""
user = db_query(query, fetch_one=True)

if not user:
    print("✗ Не найден пользователь с ролью mygov_admin или super_admin")
    print("Создайте пользователя через API /api/admin/users или напрямую в БД")
    sys.exit(1)

print(f"✓ Найден пользователь: {user['username']} (ID: {user['id']}, роль: {user['role']})")

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
    'issue_date': '2025-11-29',
    'days_off_from': '2025-11-29',
    'days_off_to': '2025-12-05',
    'created_by': user['id']
}

print("\n" + "="*50)
print("Тестирование generate_document...")
print("="*50)
print(f"Данные: {test_data}\n")

try:
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
        
except Exception as e:
    print("\n" + "="*50)
    print("✗ ИСКЛЮЧЕНИЕ при генерации документа")
    print("="*50)
    print(f"Ошибка: {e}")
    import traceback
    print("\nПолный traceback:")
    print(traceback.format_exc())


