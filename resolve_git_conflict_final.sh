    #!/bin/bash
    # Окончательное решение конфликта с fix_pycache_forever.sh

    cd /var/www/mygov-backend

    echo "=========================================="
    echo "  Решение конфликта Git"
    echo "=========================================="

echo ""
echo "1. Удаление локальных конфликтующих файлов..."
# Удаляем все скрипты, которые могут конфликтовать
rm -f fix_pycache_forever.sh 2>/dev/null || true
rm -f fix_pycache_git.sh 2>/dev/null || true
rm -f diagnose_pdf_issue.sh 2>/dev/null || true
rm -f fix_git_pycache.sh 2>/dev/null || true
rm -f resolve_git_conflict.sh 2>/dev/null || true
echo "✓ Конфликтующие файлы удалены"

    echo ""
    echo "2. Удаление всех __pycache__ файлов..."
    find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.pyc" -delete 2>/dev/null || true
    find . -name "*.pyo" -delete 2>/dev/null || true
    echo "✓ Файлы удалены"

    echo ""
    echo "3. Удаление из Git индекса..."
    git rm -r --cached app/services/__pycache__/ 2>/dev/null || true
    git rm --cached app/services/__pycache__/*.pyc 2>/dev/null || true
    git rm --cached app/__pycache__/*.pyc 2>/dev/null || true
    git rm --cached app/__pycache__/*.pyc 2>/dev/null || true
    echo "✓ Удалено из индекса"

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
    echo "5. Сброс всех локальных изменений в __pycache__..."
    git checkout -- app/services/__pycache__/ 2>/dev/null || true
    git checkout -- app/__pycache__/ 2>/dev/null || true
    git reset HEAD app/services/__pycache__/ 2>/dev/null || true
    git reset HEAD app/__pycache__/ 2>/dev/null || true
    echo "✓ Изменения сброшены"

echo ""
echo "6. Получение последних изменений..."
git fetch origin main

echo ""
echo "7. Сброс к состоянию origin/main (все локальные изменения будут потеряны)..."
git reset --hard origin/main

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "  ✓ ГОТОВО! Код обновлен"
    echo "=========================================="
    echo ""
    echo "Перезапустите сервис:"
    echo "  sudo systemctl restart mygov-backend"
else
    echo ""
    echo "=========================================="
    echo "  ✗ ОШИБКА при обновлении кода"
    echo "=========================================="
    echo ""
    echo "Проверьте статус:"
    echo "  git status"
fi

