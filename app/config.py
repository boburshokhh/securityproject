"""
Конфигурация для MyGov бэкенда
"""
import os
from dotenv import load_dotenv

load_dotenv()

# PostgreSQL конфигурация (та же БД что и dmed)
DB_HOST = os.getenv('DB_HOST', '45.138.159.141')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'dmed')
DB_USER = os.getenv('DB_USER', 'dmed_app')
DB_PASSWORD = os.getenv('DB_PASSWORD', '')
DB_SSLMODE = os.getenv('DB_SSLMODE', 'prefer')

# Flask конфигурация
SECRET_KEY = os.getenv('SECRET_KEY', 'mygov-secret-key-change-in-production')
UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', 'uploads/documents')

# Настройки приложения
DEBUG = os.getenv('DEBUG', 'True').lower() == 'true'
PORT = int(os.getenv('PORT', '5001'))

# MinIO конфигурация
MINIO_ENABLED = os.getenv('MINIO_ENABLED', 'True').lower() == 'true'
MINIO_ENDPOINT = os.getenv('MINIO_ENDPOINT', 'localhost:9000')
MINIO_ACCESS_KEY = os.getenv('MINIO_ACCESS_KEY', 'minioadmin')
MINIO_SECRET_KEY = os.getenv('MINIO_SECRET_KEY', 'minioadmin')
MINIO_SECURE = os.getenv('MINIO_SECURE', 'False').lower() == 'true'
MINIO_BUCKET_NAME = os.getenv('MINIO_BUCKET_NAME', 'mygov-documents')

# Frontend URL для генерации QR-кодов (для проверки документов)
FRONTEND_URL = os.getenv('FRONTEND_URL', 'https://repositorymygov.netlify.app')

# Тип документа для MyGov (всегда 2)
TYPE_DOC = 2

# Настройки JWT
JWT_EXPIRATION_HOURS = int(os.getenv('JWT_EXPIRATION_HOURS', '24'))

