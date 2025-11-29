"""
MyGov Backend - Работа с файловым хранилищем (MinIO)
"""
import os
from io import BytesIO
from app.config import (
    MINIO_ENABLED, MINIO_ENDPOINT, MINIO_ACCESS_KEY, 
    MINIO_SECRET_KEY, MINIO_SECURE, MINIO_BUCKET_NAME, UPLOAD_FOLDER
)


class StorageManager:
    """Менеджер хранилища файлов (MinIO или локальное)"""
    
    def __init__(self):
        self.use_minio = MINIO_ENABLED
        self.minio_client = None
        self.bucket_name = MINIO_BUCKET_NAME
        
        if self.use_minio:
            self._init_minio()
    
    def __del__(self):
        """Корректное завершение работы с MinIO"""
        if self.minio_client:
            try:
                # Закрываем соединения если они есть
                if hasattr(self.minio_client, '_http'):
                    self.minio_client._http.clear()
            except:
                pass
            self.minio_client = None
    
    def _init_minio(self):
        """Инициализация MinIO клиента"""
        try:
            from minio import Minio
            from minio.error import S3Error
            
            # Очищаем endpoint от путей (MinIO не принимает пути в endpoint)
            endpoint = MINIO_ENDPOINT.strip()
            
            # Автоматически определяем secure из URL
            is_secure = MINIO_SECURE
            if endpoint.startswith('https://'):
                is_secure = True
                endpoint = endpoint.replace('https://', '')
            elif endpoint.startswith('http://'):
                is_secure = False
                endpoint = endpoint.replace('http://', '')
            
            # Убираем слэш в конце и путь если есть (оставляем только host:port)
            endpoint = endpoint.rstrip('/')
            if '/' in endpoint:
                endpoint = endpoint.split('/')[0]
            
            print(f"[DEBUG] Подключение к MinIO: {endpoint}, bucket: {self.bucket_name}, secure: {is_secure}")
            
            self.minio_client = Minio(
                endpoint,
                access_key=MINIO_ACCESS_KEY,
                secret_key=MINIO_SECRET_KEY,
                secure=is_secure
            )
            
            # Проверяем существование bucket
            try:
                exists = self.minio_client.bucket_exists(self.bucket_name)
                if not exists:
                    print(f"[INFO] Bucket '{self.bucket_name}' не существует, создаем...")
                    try:
                        self.minio_client.make_bucket(self.bucket_name)
                        print(f"OK: Создан bucket '{self.bucket_name}'")
                    except S3Error as make_error:
                        if make_error.code == 'AccessDenied':
                            print(f"ERROR: Нет прав на создание bucket '{self.bucket_name}'")
                            print(f"  Проверьте политики доступа в MinIO")
                            raise
                        else:
                            raise
                else:
                    print(f"OK: Bucket '{self.bucket_name}' существует")
            except S3Error as e:
                if e.code == 'AccessDenied':
                    print(f"ERROR: Нет доступа к bucket '{self.bucket_name}'. Проверьте права доступа.")
                    print(f"  Убедитесь, что у пользователя есть права на чтение bucket")
                    raise
                else:
                    print(f"ERROR при проверке bucket: {e.code} - {e.message}")
                    raise
            
            print(f"OK: MinIO подключен ({endpoint})")
        except Exception as e:
            print(f"WARNING: MinIO недоступен: {e}")
            import traceback
            print(traceback.format_exc())
            print("Используем локальное хранилище.")
            self.use_minio = False
            self.minio_client = None
    
    def save_file(self, file_data, filename, content_type='application/octet-stream'):
        """Сохраняет файл в хранилище"""
        if self.use_minio and self.minio_client:
            return self._save_to_minio(file_data, filename, content_type)
        else:
            return self._save_locally(file_data, filename)
    
    def _save_to_minio(self, file_data, filename, content_type):
        """Сохраняет файл в MinIO"""
        try:
            if isinstance(file_data, bytes):
                file_data = BytesIO(file_data)
            
            file_data.seek(0, 2)  # В конец
            file_size = file_data.tell()
            file_data.seek(0)  # В начало
            
            self.minio_client.put_object(
                self.bucket_name,
                filename,
                file_data,
                file_size,
                content_type=content_type
            )
            
            return f"minio://{self.bucket_name}/{filename}"
        except Exception as e:
            print(f"ERROR MinIO save: {e}")
            # Fallback на локальное хранение
            if isinstance(file_data, BytesIO):
                file_data.seek(0)
                return self._save_locally(file_data.read(), filename)
            return self._save_locally(file_data, filename)
    
    def _save_locally(self, file_data, filename):
        """Сохраняет файл локально"""
        os.makedirs(UPLOAD_FOLDER, exist_ok=True)
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        
        if isinstance(file_data, BytesIO):
            file_data.seek(0)
            file_data = file_data.read()
        
        with open(file_path, 'wb') as f:
            f.write(file_data)
        
        return file_path
    
    def get_file(self, file_path):
        """Получает файл из хранилища"""
        if file_path.startswith('minio://'):
            return self._get_from_minio(file_path)
        else:
            return self._get_locally(file_path)
    
    def _get_from_minio(self, file_path):
        """Получает файл из MinIO"""
        try:
            # minio://bucket/filename -> filename
            parts = file_path.replace('minio://', '').split('/', 1)
            bucket = parts[0]
            filename = parts[1] if len(parts) > 1 else ''
            
            response = self.minio_client.get_object(bucket, filename)
            data = response.read()
            response.close()
            response.release_conn()
            
            return data
        except Exception as e:
            print(f"ERROR MinIO get: {e}")
            return None
    
    def _get_locally(self, file_path):
        """Получает файл локально"""
        try:
            with open(file_path, 'rb') as f:
                return f.read()
        except Exception as e:
            print(f"ERROR local get: {e}")
            return None
    
    def delete_file(self, file_path):
        """Удаляет файл из хранилища"""
        if file_path.startswith('minio://'):
            return self._delete_from_minio(file_path)
        else:
            return self._delete_locally(file_path)
    
    def _delete_from_minio(self, file_path):
        """Удаляет файл из MinIO"""
        try:
            parts = file_path.replace('minio://', '').split('/', 1)
            bucket = parts[0]
            filename = parts[1] if len(parts) > 1 else ''
            
            self.minio_client.remove_object(bucket, filename)
            return True
        except Exception as e:
            print(f"ERROR MinIO delete: {e}")
            return False
    
    def _delete_locally(self, file_path):
        """Удаляет файл локально"""
        try:
            if os.path.exists(file_path):
                os.remove(file_path)
            return True
        except Exception as e:
            print(f"ERROR local delete: {e}")
            return False


# Глобальный экземпляр менеджера хранилища
storage_manager = StorageManager()

