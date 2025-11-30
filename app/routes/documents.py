"""
MyGov Backend - Маршруты документов
"""
from flask import Blueprint, request, jsonify, send_file, current_app
from io import BytesIO

from app.config import TYPE_DOC, FRONTEND_URL
from app.services.database import db_query, db_select
from app.services.storage import storage_manager
from app.services.document import generate_document
from app.routes.auth import require_auth
from app.utils.logger import logger, log_error_with_context

documents_bp = Blueprint('documents', __name__)


@documents_bp.route('', methods=['GET'])
@require_auth
def list_documents():
    """Получение списка документов MyGov (type_doc=2)"""
    try:
        query = """
            SELECT d.*, u.username as creator_username, u.email as creator_email
            FROM documents d
            LEFT JOIN users u ON d.created_by = u.id
            WHERE d.type_doc = 2
            ORDER BY d.created_at DESC
        """
        
        result = db_query(query, fetch_all=True)
        documents = [dict(row) for row in result] if result else []
        
        # Убираем чувствительные данные
        for doc in documents:
            doc.pop('pin_code', None)
            # Форматируем даты
            for key in ['created_at', 'updated_at', 'issue_date', 'days_off_from', 'days_off_to']:
                if doc.get(key) and hasattr(doc[key], 'isoformat'):
                    doc[key] = doc[key].isoformat()
        
        return jsonify(documents)
        
    except Exception as e:
        log_error_with_context(e, "list_documents failed")
        return jsonify({'success': False, 'message': f'Ошибка: {str(e)}'}), 500


@documents_bp.route('/generate', methods=['POST'])
@require_auth
def create_document():
    """Создание нового документа MyGov"""
    try:
        data = request.get_json()
        
        if not data:
            logger.warning("[API:CREATE_DOC] Данные не предоставлены")
            return jsonify({'success': False, 'message': 'Данные не предоставлены'}), 400
        
        # Добавляем ID создателя
        user_id = request.current_user.get('user_id')
        data['created_by'] = user_id
        
        logger.info(f"[API:CREATE_DOC] Запрос на создание документа от пользователя {user_id}")
        logger.debug(f"[API:CREATE_DOC] Данные: {list(data.keys())}")
        
        # Генерируем документ
        created_document = generate_document(data, current_app)
        
        if not created_document:
            return jsonify({'success': False, 'message': 'Ошибка создания документа'}), 500
        
        return jsonify({
            'success': True,
            'document_id': created_document['id'],
            'doc_number': created_document.get('mygov_doc_number', ''),  # Номер MyGov для отображения
            'mygov_doc_number': created_document.get('mygov_doc_number', ''),  # Дублируем для совместимости
            'pin_code': created_document.get('pin_code', ''),
            'uuid': created_document.get('uuid', ''),
            'download_url': f"/api/documents/{created_document['id']}/download"
        })
        
    except Exception as e:
        log_error_with_context(e, f"create_document failed, user_id={request.current_user.get('user_id')}")
        
        # Более детальное сообщение об ошибке для отладки
        error_message = str(e)
        if 'DB_PASSWORD' in error_message or 'password' in error_message.lower():
            error_message = 'Ошибка подключения к базе данных. Проверьте настройки подключения.'
        elif 'template' in error_message.lower() or 'шаблон' in error_message.lower():
            error_message = 'Ошибка при работе с шаблоном документа.'
        elif 'minio' in error_message.lower() or 'storage' in error_message.lower():
            error_message = 'Ошибка при сохранении файла в хранилище.'
        
        return jsonify({
            'success': False, 
            'message': f'Ошибка создания документа: {error_message}',
            'error_type': type(e).__name__
        }), 500


@documents_bp.route('/<int:doc_id>', methods=['GET'])
@require_auth
def get_document(doc_id):
    """Получение информации о документе"""
    try:
        document = db_select('documents', 'id = %s AND type_doc = 2', [doc_id], fetch_one=True)
        
        if not document:
            return jsonify({'success': False, 'message': 'Документ не найден'}), 404
        
        # Убираем чувствительные данные
        document.pop('pin_code', None)
        
        # Форматируем даты
        for key in ['created_at', 'updated_at', 'issue_date', 'days_off_from', 'days_off_to']:
            if document.get(key) and hasattr(document[key], 'isoformat'):
                document[key] = document[key].isoformat()
        
        return jsonify({'success': True, 'document': document})
        
    except Exception as e:
        print(f"ERROR get_document: {e}")
        return jsonify({'success': False, 'message': f'Ошибка: {str(e)}'}), 500


