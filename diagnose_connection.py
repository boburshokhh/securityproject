#!/usr/bin/env python3
"""
Диагностический скрипт для проверки backend
Запустите: python diagnose_connection.py
"""
import sys
import os
import requests
from datetime import datetime

# Добавляем путь к проекту
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.config import PORT, DEBUG
from app.routes.documents import documents_bp
from app.routes.auth import auth_bp

def check_backend():
    """Проверка работы backend"""
    print("=" * 60)
    print("🔍 ДИАГНОСТИКА MY-GOV-BACKEND")
    print("=" * 60)
    print()
    
    # 1. Проверка конфигурации
    print("1️⃣ Проверка конфигурации:")
    print(f"   Порт: {PORT}")
    print(f"   Debug: {DEBUG}")
    print(f"   URL: http://localhost:{PORT}")
    print()
    
    # 2. Проверка Flask приложения
    print("2️⃣ Проверка Flask приложения:")
    try:
        app = create_app()
        print("   ✓ Flask приложение создано")
        
        # Проверка зарегистрированных маршрутов
        routes = []
        for rule in app.url_map.iter_rules():
            routes.append(f"{rule.methods} {rule.rule}")
        
        print(f"   ✓ Зарегистрировано маршрутов: {len(routes)}")
        print("   Основные маршруты:")
        for route in routes[:10]:
            print(f"     - {route}")
        print()
    except Exception as e:
        print(f"   ❌ Ошибка создания приложения: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    # 3. Проверка health endpoint
    print("3️⃣ Проверка health endpoint:")
    try:
        with app.test_client() as client:
            response = client.get('/health')
            if response.status_code == 200:
                print("   ✓ Health endpoint работает")
                print(f"   Ответ: {response.get_json()}")
            else:
                print(f"   ⚠️ Health endpoint вернул статус: {response.status_code}")
        print()
    except Exception as e:
        print(f"   ❌ Ошибка проверки health: {e}")
        print()
    
    # 4. Проверка маршрута генерации документов
    print("4️⃣ Проверка маршрута /api/documents/generate:")
    try:
        with app.test_client() as client:
            # Тестовый запрос без авторизации (должен вернуть 401)
            response = client.post('/api/documents/generate', 
                                  json={'test': 'data'},
                                  content_type='application/json')
            print(f"   Статус без авторизации: {response.status_code}")
            
            if response.status_code == 401:
                print("   ✓ Маршрут защищен авторизацией (ожидаемое поведение)")
            elif response.status_code == 400:
                print("   ✓ Маршрут доступен (требует валидные данные)")
            else:
                print(f"   ⚠️ Неожиданный статус: {response.status_code}")
                print(f"   Ответ: {response.get_data(as_text=True)}")
        print()
    except Exception as e:
        print(f"   ❌ Ошибка проверки маршрута: {e}")
        import traceback
        traceback.print_exc()
        print()
    
    # 5. Проверка логирования
    print("5️⃣ Проверка логирования:")
    try:
        from app.utils.logger import logger
        logger.info("Тестовое сообщение для проверки логирования")
        print("   ✓ Логирование работает")
        print()
    except Exception as e:
        print(f"   ⚠️ Проблема с логированием: {e}")
        print()
    
    # 6. Проверка подключения к БД
    print("6️⃣ Проверка подключения к БД:")
    try:
        from app.services.database import db_query
        result = db_query("SELECT 1 as test", fetch_one=True)
        if result:
            print("   ✓ Подключение к БД работает")
        else:
            print("   ⚠️ БД не отвечает")
        print()
    except Exception as e:
        print(f"   ❌ Ошибка подключения к БД: {e}")
        print()
    
    # 7. Проверка CORS
    print("7️⃣ Проверка CORS:")
    try:
        with app.test_client() as client:
            # OPTIONS запрос для проверки CORS
            response = client.options('/api/documents/generate',
                                    headers={'Origin': 'http://localhost:3000'})
            cors_headers = {
                'Access-Control-Allow-Origin': response.headers.get('Access-Control-Allow-Origin'),
                'Access-Control-Allow-Methods': response.headers.get('Access-Control-Allow-Methods'),
                'Access-Control-Allow-Headers': response.headers.get('Access-Control-Allow-Headers'),
            }
            print(f"   CORS заголовки: {cors_headers}")
            if cors_headers['Access-Control-Allow-Origin']:
                print("   ✓ CORS настроен")
            else:
                print("   ⚠️ CORS заголовки отсутствуют")
        print()
    except Exception as e:
        print(f"   ⚠️ Ошибка проверки CORS: {e}")
        print()
    
    # 8. Рекомендации
    print("=" * 60)
    print("📋 РЕКОМЕНДАЦИИ:")
    print("=" * 60)
    print("1. Убедитесь, что backend запущен: python run.py")
    print("2. Проверьте, что порт 5001 не занят другим процессом")
    print("3. Проверьте переменные окружения в .env файле")
    print("4. Проверьте логи при выполнении запросов:")
    print("   tail -f /var/log/mygov-backend/app.log")
    print("5. Для отладки включите DEBUG=True в .env")
    print()
    
    return True

if __name__ == '__main__':
    check_backend()

