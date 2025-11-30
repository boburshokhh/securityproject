#!/bin/bash
# Диагностика проблемы с PDF для конкретного документа

cd /var/www/mygov-backend
source venv/bin/activate

echo "=========================================="
echo "  Диагностика проблемы с PDF"
echo "=========================================="

if [ -z "$1" ]; then
    echo "Использование: ./diagnose_pdf_issue.sh <document_id>"
    echo "Пример: ./diagnose_pdf_issue.sh 460"
    exit 1
fi

DOC_ID=$1

python3 - "$DOC_ID" << PYTHON_EOF
from app.services.database import db_query, db_select
from app.services.storage import storage_manager
from app.services.document import convert_docx_to_pdf
from app import create_app
import os
import sys

# Получаем ID документа из аргументов
doc_id = int(sys.argv[1]) if len(sys.argv) > 1 else None
if not doc_id:
    print("Ошибка: не указан ID документа")
    sys.exit(1)

app = create_app()

print(f"\nПроверка документа ID: {doc_id}")
print("=" * 60)

# Получаем документ
doc = db_select('documents', 'id = %s AND type_doc = 2', [doc_id], fetch_one=True)

if not doc:
    print(f"✗ Документ {doc_id} не найден")
    sys.exit(1)

print(f"✓ Документ найден")
print(f"  Номер: {doc.get('mygov_doc_number')}")
print(f"  UUID: {doc.get('uuid')}")
print(f"  DOCX путь: {doc.get('docx_path') or 'НЕТ'}")
print(f"  PDF путь: {doc.get('pdf_path') or 'НЕТ'}")

docx_path = doc.get('docx_path')
pdf_path = doc.get('pdf_path')

print(f"\n1. Проверка DOCX:")
print("-" * 60)
if docx_path:
    if docx_path.startswith('minio://'):
        print(f"  Формат: MinIO")
        print(f"  Путь: {docx_path}")
        docx_data = storage_manager.get_file(docx_path)
        if docx_data:
            print(f"  ✓ DOCX получен из MinIO, размер: {len(docx_data)} bytes")
        else:
            print(f"  ✗ DOCX не получен из MinIO")
    else:
        print(f"  Формат: Локальный файл")
        print(f"  Путь: {docx_path}")
        if os.path.exists(docx_path):
            print(f"  ✓ Файл существует, размер: {os.path.getsize(docx_path)} bytes")
        else:
            print(f"  ✗ Файл не существует")
else:
    print(f"  ✗ DOCX путь не указан")

print(f"\n2. Проверка PDF:")
print("-" * 60)
if pdf_path:
    if pdf_path.startswith('minio://'):
        print(f"  Формат: MinIO")
        print(f"  Путь: {pdf_path}")
        pdf_data = storage_manager.get_file(pdf_path)
        if pdf_data:
            print(f"  ✓ PDF получен из MinIO, размер: {len(pdf_data)} bytes")
        else:
            print(f"  ✗ PDF не получен из MinIO")
    else:
        print(f"  Формат: Локальный файл")
        print(f"  Путь: {pdf_path}")
        if os.path.exists(pdf_path):
            print(f"  ✓ Файл существует, размер: {os.path.getsize(pdf_path)} bytes")
        else:
            print(f"  ✗ Файл не существует")
else:
    print(f"  ✗ PDF путь не указан")

print(f"\n3. Попытка генерации PDF:")
print("-" * 60)
if docx_path:
    try:
        document_uuid = doc.get('uuid', '')
        print(f"  Запуск конвертации...")
        print(f"  DOCX: {docx_path}")
        print(f"  UUID: {document_uuid}")
        
        new_pdf_path = convert_docx_to_pdf(docx_path, document_uuid, app)
        
        if new_pdf_path:
            print(f"  ✓ PDF создан: {new_pdf_path}")
            
            # Проверяем, что файл доступен
            if new_pdf_path.startswith('minio://'):
                pdf_data = storage_manager.get_file(new_pdf_path)
                if pdf_data:
                    print(f"  ✓ PDF доступен в MinIO, размер: {len(pdf_data)} bytes")
                else:
                    print(f"  ✗ PDF не доступен в MinIO")
            
            # Обновляем в БД
            from app.services.database import db_update
            db_update('documents', {'pdf_path': new_pdf_path}, 'id = %s', [doc_id])
            print(f"  ✓ pdf_path обновлен в БД")
        else:
            print(f"  ✗ PDF не создан (convert_docx_to_pdf вернул None)")
    except Exception as e:
        print(f"  ✗ Ошибка при генерации: {e}")
        import traceback
        traceback.print_exc()
else:
    print(f"  ✗ DOCX не найден, генерация невозможна")

print(f"\n" + "=" * 60)
print("  Диагностика завершена")
print("=" * 60)
PYTHON_EOF



