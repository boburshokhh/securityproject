#!/bin/bash
# Скрипт для диагностики проблем с LibreOffice на Ubuntu сервере

echo "=========================================="
echo "  Диагностика LibreOffice для конвертации"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"
SERVICE_USER="www-data"

echo ""
echo "1. Проверка установки LibreOffice..."
if command -v libreoffice &> /dev/null; then
    LO_PATH=$(which libreoffice)
    echo "✓ LibreOffice найден: $LO_PATH"
    libreoffice --version
else
    echo "✗ LibreOffice НЕ найден в PATH"
    echo "  Попробуем найти в стандартных местах..."
    for path in /usr/bin/libreoffice /usr/bin/soffice /usr/local/bin/libreoffice; do
        if [ -f "$path" ]; then
            echo "  Найден: $path"
            $path --version
        fi
    done
fi

echo ""
echo "2. Проверка доступности LibreOffice для www-data..."
if [ -f "$LO_PATH" ] || [ -f "/usr/bin/libreoffice" ]; then
    LO_CMD="${LO_PATH:-/usr/bin/libreoffice}"
    sudo -u $SERVICE_USER $LO_CMD --version 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ www-data может запустить LibreOffice"
    else
        echo "✗ www-data НЕ может запустить LibreOffice"
        echo "  Ошибка выше"
    fi
fi

echo ""
echo "3. Проверка headless режима..."
if [ -f "$LO_PATH" ] || [ -f "/usr/bin/libreoffice" ]; then
    LO_CMD="${LO_PATH:-/usr/bin/libreoffice}"
    echo "Тестирование headless режима..."
    sudo -u $SERVICE_USER $LO_CMD --headless --version 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ Headless режим работает"
    else
        echo "✗ Проблемы с headless режимом"
    fi
fi

echo ""
echo "4. Проверка зависимостей LibreOffice..."
echo "Проверка установленных пакетов:"
dpkg -l | grep -i libreoffice | head -5

echo ""
echo "Проверка необходимых библиотек:"
for lib in libcairo2 libx11-6 libxext6 libxrender1; do
    if dpkg -l | grep -q "^ii.*$lib"; then
        echo "  ✓ $lib установлен"
    else
        echo "  ✗ $lib НЕ установлен"
    fi
done

echo ""
echo "5. Проверка прав на временные директории..."
TEMP_DIRS=("/tmp" "/var/tmp" "$PROJECT_DIR/uploads/documents")
for temp_dir in "${TEMP_DIRS[@]}"; do
    if [ -d "$temp_dir" ]; then
        echo "Проверка: $temp_dir"
        ls -ld "$temp_dir"
        sudo -u $SERVICE_USER touch "$temp_dir/.test_write_$$" 2>&1
        if [ $? -eq 0 ]; then
            echo "  ✓ Запись возможна"
            sudo -u $SERVICE_USER rm -f "$temp_dir/.test_write_$$"
        else
            echo "  ✗ Запись НЕ возможна"
        fi
    else
        echo "  ✗ Директория не существует: $temp_dir"
    fi
done

echo ""
echo "6. Тест конвертации DOCX в PDF..."
cd "$PROJECT_DIR"
source venv/bin/activate

# Создаем тестовый DOCX файл
TEST_DOCX="/tmp/test_libreoffice_$$.docx"
TEST_PDF="/tmp/test_libreoffice_$$.pdf"

echo "Создание тестового DOCX..."
python3 << 'PYTHON_EOF'
from docx import Document
import os

doc = Document()
doc.add_paragraph('Test document for LibreOffice conversion')
test_file = '/tmp/test_libreoffice_' + str(os.getpid()) + '.docx'
doc.save(test_file)
print(f"✓ Тестовый файл создан: {test_file}")
PYTHON_EOF

