"""
Система подробного логирования для MyGov Backend
"""
import logging
import sys
from datetime import datetime
from functools import wraps
import traceback

# Настройка форматирования логов
LOG_FORMAT = '%(asctime)s [%(levelname)s] [%(name)s:%(lineno)d] %(message)s'
DATE_FORMAT = '%Y-%m-%d %H:%M:%S'

# Создаем корневой логгер
logger = logging.getLogger('mygov')
logger.setLevel(logging.DEBUG)

# Обработчик для консоли (stdout)
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.DEBUG)
console_formatter = logging.Formatter(LOG_FORMAT, DATE_FORMAT)
console_handler.setFormatter(console_formatter)
logger.addHandler(console_handler)

# Обработчик для файла (если нужно)
def setup_file_logger(log_file_path):
    """Настраивает файловое логирование"""
    file_handler = logging.FileHandler(log_file_path)
    file_handler.setLevel(logging.DEBUG)
    file_formatter = logging.Formatter(LOG_FORMAT, DATE_FORMAT)
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)
    return file_handler


def log_function_call(func):
    """Декоратор для логирования вызовов функций"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        func_name = func.__name__
        logger.debug(f"→ {func_name} вызвана с args={len(args)}, kwargs={list(kwargs.keys())}")
        try:
            start_time = datetime.now()
            result = func(*args, **kwargs)
            duration = (datetime.now() - start_time).total_seconds()
            logger.debug(f"✓ {func_name} завершена за {duration:.2f}s")
            return result
        except Exception as e:
            logger.error(f"✗ {func_name} ошибка: {e}")
            logger.debug(f"Traceback {func_name}:\n{traceback.format_exc()}")
            raise
    return wrapper


def log_document_generation(step, message, **kwargs):
    """Логирование этапов генерации документа"""
    extra_info = " | ".join([f"{k}={v}" for k, v in kwargs.items() if v is not None])
    if extra_info:
        logger.info(f"[DOC_GEN:{step}] {message} | {extra_info}")
    else:
        logger.info(f"[DOC_GEN:{step}] {message}")


def log_pdf_conversion(step, message, **kwargs):
    """Логирование этапов конвертации PDF"""
    extra_info = " | ".join([f"{k}={v}" for k, v in kwargs.items() if v is not None])
    if extra_info:
        logger.info(f"[PDF_CONV:{step}] {message} | {extra_info}")
    else:
        logger.info(f"[PDF_CONV:{step}] {message}")


def log_database_operation(operation, table, **kwargs):
    """Логирование операций с БД"""
    extra_info = " | ".join([f"{k}={v}" for k, v in kwargs.items() if v is not None])
    if extra_info:
        logger.debug(f"[DB:{operation}] table={table} | {extra_info}")
    else:
        logger.debug(f"[DB:{operation}] table={table}")


def log_storage_operation(operation, **kwargs):
    """Логирование операций с хранилищем"""
    extra_info = " | ".join([f"{k}={v}" for k, v in kwargs.items() if v is not None])
    if extra_info:
        logger.debug(f"[STORAGE:{operation}] {extra_info}")
    else:
        logger.debug(f"[STORAGE:{operation}]")


def log_error_with_context(error, context=None):
    """Логирование ошибок с контекстом"""
    error_msg = f"[ERROR] {type(error).__name__}: {str(error)}"
    if context:
        error_msg += f" | Context: {context}"
    logger.error(error_msg)
    logger.debug(f"Traceback:\n{traceback.format_exc()}")


# Экспорт основных функций
__all__ = [
    'logger',
    'setup_file_logger',
    'log_function_call',
    'log_document_generation',
    'log_pdf_conversion',
    'log_database_operation',
    'log_storage_operation',
    'log_error_with_context',
]

