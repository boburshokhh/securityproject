#!/bin/bash
# Исправление проблемы с git ownership

echo "=========================================="
echo "  Исправление проблемы с git ownership"
echo "=========================================="

PROJECT_DIR="/var/www/mygov-backend"

echo ""
echo "Проблема: Git обнаружил, что репозиторий принадлежит другому пользователю"
echo ""

# Вариант 1: Добавить в safe.directory
echo "1. Добавление директории в safe.directory..."
git config --global --add safe.directory "$PROJECT_DIR"

# Вариант 2: Изменить владельца (если нужно)
echo ""
echo "2. Проверка текущего владельца..."
ls -ld "$PROJECT_DIR/.git"

echo ""
echo "3. Если нужно изменить владельца на www-data:"
echo "   sudo chown -R www-data:www-data $PROJECT_DIR/.git"
echo "   Или для root:"
echo "   sudo chown -R root:root $PROJECT_DIR/.git"

echo ""
echo "=========================================="
echo "  Готово!"
echo "=========================================="
echo ""
echo "Теперь можно выполнить:"
echo "  cd $PROJECT_DIR"
echo "  git pull"


