#!/bin/bash
# Тест реальной конвертации DOCX в PDF

echo "=========================================="
echo "  Тест конвертации DOCX → PDF"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"
SERVICE_USER="www-data"
TEST_DIR="/tmp/libreoffice_test_$$"
LO_CMD="/usr/bin/libreoffice"

# Создаем тестовую директорию
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo ""
echo "1. Создание тестового DOCX файла..."
cd "$PROJECT_DIR"
source venv/bin/activate

python3 << 'PYTHON_EOF'
from docx import Document
import os

doc = Document()
doc.add_paragraph('Тестовый документ для конвертации в PDF')
doc.add_paragraph('Это проверка работы LibreOffice на сервере.')
test_file = f'/tmp/libreoffice_test_{os.getpid()}/test.docx'
os.makedirs(os.path.dirname(test_file), exist_ok=True)
doc.save(test_file)
print(f"✓ Тестовый файл создан: {test_file}")
PYTHON_EOF

TEST_DOCX="$TEST_DIR/test.docx"
TEST_PDF="$TEST_DIR/test.pdf"

if [ ! -f "$TEST_DOCX" ]; then
    echo "✗ Не удалось создать тестовый DOCX"
    exit 1
fi

echo "✓ Файл создан: $TEST_DOCX"
ls -lh "$TEST_DOCX"

echo ""
echo "2. Конвертация от root..."
$LO_CMD --headless --nodefault --nolockcheck --nologo --norestore --invisible \
    --convert-to pdf --outdir "$TEST_DIR" "$TEST_DOCX" 2>&1

if [ -f "$TEST_PDF" ]; then
    echo "✓ Конвертация от root успешна!"
    ls -lh "$TEST_PDF"
    file "$TEST_PDF"
    rm -f "$TEST_PDF"
else
    echo "✗ Конвертация от root не удалась"
fi

echo ""
echo "3. Конвертация от www-data..."
sudo -u $SERVICE_USER $LO_CMD --headless --nodefault --nolockcheck --nologo --norestore --invisible \
    --convert-to pdf --outdir "$TEST_DIR" "$TEST_DOCX" 2>&1

if [ -f "$TEST_PDF" ]; then
    echo "✓ Конвертация от www-data успешна!"
    ls -lh "$TEST_PDF"
    file "$TEST_PDF"
    echo ""
    echo "=========================================="
    echo "  ✓ ВСЕ РАБОТАЕТ!"
    echo "=========================================="
else
    echo "✗ Конвертация от www-data не удалась"
    echo ""
    echo "Проверьте логи выше для деталей"
fi

# Очистка
rm -rf "$TEST_DIR"

echo ""
echo "4. Исправление проблемы с dconf..."
sudo mkdir -p /var/www/.cache/dconf
sudo chown -R www-data:www-data /var/www/.cache
sudo chmod -R 755 /var/www/.cache

echo "✓ Директория dconf создана"

