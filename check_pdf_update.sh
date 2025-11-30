#!/bin/bash
# Проверка обновления pdf_path в БД

cd /var/www/mygov-backend
source venv/bin/activate

echo "=========================================="
echo "  Проверка обновления pdf_path в БД"
echo "=========================================="

python3 << 'PYTHON_EOF'
from app.services.database import db_query
from app.utils.logger import logger

# Проверяем последние документы
query = """
    SELECT id, uuid, docx_path, pdf_path, mygov_doc_number, created_at
    FROM documents 
    WHERE type_doc = 2 
    ORDER BY created_at DESC 
    LIMIT 10
"""
docs = db_query(query, fetch_all=True)

print("Последние 10 документов:")
print("=" * 80)

for doc in docs:
    print(f"\nID: {doc['id']}, Номер: {doc.get('mygov_doc_number')}")
    print(f"  UUID: {doc.get('uuid')}")
    print(f"  DOCX: {doc.get('docx_path') or 'НЕТ'}")
    print(f"  PDF: {doc.get('pdf_path') or 'НЕТ'}")
    print(f"  Создан: {doc.get('created_at')}")
    
    # Проверяем, есть ли PDF в MinIO если путь указан
    if doc.get('pdf_path'):
        pdf_path = doc['pdf_path']
        if pdf_path.startswith('minio://'):
            print(f"  ✓ PDF путь указан: {pdf_path}")
        else:
            print(f"  ⚠ PDF путь указан, но не MinIO: {pdf_path}")
    elif doc.get('docx_path'):
        print(f"  ✗ PDF путь НЕ указан, но DOCX есть")

print("\n" + "=" * 80)

# Проверяем документы без PDF
query_no_pdf = """
    SELECT COUNT(*) as count
    FROM documents 
    WHERE type_doc = 2 
    AND docx_path IS NOT NULL 
    AND (pdf_path IS NULL OR pdf_path = '')
"""
result = db_query(query_no_pdf, fetch_one=True)
count = result['count'] if result else 0

print(f"\nДокументов без PDF (но с DOCX): {count}")

if count > 0:
    print("\nЭти документы нужно обработать для создания PDF")
PYTHON_EOF

