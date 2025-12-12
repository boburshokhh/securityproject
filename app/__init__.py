"""
MyGov Backend - Инициализация Flask приложения
"""
import logging
import os
import json
from datetime import datetime
from flask import Flask
from flask_cors import CORS


def create_app():
    """Создает и конфигурирует Flask приложение"""
    app = Flask(__name__)
    
    # Отладочный лог агента (Linux/production путь)
    debug_log_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '.cursor', 'debug.log')
    def _agent_log(payload: dict):
        try:
            log_dir = os.path.dirname(debug_log_path)
            os.makedirs(log_dir, exist_ok=True)
            with open(debug_log_path, 'a', encoding='utf-8') as _f:
                _f.write(json.dumps(payload) + "\n")
        except Exception:
            pass
    
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
        logger.info(f"[REQUEST] {request.method} {request.path}")
        logger.info(f"[REQUEST] Headers: {dict(request.headers)}")
        logger.info(f"[REQUEST] Remote: {request.remote_addr}")
        # Парсим JSON только для POST/PUT/PATCH запросов с телом
        if request.method in ['POST', 'PUT', 'PATCH'] and request.is_json:
            try:
                json_data = request.get_json(silent=True, force=True)
                if json_data:
                    logger.debug(f"[REQUEST] JSON Data: {json_data}")
            except Exception:
                pass  # Игнорируем ошибки парсинга JSON
        elif request.form:
            logger.debug(f"[REQUEST] Form Data: {dict(request.form)}")
        #region agent log
        try:
            if request.path.startswith('/api/files') or request.method == 'OPTIONS':
                _agent_log({
                    "sessionId": "debug-session",
                    "runId": "cors-preflight",
                    "hypothesisId": "C1",
                    "location": "app/__init__.py:before_request",
                    "message": "Incoming request",
                    "data": {
                        "method": request.method,
                        "path": request.path,
                        "origin": request.headers.get('Origin'),
                        "host": request.headers.get('Host'),
                        "access_control_request_method": request.headers.get('Access-Control-Request-Method'),
                        "access_control_request_headers": request.headers.get('Access-Control-Request-Headers')
                    },
                    "timestamp": int(datetime.now().timestamp() * 1000)
                })
        except Exception:
            pass
        #endregion
    
    @app.after_request
    def log_response_info(response):
        from flask import request
        from app.utils.logger import logger
        logger.info(f"[RESPONSE] {response.status_code} {request.method} {request.path}")
        if response.status_code >= 400:
            logger.warning(f"[RESPONSE] Error response: {response.get_data(as_text=True)[:500]}")
        #region agent log
        try:
            if request.path.startswith('/api/files') or request.method == 'OPTIONS':
                _agent_log({
                    "sessionId": "debug-session",
                    "runId": "cors-preflight",
                    "hypothesisId": "C1",
                    "location": "app/__init__.py:after_request",
                    "message": "Response sent",
                    "data": {
                        "status": response.status_code,
                        "path": request.path,
                        "method": request.method,
                        "has_acao": bool(response.headers.get('Access-Control-Allow-Origin')),
                        "acao": response.headers.get('Access-Control-Allow-Origin'),
                        "acah": response.headers.get('Access-Control-Allow-Headers'),
                        "acam": response.headers.get('Access-Control-Allow-Methods')
                    },
                    "timestamp": int(datetime.now().timestamp() * 1000)
                })
        except Exception:
            pass
        #endregion
        return response
    
    # Настройка CORS
    # Разрешаем все origins для публичных API
    CORS(app, resources={
        r"/api/*": {
            "origins": "*",
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"],
            "allow_headers": ["Content-Type", "Authorization", "X-Requested-With"],
            "supports_credentials": False,
            "max_age": 3600
        }
    })
    
    # Регистрация blueprints
    from app.routes.auth import auth_bp
    from app.routes.documents import documents_bp
    from app.routes.admin import admin_bp
    from app.routes.access import access_bp
    
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(documents_bp, url_prefix='/api/documents')
    app.register_blueprint(admin_bp, url_prefix='/api/admin')
    app.register_blueprint(access_bp, url_prefix='/api/access')
    
    # Маршрут проверки здоровья
    @app.route('/health')
    def health():
        return {'status': 'ok', 'service': 'mygov-backend'}
    
    return app


# Создаем приложение для Gunicorn
app = create_app()

