#!/bin/bash
# Быстрый тест конвертации DOCX в PDF

echo "=========================================="
echo "  Быстрый тест конвертации"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"
TEST_DIR="/tmp/lo_test_$$"
LO_CMD="/usr/bin/libreoffice"

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo ""
echo "1. Создание тестового DOCX..."
cd "$PROJECT_DIR"
source venv/bin/activate

python3 << PYTHON_EOF
from docx import Document
import os

doc = Document()
doc.add_paragraph('Test document for PDF conversion')
test_file = '$TEST_DIR/test.docx'
os.makedirs(os.path.dirname(test_file), exist_ok=True)
doc.save(test_file)
print(f"Created: {test_file}")
PYTHON_EOF

TEST_DOCX="$TEST_DIR/test.docx"
TEST_PDF="$TEST_DIR/test.pdf"

if [ ! -f "$TEST_DOCX" ]; then
    echo "✗ Failed to create DOCX"
    exit 1
fi

echo "✓ DOCX created: $TEST_DOCX"
ls -lh "$TEST_DOCX"

echo ""
echo "2. Конвертация от www-data..."
sudo -u www-data $LO_CMD --headless --nodefault --nolockcheck --nologo --norestore --invisible \
    --convert-to pdf --outdir "$TEST_DIR" "$TEST_DOCX" 2>&1 | head -5

if [ -f "$TEST_PDF" ]; then
    echo ""
    echo "✓ SUCCESS! PDF created:"
    ls -lh "$TEST_PDF"
    file "$TEST_PDF"
    rm -f "$TEST_PDF"
    echo ""
    echo "=========================================="
    echo "  ✓ КОНВЕРТАЦИЯ РАБОТАЕТ!"
    echo "=========================================="
else
    echo ""
    echo "✗ PDF not created"
    echo "Files in directory:"
    ls -la "$TEST_DIR"
fi

rm -rf "$TEST_DIR"


