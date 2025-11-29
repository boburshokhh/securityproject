"""
MyGov Backend - Инициализация Flask приложения
"""
from flask import Flask
from flask_cors import CORS


def create_app():
    """Создает и конфигурирует Flask приложение"""
    app = Flask(__name__)
    
    # Загружаем конфигурацию
    from app.config import SECRET_KEY, UPLOAD_FOLDER
    app.config['SECRET_KEY'] = SECRET_KEY
    app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
    app.config['TEMPLATE_FOLDER'] = 'templates'
    
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

