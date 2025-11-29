"""
MyGov Backend - Генерация документов (DOCX и PDF)
"""
import os
import re
import uuid
import subprocess
import shutil
from datetime import datetime
from docx import Document
from docx.shared import Pt, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

from app.config import FRONTEND_URL, UPLOAD_FOLDER, TYPE_DOC
from app.services.qr_code import generate_simple_qr, save_qr_to_file
from app.services.storage import storage_manager
from app.services.database import get_next_mygov_doc_number, db_insert, db_update


def generate_document(document_data, app=None):
    """
    Генерирует документ MyGov (DOCX и PDF)
    
    Args:
        document_data: Данные документа
        app: Flask приложение (опционально)
    
    Returns:
        dict: Созданный документ или None при ошибке
    """
    document_id = None
    try:
        print(f"[DEBUG] generate_document: Начало генерации документа")
        print(f"[DEBUG] Данные документа: {list(document_data.keys())}")
        
        # Генерируем уникальные идентификаторы
        document_uuid = str(uuid.uuid4())
        pin_code = generate_pin_code()
        print(f"[DEBUG] Сгенерирован UUID: {document_uuid}, PIN: {pin_code}")
        
        try:
            mygov_doc_number = get_next_mygov_doc_number()
            print(f"[DEBUG] Получен номер документа: {mygov_doc_number}")
        except Exception as e:
            print(f"ERROR get_next_mygov_doc_number: {e}")
            import traceback
            print(traceback.format_exc())
            raise
        
        # Стандартный doc_number для совместимости с БД
        doc_number = f"№ MG {mygov_doc_number}"
        
        # Подготавливаем данные для вставки в БД
        db_data = {
            'doc_number': doc_number,
            'pin_code': pin_code,
            'uuid': document_uuid,
            'patient_name': document_data.get('patient_name'),
            'gender': document_data.get('gender'),
            'age': document_data.get('age'),
            'jshshir': document_data.get('jshshir'),
            'address': document_data.get('address'),
            'attached_medical_institution': document_data.get('attached_medical_institution'),
            'diagnosis': document_data.get('diagnosis'),
            'diagnosis_icd10_code': document_data.get('diagnosis_icd10_code'),
            'final_diagnosis': document_data.get('final_diagnosis'),
            'final_diagnosis_icd10_code': document_data.get('final_diagnosis_icd10_code'),
            'organization': document_data.get('organization'),
            'doctor_name': document_data.get('doctor_name'),
            'doctor_position': document_data.get('doctor_position'),
            'department_head_name': document_data.get('department_head_name'),
            'days_off_from': document_data.get('days_off_from'),
            'days_off_to': document_data.get('days_off_to'),
            'issue_date': document_data.get('issue_date', datetime.now().isoformat()),
            'type_doc': TYPE_DOC,  # Всегда 2 для MyGov
            'mygov_doc_number': mygov_doc_number,
            'created_by': document_data.get('created_by')
        }
        
        print(f"[DEBUG] Вставка в БД...")
        # Вставляем в БД
        created_document = db_insert('documents', db_data)
        if not created_document:
            print("ERROR: Не удалось создать документ в БД")
            return None
        
        document_id = created_document['id']
        print(f"[DEBUG] Документ создан в БД с ID: {document_id}")
        
        # Генерируем DOCX
        print(f"[DEBUG] Генерация DOCX...")
        docx_path = fill_docx_template(created_document, app)
        if not docx_path:
            print("ERROR: Не удалось создать DOCX")
            # Удаляем документ из БД если не удалось создать DOCX
            if document_id:
                try:
                    db_query("DELETE FROM documents WHERE id = %s", [document_id])
                except:
                    pass
            return None
        
        print(f"[DEBUG] DOCX создан: {docx_path}")
        
        # Обновляем путь к DOCX в БД
        db_update('documents', {'docx_path': docx_path}, 'id = %s', [document_id])
        
        # Конвертируем в PDF
        print(f"[DEBUG] Конвертация в PDF...")
        pdf_path = convert_docx_to_pdf(docx_path, document_uuid, app)
        if pdf_path:
            print(f"[DEBUG] PDF создан: {pdf_path}")
            db_update('documents', {'pdf_path': pdf_path}, 'id = %s', [document_id])
        else:
            print("WARNING: PDF не был создан, но документ сохранен")
        
        # Возвращаем результат
        created_document['docx_path'] = docx_path
        created_document['pdf_path'] = pdf_path
        
        print(f"[DEBUG] generate_document: Успешно завершено")
        return created_document
        
    except Exception as e:
        print(f"ERROR generate_document: {e}")
        import traceback
        error_trace = traceback.format_exc()
        print(error_trace)
        
        # Удаляем документ из БД если была ошибка после создания
        if document_id:
            try:
                print(f"[DEBUG] Удаление документа {document_id} из БД из-за ошибки")
                db_query("DELETE FROM documents WHERE id = %s", [document_id])
            except Exception as cleanup_error:
                print(f"ERROR при очистке: {cleanup_error}")
        
        return None


