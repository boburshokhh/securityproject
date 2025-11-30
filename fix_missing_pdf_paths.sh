#!/bin/bash
# Исправление отсутствующих pdf_path в БД для существующих документов

cd /var/www/mygov-backend
source venv/bin/activate

echo "=========================================="
echo "  Исправление pdf_path в БД"
echo "=========================================="

python3 << 'PYTHON_EOF'
from app.services.database import db_query, db_update
from app.services.storage import storage_manager
from app.services.document import convert_docx_to_pdf
from app import create_app
import os

app = create_app()

# Находим документы без PDF, но с DOCX
query = """
    SELECT id, uuid, docx_path, pdf_path, mygov_doc_number
    FROM documents 
    WHERE type_doc = 2 
    AND docx_path IS NOT NULL 
    AND (pdf_path IS NULL OR pdf_path = '')
    ORDER BY created_at DESC
"""
docs = db_query(query, fetch_all=True)

if not docs:
    print("✓ Все документы имеют PDF")
else:
    print(f"Найдено документов без PDF: {len(docs)}")
    print("")
    
    for doc in docs:
        doc_id = doc['id']
        doc_uuid = doc['uuid']
        docx_path = doc['docx_path']
        doc_number = doc.get('mygov_doc_number', 'N/A')
        
        print(f"Обработка документа ID: {doc_id}, Номер: {doc_number}")
        print(f"  DOCX: {docx_path}")
        
        # Пробуем конвертировать
        try:
            pdf_path = convert_docx_to_pdf(docx_path, doc_uuid, app)
            
            if pdf_path:
                print(f"  ✓ PDF создан: {pdf_path}")
                
                # Обновляем в БД
                db_update('documents', {'pdf_path': pdf_path}, 'id = %s', [doc_id])
                print(f"  ✓ pdf_path обновлен в БД")
            else:
                print(f"  ✗ PDF не создан")
        except Exception as e:
            print(f"  ✗ Ошибка: {e}")
            import traceback
            traceback.print_exc()
        
        print("")

print("==========================================")
print("  Обработка завершена")
print("==========================================")
PYTHON_EOF

