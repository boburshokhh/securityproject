#!/usr/bin/env python3
"""
MyGov Backend - Точка входа
"""
import sys
import os

# Добавляем корневую директорию в путь поиска модулей
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app
from app.config import DEBUG, PORT

app = create_app()

if __name__ == '__main__':
    print(f"""
╔══════════════════════════════════════════╗
║       MyGov Backend Server               ║
║                                          ║
║  Port: {PORT}                              ║
║  Debug: {DEBUG}                            ║
║                                          ║
║  API: http://localhost:{PORT}/api          ║
║  Health: http://localhost:{PORT}/health    ║
╚══════════════════════════════════════════╝
    """)
    
    app.run(
        host='0.0.0.0',
        port=PORT,
        debug=DEBUG
    )

