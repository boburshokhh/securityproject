#!/bin/bash
# Исправление проблемы с __pycache__ в git

echo "=========================================="
echo "  Исправление проблемы с __pycache__"
echo "=========================================="

cd /var/www/mygov-backend

echo ""
echo "1. Удаление __pycache__ из индекса git..."
git rm -r --cached app/__pycache__/ 2>/dev/null || true
git rm -r --cached app/routes/__pycache__/ 2>/dev/null || true
git rm -r --cached app/services/__pycache__/ 2>/dev/null || true
git rm -r --cached app/utils/__pycache__/ 2>/dev/null || true

# Удаляем все __pycache__ рекурсивно
find . -type d -name __pycache__ -exec git rm -r --cached {} + 2>/dev/null || true

echo "✓ __pycache__ удалены из индекса"

echo ""
echo "2. Проверка .gitignore..."
if [ -f ".gitignore" ]; then
    if grep -q "__pycache__" .gitignore; then
        echo "✓ __pycache__ уже в .gitignore"
    else
        echo "Добавление __pycache__ в .gitignore..."
        echo "" >> .gitignore
        echo "# Python cache" >> .gitignore
        echo "__pycache__/" >> .gitignore
        echo "*.py[cod]" >> .gitignore
        echo "✓ Добавлено в .gitignore"
    fi
else
    echo "Создание .gitignore..."
    cat > .gitignore << 'EOF'
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# Environments
.env
.venv
env/
venv/
ENV/

# Project specific
uploads/
*.db
.DS_Store
EOF
    echo "✓ .gitignore создан"
fi

echo ""
echo "3. Коммит изменений (если нужно)..."
if [ -n "$(git status --porcelain)" ]; then
    echo "Есть изменения для коммита"
    read -p "Закоммитить изменения? (y/n): " answer
    if [ "$answer" = "y" ]; then
        git add .gitignore
        git commit -m "Remove __pycache__ from git tracking"
        echo "✓ Изменения закоммичены"
    else
        echo "Пропуск коммита"
    fi
else
    echo "Нет изменений для коммита"
fi

echo ""
echo "4. Настройка стратегии слияния..."
git config pull.rebase false

echo ""
echo "5. Выполнение git pull..."
git pull origin main || {
    echo ""
    echo "⚠ Обнаружены расходящиеся ветки"
    echo "Выберите действие:"
    echo "1. Сбросить локальные изменения и обновиться с удаленного (рекомендуется для сервера)"
    echo "2. Сделать merge"
    echo "3. Сделать rebase"
    read -p "Выберите опцию (1-3): " choice
    
    case $choice in
        1)
            echo "Сброс локальных изменений..."
            git fetch origin
            git reset --hard origin/main
            echo "✓ Обновлено с удаленного репозитория"
            ;;
        2)
            echo "Выполнение merge..."
            git pull --no-rebase origin main
            ;;
        3)
            echo "Выполнение rebase..."
            git pull --rebase origin main
            ;;
        *)
            echo "Отмена. Выполните вручную:"
            echo "  git fetch origin"
            echo "  git reset --hard origin/main  # для сброса локальных изменений"
            echo "  или git pull --no-rebase origin main  # для merge"
            ;;
    esac
}

echo ""
echo "=========================================="
echo "  Готово!"
echo "=========================================="

