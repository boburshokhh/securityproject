"""
MyGov Backend - Маршруты авторизации
"""
from functools import wraps
from flask import Blueprint, request, jsonify
import bcrypt
import jwt
from datetime import datetime, timedelta

from app.config import SECRET_KEY, JWT_EXPIRATION_HOURS
from app.services.database import db_query

auth_bp = Blueprint('auth', __name__)


def generate_token(user_id, username, role):
    """Генерирует JWT токен"""
    payload = {
        'user_id': user_id,
        'username': username,
        'role': role,
        'exp': datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm='HS256')


def verify_token(token):
    """Проверяет JWT токен"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None


def require_auth(f):
    """Декоратор для проверки авторизации"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            return jsonify({'success': False, 'message': 'Требуется авторизация'}), 401
        
        # Извлекаем токен из заголовка "Bearer <token>"
        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            return jsonify({'success': False, 'message': 'Неверный формат токена'}), 401
        
        token = parts[1]
        payload = verify_token(token)
        
        if not payload:
            return jsonify({'success': False, 'message': 'Недействительный токен'}), 401
        
        # Проверяем, что пользователь имеет роль mygov_admin или super_admin
        if payload.get('role') not in ['mygov_admin', 'super_admin']:
            return jsonify({'success': False, 'message': 'Недостаточно прав'}), 403
        
        # Добавляем информацию о пользователе в request
        request.current_user = payload
        
        return f(*args, **kwargs)
    return decorated_function


@auth_bp.route('/login', methods=['POST'])
def login():
    """Авторизация пользователя"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'success': False, 'message': 'Данные не предоставлены'}), 400
        
        username = data.get('username', '').strip()
        password = data.get('password', '')
        
        if not username or not password:
            return jsonify({'success': False, 'message': 'Введите логин и пароль'}), 400
        
        # Ищем пользователя в БД
        query = """
            SELECT id, username, email, password_hash, role, is_active 
            FROM users 
            WHERE (username = %s OR email = %s) AND is_active = TRUE
        """
        user = db_query(query, [username, username], fetch_one=True)
        
        if not user:
            return jsonify({'success': False, 'message': 'Неверный логин или пароль'}), 401
        
        # Проверяем роль (только mygov_admin и super_admin)
        if user['role'] not in ['mygov_admin', 'super_admin']:
            return jsonify({'success': False, 'message': 'Доступ запрещен для этой роли'}), 403
        
        # Проверяем пароль
        if not bcrypt.checkpw(password.encode('utf-8'), user['password_hash'].encode('utf-8')):
            return jsonify({'success': False, 'message': 'Неверный логин или пароль'}), 401
        
        # Генерируем токен
        token = generate_token(user['id'], user['username'], user['role'])
        
        # Обновляем время последнего входа
        db_query("UPDATE users SET last_login = NOW() WHERE id = %s", [user['id']])
        
        return jsonify({
            'success': True,
            'token': token,
            'user': {
                'id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'role': user['role']
            }
        })
        
    except Exception as e:
        print(f"ERROR login: {e}")
        return jsonify({'success': False, 'message': 'Ошибка сервера'}), 500


@auth_bp.route('/me', methods=['GET'])
@require_auth
def get_current_user():
    """Получение информации о текущем пользователе"""
    try:
        user_id = request.current_user.get('user_id')
        
        query = "SELECT id, username, email, role, is_active, last_login FROM users WHERE id = %s"
        user = db_query(query, [user_id], fetch_one=True)
        
        if not user:
            return jsonify({'success': False, 'message': 'Пользователь не найден'}), 404
        
        return jsonify({
            'success': True,
            'user': {
                'id': user['id'],
                'username': user['username'],
                'email': user['email'],
                'role': user['role'],
                'is_active': user['is_active'],
                'last_login': user['last_login'].isoformat() if user['last_login'] else None
            }
        })
        
    except Exception as e:
        print(f"ERROR get_current_user: {e}")
        return jsonify({'success': False, 'message': 'Ошибка сервера'}), 500


@auth_bp.route('/logout', methods=['POST'])
@require_auth
def logout():
    """Выход из системы"""
    # JWT токены stateless, поэтому просто возвращаем успех
    # Клиент должен удалить токен на своей стороне
    return jsonify({'success': True, 'message': 'Выход выполнен успешно'})

