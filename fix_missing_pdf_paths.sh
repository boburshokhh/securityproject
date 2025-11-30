#!/bin/bash
# Исправление отсутствующих pdf_path в БД для существующих документов

cd /var/www/mygov-backend
source venv/bin/activate

echo "=========================================="
echo "  Исправление pdf_path в БД"
echo "=========================================="

python3 << 'PYTHON_EOF'
from app.services.database import db_query, db_update, db_select
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
            # Проверяем, что docx_path в правильном формате
            if not docx_path.startswith('minio://') and not os.path.exists(docx_path):
                # Старый формат - пробуем получить из MinIO
                filename = os.path.basename(docx_path) if '/' in docx_path else docx_path
                minio_path = f"minio://dmed/{filename}"
                print(f"  ⚠ Старый формат пути, пробуем MinIO: {minio_path}")
                # Обновляем путь в БД
                db_update('documents', {'docx_path': minio_path}, 'id = %s', [doc_id])
                docx_path = minio_path
            
            pdf_path = convert_docx_to_pdf(docx_path, doc_uuid, app)
            
            if pdf_path:
                print(f"  ✓ PDF создан: {pdf_path}")
                
                # Обновляем в БД
                db_update('documents', {'pdf_path': pdf_path}, 'id = %s', [doc_id])
                print(f"  ✓ pdf_path обновлен в БД")
                
                # Проверяем обновление
                updated_doc = db_select('documents', 'id = %s', [doc_id], fetch_one=True)
                if updated_doc and updated_doc.get('pdf_path') == pdf_path:
                    print(f"  ✓ Обновление подтверждено")
                else:
                    print(f"  ⚠ Обновление не подтверждено")
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

