# Инструкция по деплою MyGov Backend на Ubuntu

## Требования

- Ubuntu 20.04+ или 22.04+
- Python 3.8+
- PostgreSQL (используется та же БД что и dmed)
- MinIO (используется тот же MinIO что и dmed)
- Nginx (опционально, для проксирования)

## Быстрый деплой

### 1. Подготовка на локальной машине

```bash
# Убедитесь, что все изменения закоммичены
cd my-gov-backend

# Проверьте, что requirements.txt содержит gunicorn
grep gunicorn requirements.txt
```

### 2. Копирование на сервер

```bash
# С вашей локальной машины
scp -r my-gov-backend user@your-server:/tmp/
```

### 3. На сервере

```bash
# Подключитесь к серверу
ssh user@your-server

# Перейдите в директорию проекта
cd /tmp/my-gov-backend

# Запустите скрипт деплоя
sudo bash deploy/deploy.sh
```

## Ручной деплой

Если скрипт не работает, выполните шаги вручную:

### 1. Создание директорий

```bash
sudo mkdir -p /var/www/my-gov-backend
sudo mkdir -p /var/log/mygov-backend
sudo chown -R www-data:www-data /var/www/my-gov-backend
sudo chown -R www-data:www-data /var/log/mygov-backend
```

### 2. Копирование файлов

```bash
# Скопируйте все файлы проекта в /var/www/my-gov-backend
# Исключите: venv, __pycache__, .env, uploads, .git
sudo cp -r /tmp/my-gov-backend/* /var/www/my-gov-backend/
```

### 3. Создание виртуального окружения

```bash
cd /var/www/my-gov-backend
sudo python3 -m venv venv
sudo chown -R www-data:www-data venv
```

### 4. Установка зависимостей

```bash
sudo -u www-data /var/www/my-gov-backend/venv/bin/pip install --upgrade pip
sudo -u www-data /var/www/my-gov-backend/venv/bin/pip install -r requirements.txt
```

### 5. Настройка .env файла

```bash
sudo nano /var/www/my-gov-backend/.env
```

Пример содержимого:

```env
# PostgreSQL (та же БД что и dmed)
DB_HOST=45.138.159.141
DB_PORT=5432
DB_NAME=dmed
DB_USER=dmed_app
DB_PASSWORD=your_password_here

# Flask
SECRET_KEY=your-secret-key-here-change-in-production
DEBUG=False
PORT=5001

# MinIO (тот же MinIO что и dmed)
MINIO_ENABLED=True
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=False
MINIO_BUCKET_NAME=mygov-documents

# Frontend URL для QR-кодов
FRONTEND_URL=https://mygov.dmed.uz

# JWT
JWT_EXPIRATION_HOURS=24
```

**ВАЖНО:** 
- Используйте тот же `DB_PASSWORD` что и в основном dmed проекте
- Сгенерируйте новый `SECRET_KEY` для production
- Установите `DEBUG=False` для production

### 6. Установка systemd сервиса

```bash
sudo cp /var/www/my-gov-backend/deploy/mygov-backend.service /etc/systemd/system/mygov-backend.service
sudo systemctl daemon-reload
sudo systemctl enable mygov-backend.service
```

### 7. Запуск сервиса

```bash
sudo systemctl start mygov-backend.service
sudo systemctl status mygov-backend.service
```

## Настройка Nginx (опционально)

Если хотите проксировать запросы через Nginx:

```bash
sudo nano /etc/nginx/sites-available/mygov-backend.conf
```

Содержимое:

```nginx
server {
    listen 80;
    server_name mygov.dmed.uz;

    location / {
        proxy_pass http://127.0.0.1:5001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Активация:

```bash
sudo ln -s /etc/nginx/sites-available/mygov-backend.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

## Управление сервисом

### Полезные команды

```bash
# Проверить статус
sudo systemctl status mygov-backend

# Посмотреть логи
sudo journalctl -u mygov-backend -f

# Перезапустить
sudo systemctl restart mygov-backend

# Остановить
sudo systemctl stop mygov-backend

# Включить автозапуск
sudo systemctl enable mygov-backend

# Отключить автозапуск
sudo systemctl disable mygov-backend
```

### Проверка работы

```bash
# Health check
curl http://localhost:5001/health

# API endpoint
curl http://localhost:5001/api/documents/verify/test-uuid
```

## Обновление приложения

```bash
# 1. Остановить сервис
sudo systemctl stop mygov-backend

# 2. Сделать резервную копию
sudo cp -r /var/www/my-gov-backend /var/www/my-gov-backend.backup

# 3. Обновить файлы (скопировать новые версии)
sudo cp -r /tmp/my-gov-backend/* /var/www/my-gov-backend/

# 4. Обновить зависимости (если изменились)
cd /var/www/my-gov-backend
sudo -u www-data venv/bin/pip install -r requirements.txt

# 5. Запустить сервис
sudo systemctl start mygov-backend
```

## Устранение проблем

### Сервис не запускается

```bash
# Проверить логи
sudo journalctl -u mygov-backend -n 50

# Проверить права доступа
ls -la /var/www/my-gov-backend
sudo chown -R www-data:www-data /var/www/my-gov-backend
```

### Ошибки подключения к БД

```bash
# Проверить доступность БД
psql -h 45.138.159.141 -U dmed_app -d dmed

# Проверить .env файл
sudo cat /var/www/my-gov-backend/.env | grep DB_
```

### Ошибки MinIO

```bash
# Проверить доступность MinIO
curl http://localhost:9000/minio/health/live

# Проверить настройки в .env
sudo cat /var/www/my-gov-backend/.env | grep MINIO_
```

### Порт уже занят

```bash
# Проверить, что использует порт 5001
sudo lsof -i :5001

# Или изменить порт в .env и systemd сервисе
```

## Безопасность

1. **Не храните .env в git** - файл уже в .gitignore
2. **Используйте сильный SECRET_KEY** - сгенерируйте через `openssl rand -hex 32`
3. **Установите DEBUG=False** в production
4. **Ограничьте доступ к .env** - `chmod 600 /var/www/my-gov-backend/.env`
5. **Используйте firewall** - откройте только необходимые порты

## Мониторинг

### Логи приложения

```bash
# Логи Gunicorn
tail -f /var/log/mygov-backend/access.log
tail -f /var/log/mygov-backend/error.log

# Логи systemd
journalctl -u mygov-backend -f
```

### Мониторинг ресурсов

```bash
# Использование памяти
ps aux | grep gunicorn

# Использование портов
netstat -tulpn | grep 5001
```