@documents_bp.route('/<int:doc_id>/download', methods=['GET'])
def download_document(doc_id):
    """Скачивание PDF документа"""
    try:
        logger.info(f"[API:DOWNLOAD] Запрос на скачивание PDF документа {doc_id}")
        
        document = db_select('documents', 'id = %s AND type_doc = 2', [doc_id], fetch_one=True)
        
        if not document:
            logger.warning(f"[API:DOWNLOAD] Документ {doc_id} не найден")
            return jsonify({'success': False, 'message': 'Документ не найден'}), 404
        
        logger.debug(f"[API:DOWNLOAD] Документ найден: doc_number={document.get('mygov_doc_number')}")
        
        pdf_path = document.get('pdf_path')
        
        # Если PDF не найден, пытаемся сгенерировать его заново из DOCX
        if not pdf_path:
            logger.warning(f"[API:DOWNLOAD] PDF путь не указан для документа {doc_id}, пытаемся сгенерировать заново")
            docx_path = document.get('docx_path')
            document_uuid = document.get('uuid', '')
            
            # Если docx_path в старом формате, пробуем обновить его
            if docx_path and not docx_path.startswith('minio://') and document_uuid:
                # Пробуем получить файл из MinIO по UUID
                possible_minio_path = f"minio://dmed/{document_uuid}.docx"
                logger.info(f"[API:DOWNLOAD] Обнаружен старый формат docx_path, пробуем обновить: {possible_minio_path}")
                docx_data = storage_manager.get_file(possible_minio_path)
                if docx_data:
                    # Обновляем docx_path в БД
                    from app.services.database import db_update
                    db_update('documents', {'docx_path': possible_minio_path}, 'id = %s', [doc_id])
                    docx_path = possible_minio_path
                    logger.info(f"[API:DOWNLOAD] docx_path обновлен в БД: {possible_minio_path}")
            
            if docx_path:
                try:
                    from app.services.document import convert_docx_to_pdf
                    logger.info(f"[API:DOWNLOAD] Начало генерации PDF из DOCX: {docx_path}, UUID: {document_uuid}")
                    pdf_path = convert_docx_to_pdf(docx_path, document_uuid, current_app)
                    if pdf_path:
                        # Обновляем путь в БД
                        from app.services.database import db_update
                        db_update('documents', {'pdf_path': pdf_path}, 'id = %s', [doc_id])
                        logger.info(f"[API:DOWNLOAD] PDF успешно сгенерирован заново для документа {doc_id}: {pdf_path}")
                    else:
                        logger.error(f"[API:DOWNLOAD] convert_docx_to_pdf вернул None для документа {doc_id}")
                        # Fallback: предлагаем скачать DOCX
                        return jsonify({
                            'success': False, 
                            'message': 'PDF не найден и не может быть сгенерирован. Попробуйте скачать DOCX версию.',
                            'docx_available': True,
                            'docx_url': f"/api/documents/{doc_id}/download/docx"
                        }), 404
                except Exception as conv_error:
                    log_error_with_context(conv_error, f"Ошибка при генерации PDF для документа {doc_id}")
                    # Fallback: предлагаем скачать DOCX
                    return jsonify({
                        'success': False, 
                        'message': f'Ошибка при генерации PDF: {str(conv_error)}. Попробуйте скачать DOCX версию.',
                        'docx_available': True,
                        'docx_url': f"/api/documents/{doc_id}/download/docx"
                    }), 500
            else:
                logger.error(f"[API:DOWNLOAD] DOCX также не найден для документа {doc_id}")
                return jsonify({'success': False, 'message': 'PDF не найден. DOCX также недоступен.'}), 404
        
        logger.debug(f"[API:DOWNLOAD] PDF путь: {pdf_path}")
        
        # Получаем файл из хранилища
        logger.debug(f"[API:DOWNLOAD] Получение файла из хранилища: {pdf_path}")
        pdf_data = storage_manager.get_file(pdf_path)
        
        if not pdf_data:
            logger.error(f"[API:DOWNLOAD] Файл не получен из хранилища: {pdf_path}")
            # Пробуем еще раз сгенерировать
            docx_path = document.get('docx_path')
            document_uuid = document.get('uuid', '')
            
            # Если docx_path в старом формате, пробуем обновить его
            if docx_path and not docx_path.startswith('minio://') and document_uuid:
                possible_minio_path = f"minio://dmed/{document_uuid}.docx"
                logger.info(f"[API:DOWNLOAD] Обнаружен старый формат docx_path при регенерации, пробуем обновить: {possible_minio_path}")
                docx_data = storage_manager.get_file(possible_minio_path)
                if docx_data:
                    from app.services.database import db_update
                    db_update('documents', {'docx_path': possible_minio_path}, 'id = %s', [doc_id])
                    docx_path = possible_minio_path
                    logger.info(f"[API:DOWNLOAD] docx_path обновлен в БД при регенерации: {possible_minio_path}")
            
            if docx_path:
                logger.info(f"[API:DOWNLOAD] Пытаемся регенерировать PDF из DOCX: {docx_path}")
                from app.services.document import convert_docx_to_pdf
                new_pdf_path = convert_docx_to_pdf(docx_path, document_uuid, current_app)
                if new_pdf_path:
                    from app.services.database import db_update
                    db_update('documents', {'pdf_path': new_pdf_path}, 'id = %s', [doc_id])
                    pdf_data = storage_manager.get_file(new_pdf_path)
                    if pdf_data:
                        pdf_path = new_pdf_path
                        logger.info(f"[API:DOWNLOAD] PDF успешно регенерирован и получен из хранилища: {new_pdf_path}")
                    else:
                        logger.error(f"[API:DOWNLOAD] PDF создан, но не получен из хранилища: {new_pdf_path}")
                        return jsonify({'success': False, 'message': 'Файл не найден в хранилище'}), 404
                else:
                    logger.error(f"[API:DOWNLOAD] Не удалось регенерировать PDF из DOCX")
                    return jsonify({'success': False, 'message': 'Не удалось сгенерировать PDF'}), 500
            else:
                logger.error(f"[API:DOWNLOAD] DOCX путь не найден для регенерации")
                return jsonify({'success': False, 'message': 'Файл не найден'}), 404
        
        logger.debug(f"[API:DOWNLOAD] Файл получен, размер: {len(pdf_data)} bytes")
        
        # Формируем имя файла
        mygov_doc_number = document.get('mygov_doc_number', '')
        filename = f"mygov_{mygov_doc_number}.pdf" if mygov_doc_number else f"document_{doc_id}.pdf"
        
        logger.info(f"[API:DOWNLOAD] Отправка файла: {filename}, размер: {len(pdf_data)} bytes")
        
        return send_file(
            BytesIO(pdf_data),
            mimetype='application/pdf',
            as_attachment=True,
            download_name=filename
        )
        
    except Exception as e:
        log_error_with_context(e, f"download_document failed, doc_id={doc_id}")
        return jsonify({'success': False, 'message': f'Ошибка: {str(e)}'}), 500