def generate_pin_code():
    """Генерирует 4-значный PIN-код"""
    import random
    return ''.join([str(random.randint(0, 9)) for _ in range(4)])


def fill_docx_template(document_data, app=None):
    """
    Заполняет шаблон DOCX данными документа
    
    Args:
        document_data: Данные документа
        app: Flask приложение
    
    Returns:
        str: Путь к созданному файлу или None
    """
    try:
        template_folder = 'templates'
        if app:
            template_folder = app.config.get('TEMPLATE_FOLDER', 'templates')
        
        # Получаем абсолютный путь к шаблону
        if app:
            # Используем корневую директорию приложения
            app_root = app.root_path
            template_path = os.path.join(app_root, template_folder, 'template_mygov.docx')
        else:
            # Используем относительный путь от текущей директории
            template_path = os.path.join(template_folder, 'template_mygov.docx')
            # Пробуем абсолютный путь
            if not os.path.exists(template_path):
                # Пробуем от корня проекта
                current_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
                template_path = os.path.join(current_dir, template_folder, 'template_mygov.docx')
        
        print(f"[DEBUG] fill_docx_template: Ищем шаблон по пути: {template_path}")
        
        if not os.path.exists(template_path):
            print(f"ERROR: Шаблон не найден: {template_path}")
            print(f"[DEBUG] Текущая рабочая директория: {os.getcwd()}")
            print(f"[DEBUG] Абсолютный путь к скрипту: {os.path.abspath(__file__)}")
            if app:
                print(f"[DEBUG] app.root_path: {app.root_path}")
            return None
        
        print(f"[DEBUG] Шаблон найден: {template_path}")
        
        doc = Document(template_path)
        
        # Подготавливаем замены
        replacements = prepare_replacements(document_data)
        
        # Заменяем плейсхолдеры
        replace_placeholders(doc, replacements)
        
        # Добавляем QR-код
        add_qr_code(doc, document_data, app)
        
        # Сохраняем документ
        os.makedirs(UPLOAD_FOLDER, exist_ok=True)
        document_uuid = document_data.get('uuid', str(uuid.uuid4()))
        output_path = os.path.join(UPLOAD_FOLDER, f"{document_uuid}.docx")
        
        doc.save(output_path)
        
        # Сохраняем в MinIO
        with open(output_path, 'rb') as f:
            docx_data = f.read()
        
        stored_path = storage_manager.save_file(
            docx_data, 
            f"{document_uuid}.docx",
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        )
        
        # Удаляем локальный файл если сохранили в MinIO
        if storage_manager.use_minio and os.path.exists(output_path):
            try:
                os.remove(output_path)
            except:
                pass
        
        return stored_path
        
    except Exception as e:
        print(f"ERROR fill_docx_template: {e}")
        import traceback
        print(traceback.format_exc())
        return None


