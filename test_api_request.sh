#!/bin/bash
# Скрипт для тестирования API запроса с логированием

echo "=========================================="
echo "  Тест API запроса на генерацию документа"
echo "=========================================="

API_URL="${1:-https://backend2.dmed.gubkin.uz/api/documents/generate}"

echo ""
echo "URL: $API_URL"
echo ""

# Проверяем наличие токена
if [ -z "$TOKEN" ]; then
    echo "⚠ Переменная TOKEN не установлена"
    echo ""
    echo "Использование:"
    echo "  export TOKEN='your_jwt_token_here'"
    echo "  ./test_api_request.sh"
    echo ""
    echo "Или передайте токен как второй аргумент:"
    echo "  ./test_api_request.sh https://backend2.dmed.gubkin.uz/api/documents/generate 'your_token'"
    echo ""
    
    if [ -n "$2" ]; then
        TOKEN="$2"
        echo "Используется токен из аргумента"
    else
        echo "Попробуем выполнить запрос без токена (может не сработать)..."
        TOKEN=""
    fi
fi

echo ""
echo "Выполнение запроса..."
echo ""

# Тестовые данные
DATA='{
  "patient_name": "Тестовый Пациент",
  "gender": "M",
  "age": 30,
  "jshshir": "12345678901234",
  "address": "Тестовый адрес",
  "organization": "Тестовая Организация",
  "diagnosis": "Тестовый диагноз",
  "doctor_name": "Тестовый Доктор",
  "doctor_position": "Врач",
  "issue_date": "2025-11-29",
  "days_off_from": "2025-11-29",
  "days_off_to": "2025-12-05"
}'

if [ -n "$TOKEN" ]; then
    curl -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d "$DATA" \
        -v \
        -w "\n\nHTTP Status: %{http_code}\nTime: %{time_total}s\n"
else
    curl -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -d "$DATA" \
        -v \
        -w "\n\nHTTP Status: %{http_code}\nTime: %{time_total}s\n"
fi

echo ""
echo "=========================================="
echo "  Запрос выполнен"
echo "=========================================="
echo ""
echo "Проверьте логи сервиса:"
echo "  sudo journalctl -u mygov-backend -f"
echo ""
echo "Или последние логи:"
echo "  sudo journalctl -u mygov-backend -n 50"