@documents_bp.route('/<int:doc_id>/download/docx', methods=['GET'])
def download_docx(doc_id):
    """Скачивание DOCX документа"""
    try:
        logger.info(f"[API:DOWNLOAD_DOCX] Запрос на скачивание DOCX документа {doc_id}")
        
        document = db_select('documents', 'id = %s AND type_doc = 2', [doc_id], fetch_one=True)
        
        if not document:
            logger.warning(f"[API:DOWNLOAD_DOCX] Документ {doc_id} не найден")
            return jsonify({'success': False, 'message': 'Документ не найден'}), 404
        
        logger.debug(f"[API:DOWNLOAD_DOCX] Документ найден: doc_number={document.get('mygov_doc_number')}")
        
        docx_path = document.get('docx_path')
        if not docx_path:
            logger.warning(f"[API:DOWNLOAD_DOCX] DOCX путь не указан для документа {doc_id}")
            return jsonify({'success': False, 'message': 'DOCX не найден'}), 404
        
        logger.debug(f"[API:DOWNLOAD_DOCX] DOCX путь: {docx_path}")
        
        # Получаем файл из хранилища
        logger.debug(f"[API:DOWNLOAD_DOCX] Получение файла из хранилища: {docx_path}")
        docx_data = storage_manager.get_file(docx_path)
        
        if not docx_data:
            logger.error(f"[API:DOWNLOAD_DOCX] Файл не получен из хранилища: {docx_path}")
            return jsonify({'success': False, 'message': 'Файл не найден'}), 404
        
        logger.debug(f"[API:DOWNLOAD_DOCX] Файл получен, размер: {len(docx_data)} bytes")
        
        # Формируем имя файла
        mygov_doc_number = document.get('mygov_doc_number', '')
        filename = f"mygov_{mygov_doc_number}.docx" if mygov_doc_number else f"document_{doc_id}.docx"
        
        logger.info(f"[API:DOWNLOAD_DOCX] Отправка файла: {filename}, размер: {len(docx_data)} bytes")
        
        return send_file(
            BytesIO(docx_data),
            mimetype='application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            as_attachment=True,
            download_name=filename
        )
        
    except Exception as e:
        log_error_with_context(e, f"download_docx failed, doc_id={doc_id}")
        return jsonify({'success': False, 'message': f'Ошибка: {str(e)}'}), 500


