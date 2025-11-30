#!/bin/bash
# Окончательное решение проблемы с __pycache__

cd /var/www/mygov-backend

echo "=========================================="
echo "  Окончательное исправление __pycache__"
echo "=========================================="

echo ""
echo "1. Удаление всех __pycache__ файлов..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.pyo" -delete 2>/dev/null || true

echo "✓ Файлы удалены"

echo ""
echo "2. Удаление из Git индекса..."
git rm -r --cached app/services/__pycache__/ 2>/dev/null || true
git rm --cached app/services/__pycache__/*.pyc 2>/dev/null || true
git rm --cached app/__pycache__/*.pyc 2>/dev/null || true

echo "✓ Удалено из индекса"

echo ""
echo "3. Сброс изменений в Git..."
git checkout -- app/services/__pycache__/ 2>/dev/null || true
git reset HEAD app/services/__pycache__/ 2>/dev/null || true

echo "✓ Изменения сброшены"

echo ""
echo "4. Проверка .gitignore..."
if ! grep -q "^__pycache__" .gitignore 2>/dev/null; then
    echo "Добавление в .gitignore..."
    cat >> .gitignore << 'EOF'

# Python cache files
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
EOF
    echo "✓ .gitignore обновлен"
else
    echo "✓ .gitignore уже настроен"
fi

echo ""
echo "5. Обновление кода..."
git pull origin main

echo ""
echo "=========================================="
echo "  ✓ ГОТОВО! Код обновлен"
echo "=========================================="
echo ""
echo "Перезапустите сервис:"
echo "  sudo systemctl restart mygov-backend"

