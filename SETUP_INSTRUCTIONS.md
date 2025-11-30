# Инструкция по настройке MyGov Backend как dmed

## Полная настройка на Ubuntu сервере

### Автоматическая настройка (рекомендуется)

Выполните на сервере:

```bash
cd /var/www/mygov-backend
chmod +x setup_like_dmed.sh
sudo ./setup_like_dmed.sh
```

Этот скрипт автоматически:
- ✅ Установит все системные зависимости (LibreOffice, библиотеки)
- ✅ Создаст все необходимые директории
- ✅ Установит правильные права доступа
- ✅ Настроит виртуальное окружение
- ✅ Установит Python зависимости
- ✅ Создаст systemd сервис с правильными переменными окружения
- ✅ Настроит логирование
- ✅ Запустит сервис

### Ручная настройка

Если нужно настроить вручную:

#### 1. Установка зависимостей

```bash
sudo apt-get update
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

#### 2. Создание директорий

```bash
sudo mkdir -p /var/www/mygov-backend/uploads/documents
sudo mkdir -p /var/www/mygov-backend/templates
sudo mkdir -p /var/log/mygov-backend
sudo mkdir -p /var/www/.cache/dconf
sudo mkdir -p /var/www/.config
sudo mkdir -p /var/www/.local/share
```

#### 3. Установка прав

```bash
sudo chown -R www-data:www-data /var/www/mygov-backend
sudo chown -R www-data:www-data /var/log/mygov-backend
sudo chown -R www-data:www-data /var/www/.cache
sudo chown -R www-data:www-data /var/www/.config
sudo chown -R www-data:www-data /var/www/.local

sudo chmod -R 755 /var/www/mygov-backend
sudo chmod -R 775 /var/www/mygov-backend/uploads
sudo chmod 1777 /tmp
sudo chmod 1777 /var/tmp
```

#### 4. Настройка systemd сервиса

```bash
sudo nano /etc/systemd/system/mygov-backend.service
```

Убедитесь, что файл содержит:

```ini
[Unit]
Description=MyGov Backend Gunicorn Application Server
After=network.target postgresql.service

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/mygov-backend
Environment="PATH=/var/www/mygov-backend/venv/bin"
Environment="HOME=/var/www"
Environment="TMPDIR=/tmp"
Environment="TMP=/tmp"
Environment="TEMP=/tmp"
Environment="XDG_CACHE_HOME=/var/www/.cache"
Environment="XDG_CONFIG_HOME=/var/www/.config"
Environment="XDG_DATA_HOME=/var/www/.local/share"
ExecStart=/var/www/mygov-backend/venv/bin/gunicorn \
    --workers 4 \
    --bind 0.0.0.0:8000 \
    --timeout 300 \
    --access-logfile /var/log/mygov-backend/access.log \
    --error-logfile /var/log/mygov-backend/error.log \
    --log-level info \
    --capture-output \
    --enable-stdio-inheritance \
    --chdir /var/www/mygov-backend \
    run:app

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Важно:**
- Если используете `app:app`, замените `run:app` на `app:app` и порт на `127.0.0.1:5001`
- Переменные окружения `HOME`, `TMPDIR` и `XDG_*` критичны для работы LibreOffice

#### 5. Перезагрузка и запуск

```bash
sudo systemctl daemon-reload
sudo systemctl enable mygov-backend
sudo systemctl restart mygov-backend
sudo systemctl status mygov-backend
```

## Проверка работы

### 1. Проверка статуса

```bash
sudo systemctl status mygov-backend
```

### 2. Проверка логов

```bash
# Systemd логи
sudo journalctl -u mygov-backend -f

# Файлы логов
tail -f /var/log/mygov-backend/error.log
tail -f /var/log/mygov-backend/access.log
```

### 3. Тест генерации документа

```bash
cd /var/www/mygov-backend
source venv/bin/activate
python3 test_generate.py
```

### 4. Тест LibreOffice

```bash
# Проверка от www-data
sudo -u www-data libreoffice --headless --version

# Тест конвертации
chmod +x quick_test_conversion.sh
sudo ./quick_test_conversion.sh
```

## Отличия от dmed

MyGov Backend настроен аналогично dmed, но с отличиями:

| Параметр | dmed | mygov-backend |
|----------|------|---------------|
| Порт | 5000 | 5001 или 8000 |
| Модуль | app:app | run:app или app:app |
| Тип документа | 1 | 2 |
| Bucket MinIO | dmed | dmed (тот же) |
| БД | dmed | dmed (та же) |

## Решение проблем

### Проблема: Логи не отображаются

Проверьте:
1. `--capture-output` в systemd файле
2. `--enable-stdio-inheritance` в systemd файле
3. Права на `/var/log/mygov-backend`

### Проблема: LibreOffice не работает

Проверьте:
1. Переменные окружения `HOME`, `TMPDIR` в systemd
2. Права на `/tmp` и `/var/tmp`
3. Директории `/var/www/.cache`, `/var/www/.config`

### Проблема: Ошибки прав доступа

```bash
sudo chown -R www-data:www-data /var/www/mygov-backend
sudo chmod -R 775 /var/www/mygov-backend/uploads
```

## Дополнительная информация

- Скрипт настройки: `setup_like_dmed.sh`
- Скрипт обновления systemd: `update_systemd_service.sh`
- Диагностика: `debug_generation.sh`
- Тест LibreOffice: `quick_test_conversion.sh`

