#!/bin/bash
# Запуск Python скриптов с активированным venv

PROJECT_DIR="/var/www/mygov-backend"
SCRIPT="$1"

if [ -z "$SCRIPT" ]; then
    echo "Использование: ./run_with_venv.sh <script.py>"
    exit 1
fi

cd "$PROJECT_DIR"
source venv/bin/activate
python3 "$SCRIPT"