def prepare_replacements(document_data):
    """Подготавливает словарь замен для шаблона"""
    # Форматируем даты в формат DD.MM.YYYY
    def format_date(date_str):
        if not date_str:
            return ''
        try:
            # Преобразуем в строку
            date_str = str(date_str).strip()
            
            # Если есть время (ISO формат), берем только дату
            if 'T' in date_str:
                date_str = date_str.split('T')[0]
            # Если есть пробел, берем только дату
            elif ' ' in date_str:
                date_str = date_str.split(' ')[0]
            
            # Парсим дату в формате YYYY-MM-DD
            dt = datetime.strptime(date_str, '%Y-%m-%d')
            # Возвращаем в формате DD.MM.YYYY
            return dt.strftime('%d.%m.%Y')
        except Exception as e:
            # Если не удалось распарсить, возвращаем исходную строку
            print(f"WARNING: Не удалось отформатировать дату '{date_str}': {e}")
            return str(date_str) if date_str else ''
            
    # Вычисляем количество дней
    def calculate_days_off(start_date, end_date):
        try:
            if not start_date or not end_date:
                return ''
            if 'T' in str(start_date): start_date = str(start_date).split('T')[0]
            if 'T' in str(end_date): end_date = str(end_date).split('T')[0]
            
            d1 = datetime.strptime(str(start_date), '%Y-%m-%d')
            d2 = datetime.strptime(str(end_date), '%Y-%m-%d')
            delta = (d2 - d1).days + 1 # Включая первый день
            return str(delta)
        except:
            return ''
    
    days_off_count = calculate_days_off(document_data.get('days_off_from'), document_data.get('days_off_to'))
    
    return {
        '{{doc_number}}': f"№ {document_data.get('mygov_doc_number', '')}", # Форматированный номер
        '{{mygov_doc_number}}': document_data.get('mygov_doc_number', ''),
        '{{uuid}}': document_data.get('uuid', ''),
        '{{patient_name}}': document_data.get('patient_name', ''),
        '{{gender}}': document_data.get('gender', ''),
        '{{age}}': str(document_data.get('age', '')),
        '{{jshshir}}': document_data.get('jshshir', ''),
        '{{address}}': document_data.get('address', ''),
        '{{attached_medical_institution}}': document_data.get('attached_medical_institution', ''),
        '{{diagnosis}}': document_data.get('diagnosis', ''),
        '{{diagnosis_icd10_code}}': document_data.get('diagnosis_icd10_code', ''),
        '{{final_diagnosis}}': document_data.get('final_diagnosis', ''),
        '{{final_diagnosis_icd10_code}}': document_data.get('final_diagnosis_icd10_code', ''),
        '{{organization}}': document_data.get('organization', ''),
        '{{doctor_name}}': document_data.get('doctor_name', ''),
        '{{doctor_position}}': document_data.get('doctor_position', ''),
        '{{department_head_name}}': document_data.get('department_head_name', ''),
        '{{days_off_from}}': format_date(document_data.get('days_off_from')),
        '{{days_off_to}}': format_date(document_data.get('days_off_to')),
        '{{days_off_period}}': days_off_count,
        '{{issue_date}}': format_date(document_data.get('issue_date')),
        '{{pin_code}}': document_data.get('pin_code', ''),  # PIN-код заменяется здесь
        # {{qr_code}} обрабатывается отдельно в add_qr_code (нужно изображение)
    }


