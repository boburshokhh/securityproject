"""
MyGov Backend - Сервисы
"""
from app.services.database import db_query, db_insert, db_select, db_update
from app.services.storage import storage_manager
from app.services.qr_code import generate_simple_qr
from app.services.document import generate_document

__all__ = [
    'db_query', 'db_insert', 'db_select', 'db_update',
    'storage_manager',
    'generate_simple_qr',
    'generate_document'
]

