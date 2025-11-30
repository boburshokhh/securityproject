#!/bin/bash
# Диагностика проблемы конвертации DOCX в PDF

echo "=========================================="
echo "  Диагностика конвертации DOCX в PDF"
echo "=========================================="

echo ""
echo "1. Проверка LibreOffice:"
echo "=========================================="
which libreoffice || which soffice
if [ $? -eq 0 ]; then
    echo "✓ LibreOffice найден"
    libreoffice --version 2>/dev/null || soffice --version 2>/dev/null
else
    echo "✗ LibreOffice не найден в PATH"
fi

echo ""
echo "2. Последние логи конвертации PDF:"
echo "=========================================="
# Ищем логи с тегом PDF_CONV (новые логи)
sudo journalctl -u mygov-backend --since "1 hour ago" | grep "PDF_CONV" | tail -50

echo ""
echo "3. Ошибки конвертации:"
echo "=========================================="
sudo journalctl -u mygov-backend --since "1 hour ago" | grep -i -E "PDF_CONV.*ERROR|PDF_CONV.*FAIL|libreoffice.*error|soffice.*error" | tail -20

echo ""
echo "4. Проверка последних документов без PDF:"
echo "=========================================="
cd /var/www/mygov-backend
source venv/bin/activate

python3 << 'PYTHON_EOF'
from app.services.database import db_query

query = """
    SELECT id, mygov_doc_number, docx_path, pdf_path, created_at, uuid
    FROM documents 
    WHERE type_doc = 2 
    AND docx_path IS NOT NULL 
    AND (pdf_path IS NULL OR pdf_path = '')
    ORDER BY created_at DESC 
    LIMIT 5
"""
docs = db_query(query, fetch_all=True)

if docs:
    print("Документы без PDF:")
    for doc in docs:
        print(f"\nID: {doc['id']}, Номер: {doc.get('mygov_doc_number')}")
        print(f"  UUID: {doc.get('uuid')}")
        print(f"  DOCX: {doc.get('docx_path')}")
        print(f"  PDF: {doc.get('pdf_path') or 'НЕ СОЗДАН'}")
        print(f"  Создан: {doc.get('created_at')}")
else:
    print("Все последние документы имеют PDF")
PYTHON_EOF

echo ""
echo "5. Тест конвертации (имитация):"
echo "=========================================="
python3 << 'PYTHON_EOF'
import os
import sys
from app.services.database import db_query
from app.services.storage import storage_manager
import tempfile

# Получаем последний документ с DOCX
query = """
    SELECT id, docx_path, uuid
    FROM documents 
    WHERE type_doc = 2 AND docx_path IS NOT NULL
    ORDER BY created_at DESC 
    LIMIT 1
"""
doc = db_query(query, fetch_one=True)

if doc and doc.get('docx_path'):
    print(f"Тестирование конвертации документа ID: {doc['id']}")
    print(f"DOCX путь: {doc['docx_path']}")
    
    # Получаем DOCX из хранилища
    docx_data = storage_manager.get_file(doc['docx_path'])
    if docx_data:
        print(f"✓ DOCX получен, размер: {len(docx_data)} bytes")
        
        # Создаем временный файл
        with tempfile.NamedTemporaryFile(suffix='.docx', delete=False) as tmp_docx:
            tmp_docx.write(docx_data)
            tmp_docx_path = tmp_docx.name
        
        print(f"Временный DOCX: {tmp_docx_path}")
        
        try:
            from app.services.document import convert_docx_to_pdf
            from app import create_app
            
            app = create_app()
            
            # Важно: передаем правильные аргументы
            print("Запуск convert_docx_to_pdf...")
            # Используем uuid из документа или генерируем тестовый
            doc_uuid = doc.get('uuid') or 'test-uuid'
            
            stored_path = convert_docx_to_pdf(tmp_docx_path, doc_uuid, app)
            
            if stored_path:
                print(f"✓ Функция вернула путь: {stored_path}")
                if stored_path.startswith('minio://'):
                    print("  Это путь в MinIO (корректно)")
                else:
                    print("  Это локальный путь (возможно)")
            else:
                print(f"✗ Функция вернула None - конвертация не удалась")
                
        except Exception as e:
            print(f"✗ Исключение при конвертации: {e}")
            import traceback
            traceback.print_exc()
        finally:
            # Удаляем временный файл
            if os.path.exists(tmp_docx_path):
                os.remove(tmp_docx_path)
    else:
        print("✗ Не удалось получить DOCX из хранилища")
else:
    print("Документы с DOCX не найдены")
PYTHON_EOF

echo ""
echo "=========================================="
echo "  Диагностика завершена"
echo "=========================================="
