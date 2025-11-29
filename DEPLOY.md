# Быстрый деплой MyGov Backend на Ubuntu

## Шаги деплоя

### 1. На локальной машине

```bash
# Убедитесь, что все изменения сохранены
cd my-gov-backend
git status  # если используете git
```

### 2. Копирование на сервер

```bash
# С вашей локальной машины (Windows PowerShell)
scp -r my-gov-backend user@your-server:/tmp/
```

Или используйте WinSCP, FileZilla или другой SFTP клиент.

### 3. На сервере Ubuntu

```bash
# Подключитесь к серверу
ssh user@your-server

# Перейдите в директорию
cd /tmp/my-gov-backend

# Запустите скрипт деплоя
sudo bash deploy/deploy.sh
```

Скрипт автоматически:
- ✅ Создаст директории `/var/www/my-gov-backend` и `/var/log/mygov-backend`
- ✅ Скопирует файлы проекта
- ✅ Создаст виртуальное окружение Python
- ✅ Установит все зависимости (включая Gunicorn)
- ✅ Настроит systemd сервис
- ✅ Запустит приложение

### 4. Настройка .env файла

После первого запуска скрипт попросит создать `.env` файл. Создайте его:

```bash
sudo nano /var/www/my-gov-backend/.env
```

**ВАЖНО:** Используйте те же настройки БД и MinIO, что и в основном dmed проекте:

```env
DB_HOST=45.138.159.141
DB_PORT=5432
DB_NAME=dmed
DB_USER=dmed_app
DB_PASSWORD=ваш_пароль_от_dmed
DB_SSLMODE=prefer

SECRET_KEY=сгенерируйте_новый_ключ_openssl_rand_hex_32
DEBUG=False
PORT=5001

MINIO_ENABLED=True
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_SECURE=False
MINIO_BUCKET_NAME=mygov-documents

FRONTEND_URL=https://mygov.dmed.uz
JWT_EXPIRATION_HOURS=24
UPLOAD_FOLDER=uploads/documents
```

После создания `.env` файла, перезапустите сервис:

```bash
sudo systemctl restart mygov-backend
```

## Проверка работы

```bash
# Проверить статус
sudo systemctl status mygov-backend

# Проверить логи
sudo journalctl -u mygov-backend -f

# Проверить API
curl http://localhost:5001/health
```

## Полезные команды

```bash
# Перезапустить сервис
sudo systemctl restart mygov-backend

# Остановить сервис
sudo systemctl stop mygov-backend

# Посмотреть логи
sudo journalctl -u mygov-backend -n 50

# Посмотреть логи Gunicorn
tail -f /var/log/mygov-backend/error.log
```

## Обновление приложения

```bash
# 1. Остановить
sudo systemctl stop mygov-backend

# 2. Обновить файлы (скопировать новые версии в /var/www/my-gov-backend)

# 3. Обновить зависимости (если изменились)
cd /var/www/my-gov-backend
sudo -u www-data venv/bin/pip install -r requirements.txt

# 4. Запустить
sudo systemctl start mygov-backend
```

## Устранение проблем

### Сервис не запускается

```bash
# Проверить логи
sudo journalctl -u mygov-backend -n 100

# Проверить права доступа
sudo chown -R www-data:www-data /var/www/my-gov-backend
```

### Ошибки подключения к БД

Убедитесь, что `.env` файл содержит правильный `DB_PASSWORD` (тот же, что и в dmed).

### Порт занят

```bash
# Проверить, что использует порт 5001
sudo lsof -i :5001

# Или изменить порт в .env и systemd сервисе
```

Подробная документация: `deploy/README_DEPLOY.md`

