#!/bin/bash
# Быстрая проверка шаблона и плейсхолдеров

cd /var/www/mygov-backend
source venv/bin/activate

echo "=========================================="
echo "  Проверка шаблона"
echo "=========================================="

python3 << 'PYTHON_EOF'
import sys
import os
from docx import Document
import re

template_path = '/var/www/mygov-backend/templates/template_mygov.docx'

if not os.path.exists(template_path):
    print(f"✗ Шаблон не найден: {template_path}")
    sys.exit(1)

print(f"✓ Шаблон найден: {template_path}")

doc = Document(template_path)
placeholder_pattern = r'\{\{[^}]+\}\}'
found_placeholders = set()

print("\nПоиск плейсхолдеров...")

# В параграфах
for para in doc.paragraphs:
    placeholders = re.findall(placeholder_pattern, para.text)
    for ph in placeholders:
        found_placeholders.add(ph)

# В таблицах
for table in doc.tables:
    for row in table.rows:
        for cell in row.cells:
            for para in cell.paragraphs:
                placeholders = re.findall(placeholder_pattern, para.text)
                for ph in placeholders:
                    found_placeholders.add(ph)

print(f"\nНайдено плейсхолдеров: {len(found_placeholders)}")
for ph in sorted(found_placeholders):
    print(f"  - {ph}")

# Проверка ожидаемых
expected = ['{{patient_name}}', '{{doc_number}}', '{{organization}}', '{{doctor_name}}']
print("\nПроверка ключевых плейсхолдеров:")
for ph in expected:
    if ph in found_placeholders:
        print(f"  ✓ {ph}")
    else:
        print(f"  ✗ {ph} - НЕ НАЙДЕН!")
PYTHON_EOF

