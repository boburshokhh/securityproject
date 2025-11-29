"""
MyGov Backend - Генерация простого QR-кода
Использует библиотеку qrcode (без стилизации)
"""
import qrcode
from PIL import Image
from io import BytesIO


def generate_simple_qr(url, box_size=3, border=1):
    """
    Генерирует простой черно-белый QR-код
    
    Args:
        url: URL для кодирования
        box_size: Размер каждого квадрата (по умолчанию 3)
        border: Размер рамки (по умолчанию 1)
    
    Returns:
        PIL.Image: Изображение QR-кода
    """
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=box_size,
        border=border,
    )
    qr.add_data(url)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    
    # Конвертируем в RGBA для совместимости
    if hasattr(img, 'convert'):
        img = img.convert('RGBA')
    
    return img


def save_qr_to_bytes(qr_img, format='PNG'):
    """
    Сохраняет QR-код в байты
    
    Args:
        qr_img: PIL.Image QR-кода
        format: Формат изображения (по умолчанию PNG)
    
    Returns:
        bytes: Байты изображения
    """
    buffer = BytesIO()
    qr_img.save(buffer, format=format)
    buffer.seek(0)
    return buffer.getvalue()


def save_qr_to_file(qr_img, file_path):
    """
    Сохраняет QR-код в файл
    
    Args:
        qr_img: PIL.Image QR-кода
        file_path: Путь к файлу
    
    Returns:
        str: Путь к сохраненному файлу
    """
    qr_img.save(file_path, 'PNG')
    return file_path