def replace_placeholders(doc, replacements):
    """Заменяет плейсхолдеры в документе"""
    
    def process_paragraph(paragraph):
        """Обрабатывает один параграф"""
        text = paragraph.text
        
        # Пропускаем параграфы с {{qr_code}} - он обрабатывается отдельно (нужно изображение)
        if '{{qr_code}}' in text:
            return
        
        has_replacement = False
        for key, value in replacements.items():
            if key in text:
                text = text.replace(key, str(value))
                has_replacement = True
        
        if has_replacement:
            # Если была замена, обновляем текст параграфа
            # Сохраняем стиль исходного параграфа (первого run)
            style = None
            if paragraph.runs:
                style = paragraph.runs[0].style
                
            paragraph.text = text
            
            # Устанавливаем шрифт Times New Roman 10.5pt для всех runs
            for run in paragraph.runs:
                run.font.name = 'Times New Roman'
                
                # Проверяем, является ли текст PIN-кодом (4 цифры)
                is_pin_code = run.text.strip().isdigit() and len(run.text.strip()) == 4
                
                if is_pin_code:
                    # PIN-код: размер 23pt, жирный
                    run.font.size = Pt(18)
                    run.font.bold = True
                else:
                    # Обычный текст: размер 10.5pt
                    run.font.size = Pt(10.5)
                
                # Устанавливаем шрифт для кириллицы (важно для русского и узбекского текста)
                # Проверяем наличие rPr элемента
                if run._element.rPr is None:
                    run._element.get_or_add_rPr()
                
                # Устанавливаем rFonts для правильного отображения кириллицы
                rFonts = run._element.rPr.find(qn('w:rFonts'))
                if rFonts is None:
                    rFonts = OxmlElement(qn('w:rFonts'))
                    run._element.rPr.append(rFonts)
                
                rFonts.set(qn('w:ascii'), 'Times New Roman')
                rFonts.set(qn('w:hAnsi'), 'Times New Roman')
                rFonts.set(qn('w:cs'), 'Times New Roman')
                
                # Восстанавливаем стиль если был
                if style:
                    run.style = style

    # 1. Обрабатываем тело документа
    for para in doc.paragraphs:
        process_paragraph(para)
        
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                for para in cell.paragraphs:
                    process_paragraph(para)
                    
    # 2. Обрабатываем колонтитулы (Headers & Footers)
    for section in doc.sections:
        # Headers
        for header in [section.header, section.first_page_header, section.even_page_header]:
            if header:
                for para in header.paragraphs:
                    process_paragraph(para)
                for table in header.tables:
                    for row in table.rows:
                        for cell in row.cells:
                            for para in cell.paragraphs:
                                process_paragraph(para)
                                
        # Footers
        for footer in [section.footer, section.first_page_footer, section.even_page_footer]:
            if footer:
                for para in footer.paragraphs:
                    process_paragraph(para)
                for table in footer.tables:
                    for row in table.rows:
                        for cell in row.cells:
                            for para in cell.paragraphs:
                                process_paragraph(para)


