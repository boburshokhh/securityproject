#!/bin/bash
# Проверка наличия шаблона

echo "=========================================="
echo "  Проверка шаблона документа"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"

echo ""
echo "1. Поиск шаблона template_mygov.docx..."
find "$PROJECT_DIR" -name "template_mygov.docx" -type f 2>/dev/null

echo ""
echo "2. Проверка стандартных путей..."
PATHS=(
    "$PROJECT_DIR/templates/template_mygov.docx"
    "$PROJECT_DIR/app/templates/template_mygov.docx"
    "/var/www/mygov-backend/templates/template_mygov.docx"
)

for path in "${PATHS[@]}"; do
    if [ -f "$path" ]; then
        echo "✓ Найден: $path"
        ls -lh "$path"
    else
        echo "✗ Не найден: $path"
    fi
done

echo ""
echo "3. Содержимое директории templates:"
if [ -d "$PROJECT_DIR/templates" ]; then
    ls -la "$PROJECT_DIR/templates/"
else
    echo "✗ Директория templates не существует"
fi

echo ""
echo "4. Содержимое директории app/templates (если существует):"
if [ -d "$PROJECT_DIR/app/templates" ]; then
    ls -la "$PROJECT_DIR/app/templates/"
else
    echo "  Директория app/templates не существует"
fi

echo ""
echo "=========================================="
echo "  Если шаблон не найден, скопируйте его:"
echo "  cp template_mygov.docx $PROJECT_DIR/templates/"
echo "=========================================="

