#!/bin/bash
# Скрипт для просмотра логов в реальном времени с фильтрацией

echo "=========================================="
echo "  Просмотр логов MyGov Backend"
echo "=========================================="
echo ""
echo "Выберите режим:"
echo "1. Все логи в реальном времени (journalctl -f)"
echo "2. Только ошибки (ERROR, Exception, Traceback)"
echo "3. Только DEBUG сообщения"
echo "4. Логи с фильтром по LibreOffice/PDF"
echo "5. Логи с фильтром по generate_document"
echo "6. Последние 100 строк"
echo "7. Поиск по тексту (введите текст)"
echo ""
read -p "Выберите опцию (1-7): " choice

case $choice in
    1)
        echo ""
        echo "Просмотр всех логов в реальном времени..."
        echo "Нажмите Ctrl+C для выхода"
        echo ""
        sudo journalctl -u mygov-backend -f
        ;;
    2)
        echo ""
        echo "Просмотр только ошибок в реальном времени..."
        echo "Нажмите Ctrl+C для выхода"
        echo ""
        sudo journalctl -u mygov-backend -f | grep --line-buffered -i -E "error|exception|traceback|failed|permission"
        ;;
    3)
        echo ""
        echo "Просмотр DEBUG сообщений в реальном времени..."
        echo "Нажмите Ctrl+C для выхода"
        echo ""
        sudo journalctl -u mygov-backend -f | grep --line-buffered "\[DEBUG\]"
        ;;
    4)
        echo ""
        echo "Просмотр логов LibreOffice/PDF в реальном времени..."
        echo "Нажмите Ctrl+C для выхода"
        echo ""
        sudo journalctl -u mygov-backend -f | grep --line-buffered -i -E "libreoffice|soffice|pdf|convert|docx"
        ;;
    5)
        echo ""
        echo "Просмотр логов generate_document в реальном времени..."
        echo "Нажмите Ctrl+C для выхода"
        echo ""
        sudo journalctl -u mygov-backend -f | grep --line-buffered -i -E "generate_document|create_document|fill_docx"
        ;;
    6)
        echo ""
        echo "Последние 100 строк логов:"
        echo ""
        sudo journalctl -u mygov-backend -n 100 --no-pager
        ;;
    7)
        read -p "Введите текст для поиска: " search_text
        echo ""
        echo "Поиск '$search_text' в реальном времени..."
        echo "Нажмите Ctrl+C для выхода"
        echo ""
        sudo journalctl -u mygov-backend -f | grep --line-buffered -i "$search_text"
        ;;
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

