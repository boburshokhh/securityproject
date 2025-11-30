# Сравнение конвертации DOCX в PDF: dmed vs my-gov-backend

## Обзор

Оба проекта используют LibreOffice для конвертации DOCX в PDF, но реализация отличается.

## Ключевые различия

### 1. Обработка Windows

**dmed (converter.py):**
```python
if sys.platform == 'win32':
    temp_config_dir = tempfile.mkdtemp(prefix='LibreOffice_Config_')
    config_path = os.path.abspath(temp_config_dir).replace('\\', '/')
    if not config_path.startswith('/'):
        config_path = '/' + config_path
    cmd.extend(['-env:UserInstallation=file:///' + config_path.lstrip('/')])
```

**my-gov-backend (document.py):**
- ❌ НЕТ специальной обработки для Windows
- ❌ НЕ использует `-env:UserInstallation`

**Проблема:** На Windows LibreOffice может требовать отдельную директорию для конфигурации.

### 2. Флаги LibreOffice

**dmed:**
```python
cmd = [
    LIBREOFFICE_CMD,
    '--headless',
    '--convert-to', 'pdf',
    '--outdir', temp_output_dir,
    docx_abs_path
]
```

**my-gov-backend:**
```python
cmd = [
    libreoffice_cmd,
    '--headless',
    '--nodefault',      # ← Дополнительный флаг
    '--nolockcheck',    # ← Дополнительный флаг
    '--nologo',         # ← Дополнительный флаг
    '--norestore',      # ← Дополнительный флаг
    '--invisible',      # ← Дополнительный флаг
    '--convert-to', 'pdf',
    '--outdir', output_dir,
    abs_docx_path
]
```

**Различие:** my-gov-backend использует больше флагов, что может вызывать проблемы на некоторых системах.

### 3. Переменные окружения

**dmed:**
- Использует стандартные переменные окружения
- Для Windows создает отдельную директорию конфигурации

**my-gov-backend:**
```python
env = os.environ.copy()
env['HOME'] = output_dir
env['TMPDIR'] = output_dir
env['TMP'] = output_dir
env['TEMP'] = output_dir
```

**Различие:** my-gov-backend переопределяет HOME, что может вызывать проблемы, если LibreOffice ожидает стандартную структуру.

### 4. Таймаут

**dmed:** 180 секунд
**my-gov-backend:** 120 секунд

### 5. Обработка ошибок

**dmed:**
- Детальная обработка stderr
- Проверка конкретных ошибок (bootstrap.ini, document is empty)
- Проверка через python-docx перед конвертацией

**my-gov-backend:**
- Простая проверка returncode
- Логирование, но без специальной обработки ошибок

### 6. Временные директории

**dmed:**
- Использует `tempfile.mkdtemp()` (ручная очистка)
- Отдельная директория для конфигурации на Windows

**my-gov-backend:**
- Использует `tempfile.TemporaryDirectory()` (автоматическая очистка)
- Одна директория для всего

## Возможные проблемы в my-gov-backend

### 1. Отсутствие поддержки Windows
Если проект запускается на Windows, отсутствие `-env:UserInstallation` может вызывать проблемы.

### 2. Переопределение HOME
Установка `HOME=output_dir` может мешать LibreOffice найти свои конфигурационные файлы.

### 3. Слишком много флагов
Флаги `--nodefault`, `--norestore` могут вызывать проблемы на некоторых системах.

### 4. Меньший таймаут
120 секунд может быть недостаточно для больших документов.

## Рекомендации по исправлению

### 1. Добавить поддержку Windows
```python
if sys.platform == 'win32':
    temp_config_dir = tempfile.mkdtemp(prefix='LibreOffice_Config_')
    config_path = os.path.abspath(temp_config_dir).replace('\\', '/')
    if not config_path.startswith('/'):
        config_path = '/' + config_path
    cmd.extend(['-env:UserInstallation=file:///' + config_path.lstrip('/')])
```

### 2. Улучшить обработку переменных окружения
Не переопределять HOME полностью, а использовать отдельную директорию для конфигурации.

### 3. Упростить флаги
Попробовать использовать минимальный набор флагов как в dmed.

### 4. Увеличить таймаут
Увеличить до 180 секунд для совместимости с dmed.

### 5. Улучшить обработку ошибок
Добавить детальную обработку stderr как в dmed.
