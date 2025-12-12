from flask import Blueprint, jsonify, request

files_bp = Blueprint('files', __name__)


@files_bp.route('', methods=['OPTIONS'])
def files_options():
    """
    Handle CORS preflight for /api/files to avoid 404 on OPTIONS.
    """
    origin = request.headers.get('Origin', '*')
    acrh = request.headers.get('Access-Control-Request-Headers', 'Authorization,Content-Type')
    resp = ('', 204, {
        'Access-Control-Allow-Origin': origin,
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
        'Access-Control-Allow-Headers': acrh,
    })
    return resp


@files_bp.route('', methods=['GET'])
def files_list():
    """
    Stub endpoint to satisfy frontend; extend with real file listing as needed.
    """
    return jsonify({"success": True, "files": []})