@documents_bp.route('/verify/<document_uuid>', methods=['GET'])
def verify_document(document_uuid):
    """Проверка документа по UUID (публичный эндпоинт)"""
    try:
        document = db_select('documents', 'uuid = %s AND type_doc = 2', [document_uuid], fetch_one=True)
        
        if not document:
            return jsonify({'success': False, 'message': 'Документ не найден'}), 404
        
        # Возвращаем публичную информацию
        return jsonify({
            'success': True,
            'document': {
                'doc_number': document.get('mygov_doc_number', ''),
                'patient_name': document.get('patient_name', ''),
                'organization': document.get('organization', ''),
                'diagnosis': document.get('diagnosis', ''),
                'issue_date': document['issue_date'].isoformat() if document.get('issue_date') and hasattr(document['issue_date'], 'isoformat') else document.get('issue_date', ''),
                'days_off_from': document['days_off_from'].isoformat() if document.get('days_off_from') and hasattr(document['days_off_from'], 'isoformat') else document.get('days_off_from', ''),
                'days_off_to': document['days_off_to'].isoformat() if document.get('days_off_to') and hasattr(document['days_off_to'], 'isoformat') else document.get('days_off_to', ''),
                'doctor_name': document.get('doctor_name', ''),
                'verified': True
            }
        })
        
    except Exception as e:
        print(f"ERROR verify_document: {e}")
        return jsonify({'success': False, 'message': f'Ошибка: {str(e)}'}), 500


@documents_bp.route('/verify-pin', methods=['POST'])
def verify_by_pin():
    """Проверка документа по UUID и PIN-коду (публичный эндпоинт)"""
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({'success': False, 'message': 'Данные не предоставлены'}), 400
        
        document_uuid = data.get('uuid', '').strip()
        pin_code = data.get('pin_code', '').strip()
        
        if not document_uuid or not pin_code:
            return jsonify({'success': False, 'message': 'UUID и PIN-код обязательны'}), 400
        
        document = db_select('documents', 'uuid = %s AND type_doc = 2', [document_uuid], fetch_one=True)
        
        if not document:
            return jsonify({'success': False, 'message': 'Документ не найден'}), 404
        
        # Проверяем PIN-код
        if document.get('pin_code') != pin_code:
            return jsonify({'success': False, 'message': 'Неверный PIN-код'}), 401
        
        # Возвращаем полную информацию
        return jsonify({
            'success': True,
            'document': {
                'id': document['id'],
                'uuid': document.get('uuid', ''),
                'doc_number': document.get('mygov_doc_number', ''),
                'patient_name': document.get('patient_name', ''),
                'gender': document.get('gender', ''),
                'age': document.get('age', ''),
                'jshshir': document.get('jshshir', ''),
                'address': document.get('address', ''),
                'organization': document.get('organization', ''),
                'diagnosis': document.get('diagnosis', ''),
                'diagnosis_icd10_code': document.get('diagnosis_icd10_code', ''),
                'final_diagnosis': document.get('final_diagnosis', ''),
                'final_diagnosis_icd10_code': document.get('final_diagnosis_icd10_code', ''),
                'doctor_name': document.get('doctor_name', ''),
                'doctor_position': document.get('doctor_position', ''),
                'department_head_name': document.get('department_head_name', ''),
                'issue_date': document['issue_date'].isoformat() if document.get('issue_date') and hasattr(document['issue_date'], 'isoformat') else document.get('issue_date', ''),
                'days_off_from': document['days_off_from'].isoformat() if document.get('days_off_from') and hasattr(document['days_off_from'], 'isoformat') else document.get('days_off_from', ''),
                'days_off_to': document['days_off_to'].isoformat() if document.get('days_off_to') and hasattr(document['days_off_to'], 'isoformat') else document.get('days_off_to', ''),
                'download_url': f"/api/documents/{document['id']}/download",
                'verified': True
            }
        })
        
    except Exception as e:
        print(f"ERROR verify_by_pin: {e}")
        return jsonify({'success': False, 'message': f'Ошибка: {str(e)}'}), 500

