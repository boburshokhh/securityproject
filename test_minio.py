"""
Скрипт для диагностики подключения к MinIO
"""
import os
from dotenv import load_dotenv

load_dotenv()

from minio import Minio
from minio.error import S3Error

# Получаем настройки
endpoint = os.getenv('MINIO_ENDPOINT', '').strip()
access_key = os.getenv('MINIO_ACCESS_KEY', '')
secret_key = os.getenv('MINIO_SECRET_KEY', '')
bucket_name = os.getenv('MINIO_BUCKET_NAME', 'dmed')
minio_secure = os.getenv('MINIO_SECURE', 'False').lower() == 'true'

print("=" * 60)
print("Диагностика MinIO")
print("=" * 60)
print(f"Endpoint (исходный): {endpoint}")
print(f"Access Key: {access_key[:3]}***")
print(f"Secret Key: {'*' * len(secret_key) if secret_key else 'НЕ УСТАНОВЛЕН'}")
print(f"Bucket: {bucket_name}")
print(f"Secure (из .env): {minio_secure}")
print()

# Парсим endpoint
is_secure = minio_secure
if endpoint.startswith('https://'):
    is_secure = True
    endpoint = endpoint.replace('https://', '')
elif endpoint.startswith('http://'):
    is_secure = False
    endpoint = endpoint.replace('http://', '')

# Убираем слэш в конце
endpoint = endpoint.rstrip('/')
if '/' in endpoint:
    endpoint = endpoint.split('/')[0]

print(f"Endpoint (обработанный): {endpoint}")
print(f"Secure (автоопределено): {is_secure}")
print()

try:
    print("Подключение к MinIO...")
    client = Minio(
        endpoint,
        access_key=access_key,
        secret_key=secret_key,
        secure=is_secure
    )
    print("✓ Подключение успешно!")
    print()
    
    # Проверяем bucket
    print(f"Проверка bucket '{bucket_name}'...")
    try:
        exists = client.bucket_exists(bucket_name)
        if exists:
            print(f"✓ Bucket '{bucket_name}' существует")
        else:
            print(f"✗ Bucket '{bucket_name}' НЕ существует")
            print(f"  Попытка создать bucket...")
            try:
                client.make_bucket(bucket_name)
                print(f"✓ Bucket '{bucket_name}' успешно создан!")
            except S3Error as e:
                print(f"✗ Ошибка при создании bucket: {e}")
                print(f"  Код ошибки: {e.code}")
                print(f"  Сообщение: {e.message}")
    except S3Error as e:
        print(f"✗ Ошибка при проверке bucket: {e}")
        print(f"  Код ошибки: {e.code}")
        print(f"  Сообщение: {e.message}")
        if e.code == 'AccessDenied':
            print()
            print("РЕШЕНИЕ:")
            print("  1. Проверьте правильность Access Key и Secret Key")
            print("  2. Убедитесь, что у пользователя есть права на bucket")
            print("  3. Проверьте политики доступа в MinIO")
    
    # Список всех buckets
    print()
    print("Список доступных buckets:")
    try:
        buckets = client.list_buckets()
        for bucket in buckets:
            print(f"  - {bucket.name} (создан: {bucket.creation_date})")
    except S3Error as e:
        print(f"✗ Ошибка при получении списка buckets: {e}")
    
    # Тест записи файла
    print()
    print(f"Тест записи файла в bucket '{bucket_name}'...")
    try:
        test_data = b"test file content"
        from io import BytesIO
        test_stream = BytesIO(test_data)
        test_filename = "test_write_access.txt"
        
        client.put_object(
            bucket_name,
            test_filename,
            test_stream,
            len(test_data),
            content_type='text/plain'
        )
        print(f"✓ Файл '{test_filename}' успешно записан!")
        
        # Удаляем тестовый файл
        try:
            client.remove_object(bucket_name, test_filename)
            print(f"✓ Тестовый файл удален")
        except:
            pass
            
    except S3Error as e:
        print(f"✗ Ошибка при записи файла: {e}")
        print(f"  Код ошибки: {e.code}")
        print(f"  Сообщение: {e.message}")
        if e.code == 'AccessDenied':
            print()
            print("ПРОБЛЕМА: Нет прав на ЗАПИСЬ в bucket!")
            print("РЕШЕНИЕ:")
            print("  1. Проверьте политики доступа в MinIO Console")
            print("  2. Убедитесь, что у пользователя есть права PutObject, GetObject")
            print("  3. Проверьте bucket policy в MinIO")
        
except Exception as e:
    print(f"✗ ОШИБКА подключения: {e}")
    print()
    print("Возможные причины:")
    print("  1. Неправильный endpoint")
    print("  2. MinIO сервер недоступен")
    print("  3. Неправильные credentials")
    print("  4. Проблемы с сетью/файрволом")
    import traceback
    traceback.print_exc()

print()
print("=" * 60)

