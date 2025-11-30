#!/bin/bash
# Исправление проблемы конвертации DOCX в PDF

echo "=========================================="
echo "  Исправление конвертации DOCX в PDF"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"

echo ""
echo "1. Проверка LibreOffice:"
echo "=========================================="

# Проверяем установку LibreOffice
if command -v libreoffice &> /dev/null; then
    echo "✓ LibreOffice найден: $(which libreoffice)"
    libreoffice --version
elif command -v soffice &> /dev/null; then
    echo "✓ soffice найден: $(which soffice)"
    soffice --version
else
    echo "✗ LibreOffice не найден"
    echo ""
    echo "Установка LibreOffice..."
    apt-get update
    apt-get install -y libreoffice libreoffice-writer-nogui
    echo "✓ LibreOffice установлен"
fi

echo ""
echo "2. Проверка зависимостей:"
echo "=========================================="

# Проверяем необходимые пакеты
REQUIRED_PACKAGES=(
    "libreoffice-core"
    "libreoffice-writer-nogui"
    "fonts-liberation"
    "fonts-dejavu"
)

for package in "${REQUIRED_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii.*$package"; then
        echo "✓ $package установлен"
    else
        echo "⚠ $package не установлен"
    fi
done

echo ""
echo "3. Проверка прав доступа:"
echo "=========================================="

# Проверяем права на /tmp
if [ -w /tmp ]; then
    echo "✓ /tmp доступен для записи"
else
    echo "✗ /tmp недоступен для записи"
    chmod 1777 /tmp
    echo "✓ Права на /tmp исправлены"
fi

# Проверяем права www-data на /tmp
if sudo -u www-data test -w /tmp; then
    echo "✓ www-data может писать в /tmp"
else
    echo "⚠ www-data не может писать в /tmp"
fi

echo ""
echo "4. Тест конвертации:"
echo "=========================================="

cd "$PROJECT_DIR"
source venv/bin/activate

# Создаем тестовый DOCX
python3 << 'PYTHON_EOF'
from docx import Document
import os

test_docx = '/tmp/test_conversion.docx'
doc = Document()
doc.add_paragraph('Test Document for PDF Conversion')
doc.save(test_docx)
print(f"✓ Тестовый DOCX создан: {test_docx}")

# Пробуем конвертировать
import subprocess
import os

libreoffice_cmd = None
for cmd in ['libreoffice', 'soffice', '/usr/bin/libreoffice', '/usr/bin/soffice']:
    if os.path.exists(cmd) or os.system(f"which {cmd} > /dev/null 2>&1") == 0:
        libreoffice_cmd = cmd
        break

if not libreoffice_cmd:
    # Пробуем найти через which
    import shutil
    libreoffice_cmd = shutil.which('libreoffice') or shutil.which('soffice')

if libreoffice_cmd:
    print(f"✓ LibreOffice найден: {libreoffice_cmd}")
    
    # Устанавливаем переменные окружения
    env = os.environ.copy()
    env['HOME'] = '/var/www'
    env['TMPDIR'] = '/tmp'
    env['TMP'] = '/tmp'
    env['TEMP'] = '/tmp'
    env['XDG_CACHE_HOME'] = '/tmp/.cache'
    env['XDG_CONFIG_HOME'] = '/tmp/.config'
    env['XDG_DATA_HOME'] = '/tmp/.local/share'
    
    # Конвертируем
    cmd = [
        libreoffice_cmd,
        '--headless',
        '--nodefault',
        '--nolockcheck',
        '--nologo',
        '--norestore',
        '--invisible',
        '--convert-to', 'pdf',
        '--outdir', '/tmp',
        test_docx
    ]
    
    print(f"Запуск команды: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60, env=env)
    
    print(f"Return code: {result.returncode}")
    if result.stdout:
        print(f"STDOUT: {result.stdout[:200]}")
    if result.stderr:
        print(f"STDERR: {result.stderr[:200]}")
    
    # Проверяем результат
    test_pdf = '/tmp/test_conversion.pdf'
    if os.path.exists(test_pdf):
        size = os.path.getsize(test_pdf)
        print(f"✓ PDF создан успешно: {test_pdf} (размер: {size} bytes)")
        os.remove(test_pdf)
    else:
        print(f"✗ PDF не создан")
        # Проверяем, что есть в /tmp
        pdf_files = [f for f in os.listdir('/tmp') if f.endswith('.pdf')]
        if pdf_files:
            print(f"Найдены PDF файлы: {pdf_files}")
else:
    print("✗ LibreOffice не найден")

# Удаляем тестовый DOCX
if os.path.exists(test_docx):
    os.remove(test_docx)
PYTHON_EOF

echo ""
echo "5. Проверка systemd конфигурации:"
echo "=========================================="

if grep -q "TMPDIR" /etc/systemd/system/mygov-backend.service; then
    echo "✓ TMPDIR настроен в systemd"
else
    echo "⚠ TMPDIR не настроен в systemd"
    echo "  Добавьте в Environment: TMPDIR=/tmp"
fi

if grep -q "HOME" /etc/systemd/system/mygov-backend.service; then
    echo "✓ HOME настроен в systemd"
else
    echo "⚠ HOME не настроен в systemd"
    echo "  Добавьте в Environment: HOME=/var/www"
fi

echo ""
echo "6. Просмотр последних ошибок конвертации:"
echo "=========================================="
sudo journalctl -u mygov-backend --since "1 hour ago" | grep -E "\[PDF_CONV:" | tail -20

echo ""
echo "=========================================="
echo "  Диагностика завершена"
echo "=========================================="
echo ""
echo "Если проблема не решена, проверьте:"
echo "1. Логи: sudo journalctl -u mygov-backend -f | grep PDF_CONV"
echo "2. Права на /tmp: ls -ld /tmp"
echo "3. Перезапустите сервис: sudo systemctl restart mygov-backend"

