# Руководство по логированию MyGov Backend

## Структура логов

Все логи структурированы с префиксами для удобной фильтрации:

### Префиксы логов

- `[DOC_GEN:*]` - Генерация документа
- `[PDF_CONV:*]` - Конвертация PDF
- `[DB:*]` - Операции с базой данных
- `[STORAGE:*]` - Операции с хранилищем (MinIO)
- `[LIBREOFFICE:*]` - Работа с LibreOffice
- `[API:*]` - API запросы
- `[ERROR]` - Ошибки
- `[REQUEST]` - HTTP запросы
- `[RESPONSE]` - HTTP ответы

## Этапы генерации документа

### 1. Начало генерации
```
[DOC_GEN:START] Начало генерации документа | keys=[...] | created_by=1
```

### 2. Генерация идентификаторов
```
[DOC_GEN:UUID_GEN] Сгенерированы идентификаторы | uuid=... | pin_code=...
[DOC_GEN:DOC_NUMBER] Получен номер документа | doc_number=...
```

### 3. Вставка в БД
```
[DOC_GEN:DB_INSERT] Вставка документа в БД | patient=...
[DOC_GEN:DB_SUCCESS] Документ создан в БД | document_id=... | doc_number=...
```

### 4. Генерация DOCX
```
[DOC_GEN:DOCX_START] Начало генерации DOCX | document_id=...
[DOCX_TEMPLATE] Поиск шаблона: ...
[DOCX_TEMPLATE:FOUND] Шаблон найден: ...
[DOC_GEN:DOCX_SUCCESS] DOCX создан успешно | document_id=... | docx_path=...
[DOC_GEN:DOCX_UPDATE] Путь DOCX обновлен в БД | document_id=...
```

### 5. Конвертация в PDF
```
[DOC_GEN:PDF_START] Начало конвертации в PDF | document_id=... | docx_path=...
[PDF_CONV:START] Начало конвертации DOCX в PDF | docx_path=... | uuid=...
[PDF_CONV:LIBREOFFICE_FOUND] LibreOffice найден | cmd=...
[PDF_CONV:EXEC_START] Запуск LibreOffice | env_home=... | env_tmpdir=...
[PDF_CONV:EXEC_RESULT] LibreOffice завершен | returncode=0 | stdout_len=... | stderr_len=...
[PDF_CONV:PDF_FOUND] PDF найден | pdf_path=... | pdf_size=...
[PDF_CONV:STORAGE_SAVE] Сохранение PDF в хранилище | pdf_size=... | uuid=...
[PDF_CONV:STORAGE_SUCCESS] PDF сохранен в хранилище | stored_path=...
[DOC_GEN:PDF_SUCCESS] PDF создан успешно | document_id=... | pdf_path=...
```

### 6. Успешное завершение
```
[DOC_GEN:SUCCESS] Генерация документа завершена успешно | document_id=... | doc_number=... | has_docx=True | has_pdf=True
```

## Просмотр логов

### Все логи в реальном времени
```bash
sudo journalctl -u mygov-backend -f
```

### Только генерация документов
```bash
sudo journalctl -u mygov-backend -f | grep "\[DOC_GEN:"
```

### Только конвертация PDF
```bash
sudo journalctl -u mygov-backend -f | grep "\[PDF_CONV:"
```

### Только ошибки
```bash
sudo journalctl -u mygov-backend -f | grep -i "\[ERROR\]\|ERROR\|Exception"
```

### Использование скрипта
```bash
chmod +x view_structured_logs.sh
./view_structured_logs.sh
```

## Поиск проблем

### Проблема: Документ не создается

Ищите в логах:
```bash
sudo journalctl -u mygov-backend | grep -E "\[DOC_GEN:(START|DB_INSERT|DB_SUCCESS|ERROR)"
```

### Проблема: DOCX не создается

Ищите в логах:
```bash
sudo journalctl -u mygov-backend | grep -E "\[DOC_GEN:(DOCX_START|DOCX_SUCCESS|DOCX_FAIL)|\[DOCX_TEMPLATE"
```

### Проблема: PDF не создается

Ищите в логах:
```bash
sudo journalctl -u mygov-backend | grep -E "\[PDF_CONV:(START|EXEC_RESULT|PDF_FOUND|EXEC_FAIL|LIBREOFFICE)"
```

### Проблема: LibreOffice не работает

Ищите в логах:
```bash
sudo journalctl -u mygov-backend | grep -E "\[LIBREOFFICE:|\[PDF_CONV:(EXEC_FAIL|STDERR)"
```

## Уровни логирования

- **DEBUG** - Детальная информация для отладки
- **INFO** - Информационные сообщения о процессе
- **WARNING** - Предупреждения (не критичные проблемы)
- **ERROR** - Ошибки (критичные проблемы)

## Файлы логов

- Systemd логи: `journalctl -u mygov-backend`
- Файл логов приложения: `/var/log/mygov-backend/app.log` (если настроено)
- Gunicorn error.log: `/var/log/mygov-backend/error.log`
- Gunicorn access.log: `/var/log/mygov-backend/access.log`

## Примеры использования

### Отслеживание конкретного документа
```bash
# Найдите document_id в логах, затем:
sudo journalctl -u mygov-backend | grep "document_id=444"
```

### Анализ времени выполнения
```bash
# Ищите сообщения с временем выполнения
sudo journalctl -u mygov-backend | grep "завершена за"
```

### Поиск всех ошибок за последний час
```bash
sudo journalctl -u mygov-backend --since "1 hour ago" | grep -i error
```

