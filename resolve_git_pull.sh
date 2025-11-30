#!/bin/bash
# Разрешение конфликта при git pull

echo "=========================================="
echo "  Разрешение конфликта git pull"
echo "=========================================="

cd /var/www/mygov-backend

echo ""
echo "Выберите действие:"
echo "1. Удалить локальные изменения в check_template_placeholders.py и test_template_fill.py"
echo "2. Закоммитить изменения"
echo "3. Сохранить изменения в stash"
echo ""
read -p "Выберите опцию (1-3): " choice

case $choice in
    1)
        echo "Удаление локальных изменений..."
        git checkout -- check_template_placeholders.py test_template_fill.py
        echo "✓ Изменения отменены"
        echo ""
        echo "Теперь можно выполнить: git pull"
        ;;
    2)
        echo "Коммит изменений..."
        git add check_template_placeholders.py test_template_fill.py
        git commit -m "Add template diagnostic scripts"
        echo "✓ Изменения закоммичены"
        echo ""
        echo "Теперь можно выполнить: git pull"
        ;;
    3)
        echo "Сохранение в stash..."
        git stash push -m "Local changes to diagnostic scripts" check_template_placeholders.py test_template_fill.py
        echo "✓ Изменения сохранены в stash"
        echo ""
        echo "Теперь можно выполнить: git pull"
        echo "Для восстановления: git stash pop"
        ;;
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

