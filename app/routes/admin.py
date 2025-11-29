"""
MyGov Backend - Маршруты для управления пользователями (только для super_admin)
"""
from functools import wraps
from flask import Blueprint, request, jsonify
import bcrypt

from app.routes.auth import require_auth, verify_token
from app.services.database import db_query, db_select, db_insert, db_update

admin_bp = Blueprint('admin', __name__)


def require_super_admin(f):
    """Декоратор для проверки прав super_admin"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        # Сначала проверяем авторизацию
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            return jsonify({'success': False, 'message': 'Требуется авторизация'}), 401
        
        parts = auth_header.split()
        if len(parts) != 2 or parts[0].lower() != 'bearer':
            return jsonify({'success': False, 'message': 'Неверный формат токена'}), 401
        
        token = parts[1]
        payload = verify_token(token)
        
        if not payload:
            return jsonify({'success': False, 'message': 'Недействительный токен'}), 401
        
        # Проверяем, что пользователь - super_admin
        if payload.get('role') != 'super_admin':
            return jsonify({'success': False, 'message': 'Доступ запрещен. Требуется роль super_admin'}), 403
        
        # Добавляем информацию о пользователе в request
        request.current_user = payload
        
        return f(*args, **kwargs)
    return decorated_function


@admin_bp.route('/users', methods=['GET'])
@require_super_admin
def list_users():
    """Получение списка всех пользователей (только mygov_admin и super_admin)"""
    try:
        query = """
            SELECT id, username, email, role, is_active, created_at, updated_at, last_login
            FROM users
            WHERE role IN ('mygov_admin', 'super_admin', 'admin')
            ORDER BY created_at DESC
        """
        
        result = db_query(query, fetch_all=True)
        users = [dict(row) for row in result] if result else []
        
        # Форматируем даты
        for user in users:
            for key in ['created_at', 'updated_at', 'last_login']:
                if user.get(key) and hasattr(user[key], 'isoformat'):
                    user[key] = user[key].isoformat()
        
        return jsonify(users)
        
    except Exception as e:
        print(f"ERROR list_users: {e}")
        return jsonify({'success': False, 'message': f'Ошибка получения списка пользователей: {str(e)}'}), 500


@admin_bp.route('/users', methods=['POST'])
@require_super_admin
def create_user():
    """Создание нового пользователя"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'success': False, 'message': 'Данные не предоставлены'}), 400
        
        username = data.get('username', '').strip()
        email = data.get('email', '').strip()
        password = data.get('password', '')
        role = data.get('role', 'mygov_admin')
        
        if not username or not email or not password:
            return jsonify({'success': False, 'message': 'Имя пользователя, email и пароль обязательны'}), 400
        
        if role not in ['admin', 'super_admin', 'mygov_admin']:
            return jsonify({'success': False, 'message': 'Неверная роль. Допустимые: admin, super_admin, mygov_admin'}), 400
        
        # Проверяем, существует ли пользователь
        existing_user = db_select('users', 'username = %s', [username], fetch_one=True)
        if existing_user:
            return jsonify({'success': False, 'message': 'Пользователь с таким именем уже существует'}), 400
        
        existing_email = db_select('users', 'email = %s', [email], fetch_one=True)
        if existing_email:
            return jsonify({'success': False, 'message': 'Пользователь с таким email уже существует'}), 400
        
        # Хешируем пароль
        password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        
        # Создаем пользователя
        user_data = {
            'username': username,
            'email': email,
            'password_hash': password_hash,
            'role': role,
            'is_active': True,
            'created_by': request.current_user.get('user_id')
        }
        
        new_user = db_insert('users', user_data)
        if not new_user:
            return jsonify({'success': False, 'message': 'Ошибка создания пользователя'}), 500
        
        # Убираем пароль из ответа
        new_user.pop('password_hash', None)
        
        # Форматируем даты
        for key in ['created_at', 'updated_at', 'last_login']:
            if new_user.get(key) and hasattr(new_user[key], 'isoformat'):
                new_user[key] = new_user[key].isoformat()
        
        return jsonify(new_user), 201
        
    except Exception as e:
        print(f"ERROR create_user: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': f'Ошибка создания пользователя: {str(e)}'}), 500


@admin_bp.route('/users/<int:user_id>', methods=['PUT'])
@require_super_admin
def update_user(user_id):
    """Обновление пользователя"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'success': False, 'message': 'Данные не предоставлены'}), 400
        
        # Проверяем, существует ли пользователь
        user = db_select('users', 'id = %s', [user_id], fetch_one=True)
        if not user:
            return jsonify({'success': False, 'message': 'Пользователь не найден'}), 404
        
        update_data = {}
        
        if 'username' in data and data['username']:
            new_username = data['username'].strip()
            # Проверяем, не занято ли имя другим пользователем
            existing = db_select('users', 'username = %s AND id != %s', [new_username, user_id], fetch_one=True)
            if existing:
                return jsonify({'success': False, 'message': 'Пользователь с таким именем уже существует'}), 400
            update_data['username'] = new_username
        
        if 'email' in data and data['email']:
            new_email = data['email'].strip()
            # Проверяем, не занят ли email другим пользователем
            existing = db_select('users', 'email = %s AND id != %s', [new_email, user_id], fetch_one=True)
            if existing:
                return jsonify({'success': False, 'message': 'Пользователь с таким email уже существует'}), 400
            update_data['email'] = new_email
        
        if 'password' in data and data['password']:
            # Хешируем новый пароль
            password_hash = bcrypt.hashpw(data['password'].encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
            update_data['password_hash'] = password_hash
        
        if 'role' in data:
            if data['role'] not in ['admin', 'super_admin', 'mygov_admin']:
                return jsonify({'success': False, 'message': 'Неверная роль'}), 400
            # Не позволяем изменять роль самого себя
            if user_id == request.current_user.get('user_id'):
                return jsonify({'success': False, 'message': 'Нельзя изменить свою роль'}), 400
            update_data['role'] = data['role']
        
        if 'is_active' in data:
            update_data['is_active'] = data['is_active']
        
        if update_data:
            db_update('users', update_data, 'id = %s', [user_id])
        
        # Возвращаем обновленного пользователя
        updated_user = db_select('users', 'id = %s', [user_id], fetch_one=True)
        if not updated_user:
            return jsonify({'success': False, 'message': 'Ошибка получения обновленного пользователя'}), 500
        
        # Убираем пароль из ответа
        updated_user.pop('password_hash', None)
        
        # Форматируем даты
        for key in ['created_at', 'updated_at', 'last_login']:
            if updated_user.get(key) and hasattr(updated_user[key], 'isoformat'):
                updated_user[key] = updated_user[key].isoformat()
        
        return jsonify(updated_user)
        
    except Exception as e:
        print(f"ERROR update_user: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': f'Ошибка обновления пользователя: {str(e)}'}), 500


@admin_bp.route('/users/<int:user_id>', methods=['DELETE'])
@require_super_admin
def delete_user(user_id):
    """Удаление пользователя"""
    try:
        # Проверяем, существует ли пользователь
        user = db_select('users', 'id = %s', [user_id], fetch_one=True)
        if not user:
            return jsonify({'success': False, 'message': 'Пользователь не найден'}), 404
        
        # Не позволяем удалить самого себя
        if user_id == request.current_user.get('user_id'):
            return jsonify({'success': False, 'message': 'Нельзя удалить самого себя'}), 400
        
        # Не позволяем удалить super_admin (защита от случайного удаления)
        if user.get('role') == 'super_admin':
            return jsonify({'success': False, 'message': 'Нельзя удалить пользователя с ролью super_admin'}), 400
        
        # Удаляем пользователя
        db_query('DELETE FROM users WHERE id = %s', [user_id])
        
        return jsonify({'success': True, 'message': 'Пользователь успешно удален'})
        
    except Exception as e:
        print(f"ERROR delete_user: {e}")
        import traceback
        print(traceback.format_exc())
        return jsonify({'success': False, 'message': f'Ошибка удаления пользователя: {str(e)}'}), 500

