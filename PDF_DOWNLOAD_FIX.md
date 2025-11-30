# Исправление проблемы "PDF не найден"

## Проблема
При попытке скачать документ возвращается ошибка:
```json
{
  "message": "PDF не найден",
  "success": false
}
```

## Причины

1. **PDF не был создан при генерации документа**
   - LibreOffice не установлен или не найден
   - Ошибка при конвертации DOCX в PDF
   - Проблемы с правами доступа к временным директориям

2. **PDF путь не сохранен в БД**
   - Конвертация завершилась с ошибкой, но документ все равно был сохранен
   - Поле `pdf_path` осталось NULL

## Решение

### 1. Проверка LibreOffice

Проверьте, установлен ли LibreOffice и доступен ли он:

```bash
# Проверка наличия LibreOffice
which libreoffice
# или
which soffice

# Если не найден, установите:
# Ubuntu/Debian:
sudo apt-get update
sudo apt-get install libreoffice

# CentOS/RHEL:
sudo yum install libreoffice
```

### 2. Проверка логов

Проверьте логи backend для диагностики:

```bash
# Просмотр логов генерации PDF
grep "PDF_CONV" /path/to/logs/app.log

# Просмотр ошибок
grep "ERROR.*PDF" /path/to/logs/app.log
```

### 3. Автоматическая регенерация PDF

**Исправление добавлено в код:**
- При запросе на скачивание PDF, если PDF не найден, система автоматически попытается сгенерировать его заново из DOCX
- Если DOCX доступен, PDF будет создан и сохранен в БД
- Если DOCX также недоступен, вернется информативное сообщение

### 4. Ручная регенерация PDF для существующих документов

Если у вас есть документы без PDF, можно создать скрипт для их регенерации:

```python
# regenerate_pdfs.py
from app import create_app
from app.services.database import db_query, db_update
from app.services.document import convert_docx_to_pdf

app = create_app()

with app.app_context():
    # Получаем все документы без PDF
    query = "SELECT id, uuid, docx_path FROM documents WHERE type_doc = 2 AND (pdf_path IS NULL OR pdf_path = '') AND docx_path IS NOT NULL"
    documents = db_query(query, fetch_all=True)
    
    for doc in documents:
        doc_id = doc['id']
        doc_uuid = doc['uuid']
        docx_path = doc['docx_path']
        
        print(f"Регенерация PDF для документа {doc_id}...")
        pdf_path = convert_docx_to_pdf(docx_path, doc_uuid, app)
        
        if pdf_path:
            db_update('documents', {'pdf_path': pdf_path}, 'id = %s', [doc_id])
            print(f"✓ PDF создан: {pdf_path}")
        else:
            print(f"✗ Не удалось создать PDF для документа {doc_id}")
```

### 5. Проверка прав доступа

Убедитесь, что процесс backend имеет права на:
- Чтение DOCX файлов из хранилища
- Запись во временную директорию (`/tmp` или `UPLOAD_FOLDER`)
- Запись в MinIO (если используется)

```bash
# Проверка прав на временную директорию
ls -la /tmp
# Должна быть доступна для записи

# Проверка прав на UPLOAD_FOLDER
ls -la /path/to/uploads/documents
```

## Проверка после исправления

1. **Создайте новый документ** и проверьте, что PDF создается
2. **Попробуйте скачать** существующий документ без PDF - система должна автоматически сгенерировать его
3. **Проверьте логи** на наличие ошибок конвертации

## Альтернативное решение: Fallback на DOCX

Если PDF не может быть создан, можно настроить frontend для автоматического скачивания DOCX:

```javascript
// В frontend при обработке ошибки скачивания PDF
if (error.response?.data?.docx_available) {
  // Автоматически скачать DOCX
  window.open(error.response.data.docx_url, '_blank')
}
```

## Мониторинг

Добавьте мониторинг для отслеживания проблем с PDF:

```python
# В routes/documents.py уже добавлено логирование:
# - [API:DOWNLOAD] - запросы на скачивание
# - [PDF_CONV] - процесс конвертации
# - [API:DOWNLOAD] PDF успешно сгенерирован заново - успешная регенерация
```

Проверяйте логи регулярно для выявления проблем на раннем этапе.

