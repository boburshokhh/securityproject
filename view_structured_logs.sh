#!/bin/bash
# Просмотр структурированных логов

echo "=========================================="
echo "  Просмотр структурированных логов"
echo "=========================================="
echo ""
echo "Выберите фильтр:"
echo "1. Все логи генерации документов [DOC_GEN:*]"
echo "2. Все логи конвертации PDF [PDF_CONV:*]"
echo "3. Только ошибки [ERROR]"
echo "4. Логи по этапам (START, SUCCESS, FAIL)"
echo "5. Логи LibreOffice [LIBREOFFICE:*]"
echo "6. Логи БД [DB:*]"
echo "7. Логи хранилища [STORAGE:*]"
echo "8. Все логи в реальном времени"
echo "9. Последние 100 строк"
echo ""
read -p "Выберите опцию (1-9): " choice

case $choice in
    1)
        echo "Логи генерации документов:"
        sudo journalctl -u mygov-backend -f | grep --line-buffered "\[DOC_GEN:"
        ;;
    2)
        echo "Логи конвертации PDF:"
        sudo journalctl -u mygov-backend -f | grep --line-buffered "\[PDF_CONV:"
        ;;
    3)
        echo "Только ошибки:"
        sudo journalctl -u mygov-backend -f | grep --line-buffered -i "\[ERROR\]\|ERROR\|Exception\|Traceback"
        ;;
    4)
        echo "Логи по этапам:"
        sudo journalctl -u mygov-backend -f | grep --line-buffered -E "\[DOC_GEN:(START|SUCCESS|FAIL|ERROR)\]|\[PDF_CONV:(START|SUCCESS|FAIL|ERROR)\]"
        ;;
    5)
        echo "Логи LibreOffice:"
        sudo journalctl -u mygov-backend -f | grep --line-buffered "\[LIBREOFFICE:"
        ;;
    6)
        echo "Логи БД:"
        sudo journalctl -u mygov-backend -f | grep --line-buffered "\[DB:"
        ;;
    7)
        echo "Логи хранилища:"
        sudo journalctl -u mygov-backend -f | grep --line-buffered "\[STORAGE:"
        ;;
    8)
        echo "Все логи в реальном времени:"
        sudo journalctl -u mygov-backend -f
        ;;
    9)
        echo "Последние 100 строк:"
        sudo journalctl -u mygov-backend -n 100 --no-pager
        ;;
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