if [ -f "$TEST_DOCX" ]; then
    echo "Тестовый файл: $TEST_DOCX"
    ls -lh "$TEST_DOCX"
    
    # Пробуем конвертировать от имени root
    echo ""
    echo "Тест конвертации от root:"
    LO_CMD="${LO_PATH:-/usr/bin/libreoffice}"
    $LO_CMD --headless --convert-to pdf --outdir /tmp "$TEST_DOCX" 2>&1
    
    if [ -f "$TEST_PDF" ]; then
        echo "✓ Конвертация от root успешна"
        ls -lh "$TEST_PDF"
        rm -f "$TEST_PDF"
    else
        echo "✗ Конвертация от root НЕ удалась"
    fi
    
    # Пробуем конвертировать от имени www-data
    echo ""
    echo "Тест конвертации от www-data:"
    sudo -u $SERVICE_USER $LO_CMD --headless --convert-to pdf --outdir /tmp "$TEST_DOCX" 2>&1
    
    if [ -f "$TEST_PDF" ]; then
        echo "✓ Конвертация от www-data успешна"
        ls -lh "$TEST_PDF"
        sudo -u $SERVICE_USER rm -f "$TEST_PDF"
    else
        echo "✗ Конвертация от www-data НЕ удалась"
        echo "  Это основная проблема!"
    fi
    
    # Очистка
    rm -f "$TEST_DOCX"
else
    echo "✗ Не удалось создать тестовый файл"
fi

echo ""
echo "7. Проверка переменных окружения для www-data..."
echo "HOME директория www-data:"
sudo -u $SERVICE_USER sh -c 'echo $HOME'
echo ""
echo "TMPDIR:"
sudo -u $SERVICE_USER sh -c 'echo ${TMPDIR:-/tmp}'

echo ""
echo "8. Проверка кода конвертации в проекте..."
if [ -f "$PROJECT_DIR/app/services/document.py" ]; then
    echo "Функция find_libreoffice:"
    grep -A 20 "def find_libreoffice" "$PROJECT_DIR/app/services/document.py" | head -25
    
    echo ""
    echo "Функция convert_docx_to_pdf:"
    grep -A 5 "def convert_docx_to_pdf" "$PROJECT_DIR/app/services/document.py" | head -10
fi

echo ""
echo "9. Проверка логов приложения на ошибки LibreOffice..."
echo "Последние упоминания LibreOffice в логах:"
sudo journalctl -u mygov-backend --since "1 hour ago" | grep -i "libreoffice\|soffice\|pdf\|convert" | tail -20

echo ""
echo "10. Тест через Python напрямую..."
cd "$PROJECT_DIR"
source venv/bin/activate
python3 << 'PYTHON_EOF'
import os
import subprocess
import shutil

print("Поиск LibreOffice...")
libreoffice_cmd = None

# Проверяем стандартные пути
paths = [
    '/usr/bin/libreoffice',
    '/usr/bin/soffice',
    '/usr/local/bin/libreoffice',
]

for path in paths:
    if os.path.exists(path):
        libreoffice_cmd = path
        print(f"✓ Найден: {path}")
        break

# Пробуем через which
if not libreoffice_cmd:
    libreoffice_cmd = shutil.which('libreoffice') or shutil.which('soffice')
    if libreoffice_cmd:
        print(f"✓ Найден через PATH: {libreoffice_cmd}")

if libreoffice_cmd:
    print(f"\nТест версии: {libreoffice_cmd} --version")
    result = subprocess.run([libreoffice_cmd, '--version'], 
                          capture_output=True, text=True, timeout=10)
    print(result.stdout)
    if result.returncode != 0:
        print(f"Ошибка: {result.stderr}")
    
    print(f"\nТест headless: {libreoffice_cmd} --headless --version")
    result = subprocess.run([libreoffice_cmd, '--headless', '--version'], 
                          capture_output=True, text=True, timeout=10)
    if result.returncode == 0:
        print("✓ Headless режим работает")
    else:
        print(f"✗ Headless режим не работает: {result.stderr}")
else:
    print("✗ LibreOffice не найден!")
PYTHON_EOF

echo ""
echo "=========================================="
echo "  Диагностика завершена"
echo "=========================================="
echo ""
echo "Возможные решения:"
echo "1. Если LibreOffice не найден: sudo apt-get install libreoffice"
echo "2. Если проблемы с правами: sudo chown -R www-data:www-data $PROJECT_DIR"
echo "3. Если проблемы с headless: проверьте зависимости"
echo "4. Если проблемы с путями: проверьте функцию find_libreoffice в коде"


