
import sys
import os
from app.services.database import db_query

# Add the current directory to sys.path to import app modules
sys.path.append(os.getcwd())

def inspect_table():
    try:
        query = """
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'documents';
        """
        result = db_query(query, fetch_all=True)
        columns = [row['column_name'] for row in result]
        print("Existing columns:", columns)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    inspect_table()

