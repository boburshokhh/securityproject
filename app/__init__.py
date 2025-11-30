"""
MyGov Backend - Инициализация Flask приложения
"""
import logging
import os
from flask import Flask
from flask_cors import CORS


def create_app():
    """Создает и конфигурирует Flask приложение"""
    app = Flask(__name__)
    
    # Загружаем конфигурацию
    from app.config import SECRET_KEY, UPLOAD_FOLDER, DEBUG
    app.config['SECRET_KEY'] = SECRET_KEY
    app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
    app.config['TEMPLATE_FOLDER'] = 'templates'
    
    # Настройка логирования
    if not app.debug:
        # В production логируем в файл
        log_dir = '/var/log/mygov-backend'
        if os.path.exists(log_dir) and os.access(log_dir, os.W_OK):
            from app.utils.logger import setup_file_logger
            setup_file_logger(os.path.join(log_dir, 'app.log'))
    
    # Настройка логирования Flask
    app.logger.setLevel(logging.DEBUG if DEBUG else logging.INFO)
    
    # Логирование запросов
    @app.before_request
    def log_request_info():
        from flask import request
        from app.utils.logger import logger
        logger.debug(f"[REQUEST] {request.method} {request.path}")
    
    @app.after_request
    def log_response_info(response):
        from flask import request
        from app.utils.logger import logger
        logger.debug(f"[RESPONSE] {response.status_code} {request.path}")
        return response
    
    # Настройка CORS
    CORS(app, resources={
        r"/api/*": {
            "origins": "*",
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"]
        }
    })
    
    # Регистрация blueprints
    from app.routes.auth import auth_bp
    from app.routes.documents import documents_bp
    from app.routes.admin import admin_bp
    
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(documents_bp, url_prefix='/api/documents')
    app.register_blueprint(admin_bp, url_prefix='/api/admin')
    
    # Маршрут проверки здоровья
    @app.route('/health')
    def health():
        return {'status': 'ok', 'service': 'mygov-backend'}
    
    return app


# Создаем приложение для Gunicorn
app = create_app()

