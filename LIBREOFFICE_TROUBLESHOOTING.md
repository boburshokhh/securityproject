# Решение проблем с LibreOffice на Ubuntu сервере

## Быстрая диагностика

Выполните на сервере:

```bash
cd /var/www/mygov-backend
chmod +x diagnose_libreoffice.sh
sudo ./diagnose_libreoffice.sh
```

## Основные команды для анализа

### 1. Проверка установки LibreOffice

```bash
# Проверка наличия
which libreoffice
libreoffice --version

# Проверка установленных пакетов
dpkg -l | grep libreoffice

# Проверка зависимостей
ldd /usr/bin/libreoffice | head -10
```

### 2. Проверка прав доступа

```bash
# Проверка прав на запуск от www-data
sudo -u www-data libreoffice --version

# Проверка headless режима
sudo -u www-data libreoffice --headless --version

# Проверка прав на /tmp
sudo -u www-data touch /tmp/test_write
sudo -u www-data rm /tmp/test_write
```

### 3. Тест конвертации

```bash
# Создайте тестовый DOCX
cd /tmp
python3 -c "from docx import Document; d = Document(); d.add_paragraph('Test'); d.save('test.docx')"

# Конвертация от root
libreoffice --headless --convert-to pdf test.docx

# Конвертация от www-data
sudo -u www-data libreoffice --headless --convert-to pdf test.docx

# Проверка результата
ls -lh test.pdf
```

### 4. Проверка логов

```bash
# Логи systemd
sudo journalctl -u mygov-backend -f

# Поиск ошибок LibreOffice
sudo journalctl -u mygov-backend | grep -i "libreoffice\|soffice\|pdf\|convert"
```

### 5. Проверка переменных окружения

```bash
# HOME директория www-data
sudo -u www-data sh -c 'echo $HOME'

# TMPDIR
sudo -u www-data sh -c 'echo $TMPDIR'
```

## Решения проблем

### Проблема 1: LibreOffice не установлен

```bash
sudo apt-get update
sudo apt-get install -y libreoffice libreoffice-writer
```

### Проблема 2: Нет прав на запуск от www-data

```bash
# Установите переменные окружения в systemd
sudo nano /etc/systemd/system/mygov-backend.service
```

Добавьте после `[Service]`:

```ini
Environment="HOME=/var/www"
Environment="TMPDIR=/tmp"
Environment="TMP=/tmp"
Environment="TEMP=/tmp"
```

Затем:

```bash
sudo systemctl daemon-reload
sudo systemctl restart mygov-backend
```

### Проблема 3: Проблемы с временными файлами

```bash
# Установите права на /tmp
sudo chmod 1777 /tmp
sudo chmod 1777 /var/tmp

# Создайте HOME для www-data
sudo mkdir -p /var/www/.config
sudo chown -R www-data:www-data /var/www/.config
```

### Проблема 4: Отсутствуют зависимости

```bash
sudo apt-get install -y \
    libreoffice \
    libreoffice-writer \
    libreoffice-core \
    fonts-liberation \
    fonts-dejavu \
    libcairo2 \
    libx11-6 \
    libxext6 \
    libxrender1
```

### Проблема 5: LibreOffice не может найти файлы

Проверьте пути в коде. Убедитесь, что используются абсолютные пути:

```python
# В функции convert_docx_to_pdf используется:
abs_docx_path = os.path.abspath(docx_path)
```

## Автоматическое исправление

Используйте скрипт исправления:

```bash
chmod +x fix_libreoffice.sh
sudo ./fix_libreoffice.sh
```

## Проверка после исправления

```bash
# Запустите тестовый скрипт
cd /var/www/mygov-backend
source venv/bin/activate
python3 test_generate.py
```

## Дополнительная информация

- Логи приложения: `sudo journalctl -u mygov-backend -f`
- Код конвертации: `app/services/document.py` функция `convert_docx_to_pdf`
- Функция поиска LibreOffice: `app/services/document.py` функция `find_libreoffice`