def add_qr_code(doc, document_data, app=None):
    """Добавляет QR-код и PIN-код в документ inline в том же параграфе"""
    try:
        document_uuid = document_data.get('uuid', '')
        pin_code = document_data.get('pin_code', '')
        
        # Генерируем URL для QR-кода
        frontend_url = FRONTEND_URL.rstrip('/')
        qr_url = f"{frontend_url}/access/{document_uuid}"
        
        # Генерируем простой QR-код
        qr_img = generate_simple_qr(qr_url, box_size=3, border=1)
        
        # Сохраняем во временный файл
        os.makedirs(UPLOAD_FOLDER, exist_ok=True)
        qr_temp_path = os.path.join(UPLOAD_FOLDER, f'qr_temp_{pin_code}.png')
        save_qr_to_file(qr_img, qr_temp_path)
        
        qr_added = False
        
        def replace_pin_qr_inline(paragraph):
            """Просто заменяет {{pin_code}} и {{qr_code}} inline, сохраняя структуру шаблона"""
            nonlocal qr_added
            text = paragraph.text
            
            # Проверяем наличие плейсхолдеров
            has_qr = '{{qr_code}}' in text
            
            if not has_qr:
                return False
            
            # Сохраняем выравнивание параграфа
            alignment = paragraph.alignment
            
            # Сохраняем полный текст для разбора
            full_text = text
            
            # Очищаем параграф
            paragraph.clear()
            if alignment:
                paragraph.alignment = alignment
            
            # Разбиваем текст на части по плейсхолдерам
            parts = re.split(r'({{pin_code}}|{{qr_code}})', full_text)
            
            for part in parts:
                if not part:
                    continue
                
                if part == '{{pin_code}}':
                    # Добавляем PIN-код как текст
                    run = paragraph.add_run(pin_code)
                    run.font.name = 'Times New Roman'
                    run.font.size = Pt(18)
                    run.font.bold = True
                    
                    # Устанавливаем шрифт для кириллицы
                    if run._element.rPr is None:
                        run._element.get_or_add_rPr()
                    rFonts = run._element.rPr.find(qn('w:rFonts'))
                    if rFonts is None:
                        rFonts = OxmlElement(qn('w:rFonts'))
                        run._element.rPr.append(rFonts)
                    rFonts.set(qn('w:ascii'), 'Times New Roman')
                    rFonts.set(qn('w:hAnsi'), 'Times New Roman')
                    rFonts.set(qn('w:cs'), 'Times New Roman')
                    
                elif part == '{{qr_code}}':
                    # Добавляем QR-код как изображение
                    run = paragraph.add_run()
                    run.add_picture(qr_temp_path, width=Inches(0.8))
                    
                else:
                    # Обычный текст - сохраняем как есть
                    run = paragraph.add_run(part)
                    run.font.name = 'Times New Roman'
                    run.font.size = Pt(10.5)
                    
                    # Устанавливаем шрифт для кириллицы
                    if run._element.rPr is None:
                        run._element.get_or_add_rPr()
                    rFonts = run._element.rPr.find(qn('w:rFonts'))
                    if rFonts is None:
                        rFonts = OxmlElement(qn('w:rFonts'))
                        run._element.rPr.append(rFonts)
                    rFonts.set(qn('w:ascii'), 'Times New Roman')
                    rFonts.set(qn('w:hAnsi'), 'Times New Roman')
                    rFonts.set(qn('w:cs'), 'Times New Roman')
            
            return True
        
        # Вспомогательная функция для обработки параграфов
        def check_paragraphs(paragraphs):
            nonlocal qr_added
            for para in paragraphs:
                if replace_pin_qr_inline(para):
                    qr_added = True
                    return True
            return False
            
        # Вспомогательная функция для обработки таблиц
        def check_tables(tables):
            nonlocal qr_added
            for table in tables:
                for row in table.rows:
                    for cell in row.cells:
                        if check_paragraphs(cell.paragraphs):
                            return True
            return False

        # 1. Проверяем тело документа
        if not check_paragraphs(doc.paragraphs):
            if not check_tables(doc.tables):
                # 2. Проверяем Headers и Footers
                for section in doc.sections:
                    # Footers (чаще всего QR там)
                    for footer in [section.footer, section.first_page_footer, section.even_page_footer]:
                        if footer:
                            if check_paragraphs(footer.paragraphs): break
                            if check_tables(footer.tables): break
                    if qr_added: break
                    
                    # Headers (на всякий случай)
                    for header in [section.header, section.first_page_header, section.even_page_header]:
                        if header:
                            if check_paragraphs(header.paragraphs): break
                            if check_tables(header.tables): break
                    if qr_added: break
        
        # Если плейсхолдер не найден, добавляем в конец документа
        if not qr_added:
            add_pin_qr_to_end(doc, pin_code, qr_temp_path)
        
        # Удаляем временный файл
        if os.path.exists(qr_temp_path):
            os.remove(qr_temp_path)
            
    except Exception as e:
        print(f"ERROR add_qr_code: {e}")
        import traceback
        print(traceback.format_exc())


def add_pin_qr_table(doc, para, pin_code, qr_temp_path):
    """Добавляет таблицу с PIN-кодом и QR-кодом"""
    parent = para._element.getparent()
    
    # Создаем таблицу
    table = doc.add_table(rows=1, cols=2)
    table.columns[0].width = Cm(2.0)
    table.columns[1].width = Cm(2.5)
    
    # Ячейка с PIN-кодом
    pin_cell = table.rows[0].cells[0]
    pin_cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    pin_para = pin_cell.paragraphs[0]
    pin_para.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    pin_run = pin_para.add_run(pin_code)
    pin_run.font.size = Pt(18)
    pin_run.font.bold = True
    
    # Ячейка с QR-кодом
    qr_cell = table.rows[0].cells[1]
    qr_cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    qr_para = qr_cell.paragraphs[0]
    qr_para.alignment = WD_ALIGN_PARAGRAPH.LEFT
    qr_run = qr_para.add_run()
    qr_run.add_picture(qr_temp_path, width=Inches(0.8))
    
    # Вставляем таблицу вместо параграфа
    parent.insert(parent.index(para._element), table._element)
    parent.remove(para._element)


