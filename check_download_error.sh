#!/bin/bash
# Диагностика ошибки скачивания документов

echo "=========================================="
echo "  Диагностика ошибки скачивания"
echo "=========================================="

echo ""
echo "1. Последние логи скачивания (последние 50 строк):"
echo "=========================================="
sudo journalctl -u mygov-backend --since "10 minutes ago" | grep -i "\[API:DOWNLOAD" | tail -30

echo ""
echo "2. Ошибки при скачивании:"
echo "=========================================="
sudo journalctl -u mygov-backend --since "10 minutes ago" | grep -i -E "\[API:DOWNLOAD.*ERROR|download.*error|download.*failed" | tail -20

echo ""
echo "3. Полные логи последнего запроса скачивания:"
echo "=========================================="
sudo journalctl -u mygov-backend --since "10 minutes ago" | grep -A 10 -B 5 "\[API:DOWNLOAD" | tail -40

echo ""
echo "4. Проверка документов в БД:"
echo "=========================================="
cd /var/www/mygov-backend
source venv/bin/activate

python3 << 'PYTHON_EOF'
from app.services.database import db_query

print("Последние 5 документов с путями к файлам:")
query = """
    SELECT id, mygov_doc_number, docx_path, pdf_path, created_at
    FROM documents 
    WHERE type_doc = 2 
    ORDER BY created_at DESC 
    LIMIT 5
"""
docs = db_query(query, fetch_all=True)

for doc in docs:
    print(f"\nID: {doc['id']}, Номер: {doc.get('mygov_doc_number')}")
    print(f"  DOCX: {doc.get('docx_path')}")
    print(f"  PDF: {doc.get('pdf_path')}")
    print(f"  Создан: {doc.get('created_at')}")
PYTHON_EOF

echo ""
echo "5. Тест получения файла из хранилища:"
echo "=========================================="
python3 << 'PYTHON_EOF'
from app.services.database import db_query
from app.services.storage import storage_manager

# Получаем последний документ
query = """
    SELECT id, docx_path, pdf_path
    FROM documents 
    WHERE type_doc = 2 AND (docx_path IS NOT NULL OR pdf_path IS NOT NULL)
    ORDER BY created_at DESC 
    LIMIT 1
"""
doc = db_query(query, fetch_one=True)

if doc:
    print(f"Тестирование документа ID: {doc['id']}")
    
    if doc.get('pdf_path'):
        print(f"\nТест получения PDF: {doc['pdf_path']}")
        pdf_data = storage_manager.get_file(doc['pdf_path'])
        if pdf_data:
            print(f"✓ PDF получен, размер: {len(pdf_data)} bytes")
        else:
            print(f"✗ PDF не получен из хранилища")
    
    if doc.get('docx_path'):
        print(f"\nТест получения DOCX: {doc['docx_path']}")
        docx_data = storage_manager.get_file(doc['docx_path'])
        if docx_data:
            print(f"✓ DOCX получен, размер: {len(docx_data)} bytes")
        else:
            print(f"✗ DOCX не получен из хранилища")
else:
    print("Документы с путями не найдены")
PYTHON_EOF

echo ""
echo "=========================================="
echo "  Диагностика завершена"
echo "=========================================="

