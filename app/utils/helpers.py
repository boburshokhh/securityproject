"""
MyGov Backend - Вспомогательные функции
"""
from datetime import datetime


def format_date(date_value, format_str='%d.%m.%Y'):
    """
    Форматирует дату в строку
    
    Args:
        date_value: Дата (строка, datetime или None)
        format_str: Формат вывода
    
    Returns:
        str: Отформатированная дата или пустая строка
    """
    if not date_value:
        return ''
    
    try:
        if isinstance(date_value, datetime):
            return date_value.strftime(format_str)
        
        if isinstance(date_value, str):
            # Пробуем разные форматы
            formats = [
                '%Y-%m-%dT%H:%M:%S',
                '%Y-%m-%dT%H:%M:%S.%f',
                '%Y-%m-%d',
                '%d.%m.%Y',
            ]
            
            for fmt in formats:
                try:
                    dt = datetime.strptime(date_value.split('+')[0], fmt)
                    return dt.strftime(format_str)
                except ValueError:
                    continue
        
        return str(date_value)
    except Exception:
        return str(date_value) if date_value else ''


def safe_get(dictionary, key, default=''):
    """
    Безопасное получение значения из словаря
    
    Args:
        dictionary: Словарь
        key: Ключ
        default: Значение по умолчанию
    
    Returns:
        Значение или default
    """
    if not dictionary:
        return default
    
    value = dictionary.get(key)
    return value if value is not None else default


def generate_random_string(length=8, chars='0123456789'):
    """
    Генерирует случайную строку
    
    Args:
        length: Длина строки
        chars: Допустимые символы
    
    Returns:
        str: Случайная строка
    """
    import random
    return ''.join(random.choice(chars) for _ in range(length))

