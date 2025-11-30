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
                # Старый формат - пробуем получить из MinIO по UUID
                possible_paths = []
                if doc_uuid:
                    possible_paths.append(f"minio://dmed/{doc_uuid}.docx")
                
                filename = os.path.basename(docx_path) if '/' in docx_path else docx_path
                if filename and filename.endswith('.docx'):
                    possible_paths.append(f"minio://dmed/{filename}")
                
                print(f"  ⚠ Старый формат пути, пробуем MinIO: {possible_paths}")
                
                # Пробуем получить файл из MinIO
                docx_data = None
                new_docx_path = None
                for minio_path in possible_paths:
                    docx_data = storage_manager.get_file(minio_path)
                    if docx_data:
                        new_docx_path = minio_path
                        print(f"  ✓ DOCX найден в MinIO: {minio_path}")
                        break
                
                if new_docx_path:
                    # Обновляем путь в БД
                    db_update('documents', {'docx_path': new_docx_path}, 'id = %s', [doc_id])
                    docx_path = new_docx_path
                else:
                    print(f"  ✗ DOCX не найден в MinIO по путям: {possible_paths}")
                    print(f"  ⚠ Пропускаем документ {doc_id}")
                    continue
            elif not docx_path.startswith('minio://') and os.path.exists(docx_path):
                # Локальный файл существует, но нужно проверить, есть ли он в MinIO
                if doc_uuid:
                    minio_path = f"minio://dmed/{doc_uuid}.docx"
                    docx_data = storage_manager.get_file(minio_path)
                    if docx_data:
                        print(f"  ⚠ Локальный файл существует, но также найден в MinIO. Обновляем путь: {minio_path}")
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