def add_pin_qr_to_end(doc, pin_code, qr_temp_path):
    """Добавляет PIN-код и QR-код в конец документа"""
    # Добавляем таблицу
    table = doc.add_table(rows=1, cols=2)
    table.columns[0].width = Cm(2.0)
    table.columns[1].width = Cm(2.5)
    
    # PIN-код
    pin_cell = table.rows[0].cells[0]
    pin_cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    pin_para = pin_cell.paragraphs[0]
    pin_para.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    pin_run = pin_para.add_run(pin_code)
    pin_run.font.size = Pt(23)
    pin_run.font.bold = True
    
    # QR-код
    qr_cell = table.rows[0].cells[1]
    qr_cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    qr_para = qr_cell.paragraphs[0]
    qr_para.alignment = WD_ALIGN_PARAGRAPH.LEFT
    qr_run = qr_para.add_run()
    qr_run.add_picture(qr_temp_path, width=Inches(0.8))


def convert_docx_to_pdf(docx_path, document_uuid, app=None):
    """
    Конвертирует DOCX в PDF с помощью LibreOffice
    
    Args:
        docx_path: Путь к DOCX файлу
        document_uuid: UUID документа
        app: Flask приложение
    
    Returns:
        str: Путь к PDF файлу или None
    """
    try:
        # Получаем DOCX из хранилища
        if docx_path.startswith('minio://'):
            docx_data = storage_manager.get_file(docx_path)
            if not docx_data:
                print("ERROR: Не удалось получить DOCX из MinIO")
                return None
            
            # Сохраняем временно
            os.makedirs(UPLOAD_FOLDER, exist_ok=True)
            temp_docx = os.path.join(UPLOAD_FOLDER, f"temp_{document_uuid}.docx")
            with open(temp_docx, 'wb') as f:
                f.write(docx_data)
            docx_path = temp_docx
        
        # Конвертируем с помощью LibreOffice
        libreoffice_cmd = find_libreoffice()
        if not libreoffice_cmd:
            print("WARNING: LibreOffice не найден, PDF не будет создан")
            return None
        
        output_dir = UPLOAD_FOLDER
        os.makedirs(output_dir, exist_ok=True)
        
        cmd = [
            libreoffice_cmd,
            '--headless',
            '--convert-to', 'pdf',
            '--outdir', output_dir,
            os.path.abspath(docx_path)
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        
        if result.returncode != 0:
            print(f"ERROR LibreOffice: {result.stderr}")
            return None
        
        # Находим созданный PDF
        pdf_filename = os.path.splitext(os.path.basename(docx_path))[0] + '.pdf'
        pdf_path = os.path.join(output_dir, pdf_filename)
        
        if not os.path.exists(pdf_path):
            print(f"ERROR: PDF не найден: {pdf_path}")
            return None
        
        # Сохраняем в MinIO
        with open(pdf_path, 'rb') as f:
            pdf_data = f.read()
        
        stored_path = storage_manager.save_file(
            pdf_data,
            f"{document_uuid}.pdf",
            'application/pdf'
        )
        
        # Удаляем временные файлы
        if storage_manager.use_minio:
            try:
                if os.path.exists(pdf_path):
                    os.remove(pdf_path)
                if 'temp_' in docx_path and os.path.exists(docx_path):
                    os.remove(docx_path)
            except:
                pass
        
        return stored_path
        
    except Exception as e:
        print(f"ERROR convert_docx_to_pdf: {e}")
        import traceback
        print(traceback.format_exc())
        return None


def find_libreoffice():
    """Находит путь к LibreOffice"""
    import platform
    
    if platform.system() == 'Windows':
        paths = [
            r'C:\Program Files\LibreOffice\program\soffice.exe',
            r'C:\Program Files (x86)\LibreOffice\program\soffice.exe',
        ]
    else:
        paths = [
            '/usr/bin/libreoffice',
            '/usr/bin/soffice',
            '/usr/local/bin/libreoffice',
        ]
    
    for path in paths:
        if os.path.exists(path):
            return path
    
    # Пробуем найти в PATH
    return shutil.which('libreoffice') or shutil.which('soffice')

