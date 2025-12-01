"""
MyGov Backend - Публичные маршруты для доступа к документам
"""
from flask import Blueprint, request, jsonify, url_for
from app.services.database import db_select
from app.utils.logger import logger, log_error_with_context

access_bp = Blueprint('access', __name__)


@access_bp.route('/<document_uuid>', methods=['GET'])
def get_document_by_uuid(document_uuid):
    """Получение информации о документе по UUID (публичный эндпоинт)"""
    try:
        document = db_select('documents', 'uuid = %s AND type_doc = 2', [document_uuid], fetch_one=True)
        
        if not document:
            return jsonify({'success': False, 'error': 'Документ не найден'}), 404
        
        # Форматируем даты
        issue_date_str = ''
        days_off_str = ''
        
        if document.get('issue_date'):
            try:
                if hasattr(document['issue_date'], 'isoformat'):
                    issue_date_str = document['issue_date'].isoformat()
                else:
                    issue_date_str = str(document['issue_date'])
            except:
                issue_date_str = str(document.get('issue_date', ''))
        
        if document.get('days_off_from') and document.get('days_off_to'):
            try:
                days_off_from = document['days_off_from']
                days_off_to = document['days_off_to']
                if hasattr(days_off_from, 'isoformat'):
                    days_off_str = f"{days_off_from.isoformat()} - {days_off_to.isoformat()}"
                else:
                    days_off_str = f"{days_off_from} - {days_off_to}"
            except:
                days_off_str = f"{document.get('days_off_from', '')} - {document.get('days_off_to', '')}"
        
        # Генерируем полные URL для PDF
        doc_id = document.get('id')
        pdf_url = None
        pdf_url_by_uuid = None
        
        if doc_id:
            try:
                # URL для скачивания по ID
                pdf_url = url_for('documents.download_document', doc_id=doc_id, _external=True)
            except Exception as e:
                logger.warning(f"Не удалось сгенерировать pdf_url: {e}")
        
        if document_uuid:
            try:
                # URL для скачивания по UUID (если есть такой endpoint)
                # Пока используем тот же endpoint, что и по ID
                pdf_url_by_uuid = url_for('documents.download_document', doc_id=doc_id, _external=True) if doc_id else None
            except Exception as e:
                logger.warning(f"Не удалось сгенерировать pdf_url_by_uuid: {e}")
        
        return jsonify({
            'success': True,
            'document': {
                'id': document.get('id'),
                'doc_number': document.get('mygov_doc_number', ''),
                'patient_name': document.get('patient_name', ''),
                'gender': document.get('gender', ''),
                'age': document.get('age', ''),
                'jshshir': document.get('jshshir', ''),
                'address': document.get('address', ''),
                'attached_medical_institution': document.get('attached_medical_institution', ''),
                'diagnosis': document.get('diagnosis', ''),
                'diagnosis_icd10_code': document.get('diagnosis_icd10_code', ''),
                'final_diagnosis': document.get('final_diagnosis', ''),
                'final_diagnosis_icd10_code': document.get('final_diagnosis_icd10_code', ''),
                'organization': document.get('organization', ''),
                'issue_date': issue_date_str,
                'doctor_name': document.get('doctor_name', ''),
                'doctor_position': document.get('doctor_position', ''),
                'department_head_name': document.get('department_head_name', ''),
                'days_off_period': days_off_str,
                'uuid': document.get('uuid', ''),
                'pin_code': document.get('pin_code', ''),
                'pdf_url': pdf_url,
                'pdf_url_by_uuid': pdf_url_by_uuid
            }
        })
        
    except Exception as e:
        log_error_with_context(e, f"get_document_by_uuid failed, uuid={document_uuid}")
        return jsonify({'success': False, 'error': str(e)}), 500


@access_bp.route('/<document_uuid>/verify-pin', methods=['POST'])
def verify_pin_by_uuid(document_uuid):
    """Проверка PIN-кода для документа по UUID (публичный эндпоинт)"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'success': False, 'error': 'Данные не предоставлены'}), 400
        
        pin_code = data.get('pin_code', '').strip()
        
        if not pin_code:
            return jsonify({'success': False, 'error': 'PIN-код обязателен'}), 400
        
        document = db_select('documents', 'uuid = %s AND type_doc = 2', [document_uuid], fetch_one=True)
        
        if not document:
            return jsonify({'success': False, 'error': 'Документ не найден'}), 404
        
        # Проверяем PIN-код
        if document.get('pin_code') != pin_code:
            return jsonify({'success': False, 'error': 'Неверный PIN-код'}), 401
        
        # Форматируем даты
        issue_date_str = ''
        days_off_str = ''
        
        if document.get('issue_date'):
            try:
                if hasattr(document['issue_date'], 'isoformat'):
                    issue_date_str = document['issue_date'].isoformat()
                else:
                    issue_date_str = str(document['issue_date'])
            except:
                issue_date_str = str(document.get('issue_date', ''))
        
        if document.get('days_off_from') and document.get('days_off_to'):
            try:
                days_off_from = document['days_off_from']
                days_off_to = document['days_off_to']
                if hasattr(days_off_from, 'isoformat'):
                    days_off_str = f"{days_off_from.isoformat()} - {days_off_to.isoformat()}"
                else:
                    days_off_str = f"{days_off_from} - {days_off_to}"
            except:
                days_off_str = f"{document.get('days_off_from', '')} - {document.get('days_off_to', '')}"
        
        # Генерируем полные URL для PDF
        doc_id = document.get('id')
        pdf_url = None
        pdf_url_by_uuid = None
        
        if doc_id:
            try:
                # URL для скачивания по ID
                pdf_url = url_for('documents.download_document', doc_id=doc_id, _external=True)
            except Exception as e:
                logger.warning(f"Не удалось сгенерировать pdf_url: {e}")
        
        if document_uuid:
            try:
                # URL для скачивания по UUID
                pdf_url_by_uuid = url_for('documents.download_document', doc_id=doc_id, _external=True) if doc_id else None
            except Exception as e:
                logger.warning(f"Не удалось сгенерировать pdf_url_by_uuid: {e}")
        
        return jsonify({
            'success': True,
            'document': {
                'id': document.get('id'),
                'doc_number': document.get('mygov_doc_number', ''),
                'patient_name': document.get('patient_name', ''),
                'gender': document.get('gender', ''),
                'age': document.get('age', ''),
                'jshshir': document.get('jshshir', ''),
                'address': document.get('address', ''),
                'attached_medical_institution': document.get('attached_medical_institution', ''),
                'diagnosis': document.get('diagnosis', ''),
                'diagnosis_icd10_code': document.get('diagnosis_icd10_code', ''),
                'final_diagnosis': document.get('final_diagnosis', ''),
                'final_diagnosis_icd10_code': document.get('final_diagnosis_icd10_code', ''),
                'organization': document.get('organization', ''),
                'issue_date': issue_date_str,
                'doctor_name': document.get('doctor_name', ''),
                'doctor_position': document.get('doctor_position', ''),
                'department_head_name': document.get('department_head_name', ''),
                'days_off_period': days_off_str,
                'uuid': document.get('uuid', ''),
                'pdf_url': pdf_url,
                'pdf_url_by_uuid': pdf_url_by_uuid
            }
        })
        
    except Exception as e:
        log_error_with_context(e, f"verify_pin_by_uuid failed, uuid={document_uuid}")
        return jsonify({'success': False, 'error': str(e)}), 500

