import sys
import os
from datetime import datetime
from app.services.document import prepare_replacements

# Mock data
document_data = {
    'days_off_from': '2025-12-10',
    'days_off_to': '2025-12-15',
    'mygov_doc_number': '123456',
    'patient_name': 'Test Patient'
}

print("Testing prepare_replacements with:")
print(f"From: {document_data['days_off_from']}")
print(f"To: {document_data['days_off_to']}")

try:
    replacements = prepare_replacements(document_data)
    
    days_off_period = replacements.get('{{days_off_period}}')
    print(f"\nResult for {{days_off_period}}: '{days_off_period}'")
    
    expected = "10.12.2025 - 15.12.2025"
    
    if days_off_period == expected:
        print("SUCCESS: Result matches expected format.")
    else:
        print(f"FAILURE: Expected '{expected}', got '{days_off_period}'")

except Exception as e:
    print(f"Error: {e}")
