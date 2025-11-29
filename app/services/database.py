"""
MyGov Backend - Работа с базой данных PostgreSQL
"""
import psycopg2
from psycopg2.extras import RealDictCursor
from app.config import DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_SSLMODE

# Пул подключений
db_pool = None


def get_db_connection():
    """Создает подключение к PostgreSQL"""
    if not DB_PASSWORD:
        raise ValueError("DB_PASSWORD не установлен. Проверьте файл .env")
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        sslmode=DB_SSLMODE
    )


def init_db_pool():
    """Инициализирует пул подключений к БД"""
    global db_pool
    if db_pool is None:
        try:
            from psycopg2 import pool as psycopg2_pool
            if not DB_PASSWORD:
                print("WARNING: DB_PASSWORD не установлен")
                return None
            
            db_pool = psycopg2_pool.SimpleConnectionPool(
                minconn=1,
                maxconn=10,
                host=DB_HOST,
                port=DB_PORT,
                database=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD,
                sslmode=DB_SSLMODE
            )
            print("OK: Подключение к PostgreSQL установлено")
            return db_pool
        except Exception as e:
            print(f"ERROR: Ошибка подключения к PostgreSQL: {e}")
            db_pool = None
            return None
    return db_pool


def db_query(query, params=None, fetch_one=False, fetch_all=False):
    """Выполняет SQL запрос к БД"""
    conn = None
    try:
        pool = init_db_pool()
        if pool:
            conn = pool.getconn()
        else:
            conn = get_db_connection()
        
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        cursor.execute(query, params)
        
        if fetch_one:
            result = cursor.fetchone()
            conn.commit()
        elif fetch_all:
            result = cursor.fetchall()
            conn.commit()
        else:
            conn.commit()
            result = cursor.rowcount
        
        cursor.close()
        return result
    except Exception as e:
        if conn:
            conn.rollback()
        print(f"Ошибка БД: {e}")
        raise e
    finally:
        if conn:
            pool = init_db_pool()
            if pool:
                pool.putconn(conn)
            else:
                conn.close()


def db_insert(table, data):
    """Вставляет данные в таблицу и возвращает созданную запись"""
    columns = list(data.keys())
    values = list(data.values())
    placeholders = ', '.join(['%s'] * len(values))
    columns_str = ', '.join(columns)
    
    query = f"""
        INSERT INTO {table} ({columns_str})
        VALUES ({placeholders})
        RETURNING *
    """
    
    try:
        result = db_query(query, values, fetch_one=True)
        return dict(result) if result else None
    except Exception as e:
        print(f"ERROR db_insert: {e}")
        return None


def db_select(table, where=None, params=None, fetch_one=False, order_by=None):
    """Выбирает данные из таблицы"""
    query = f"SELECT * FROM {table}"
    
    if where:
        query += f" WHERE {where}"
    if order_by:
        query += f" ORDER BY {order_by}"
    
    result = db_query(query, params, fetch_one=fetch_one, fetch_all=not fetch_one)
    
    if fetch_one:
        return dict(result) if result else None
    return [dict(row) for row in result] if result else []


def db_update(table, data, where, params=None):
    """Обновляет данные в таблице"""
    set_parts = [f"{key} = %s" for key in data.keys()]
    set_clause = ', '.join(set_parts)
    values = list(data.values())
    
    if params:
        values.extend(params)
    
    query = f"UPDATE {table} SET {set_clause} WHERE {where}"
    return db_query(query, values)


def get_next_mygov_doc_number():
    """Получает следующий номер документа для MyGov (последний + 1)"""
    query = """
        SELECT mygov_doc_number 
        FROM documents 
        WHERE type_doc = 2 
          AND mygov_doc_number IS NOT NULL 
          AND mygov_doc_number ~ '^[0-9]+$'
        ORDER BY CAST(mygov_doc_number AS INTEGER) DESC 
        LIMIT 1
    """
    result = db_query(query, fetch_one=True)
    
    if result and result.get('mygov_doc_number'):
        last_number = int(result['mygov_doc_number'])
        return str(last_number + 1)
    else:
        # Начальный номер для MyGov документов
        return '227817728'

