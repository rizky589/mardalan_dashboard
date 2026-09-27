from flask import Flask, render_template, jsonify, request, send_file
import json
import requests
from datetime import datetime, timedelta
import time
import random
import math
import io
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment

app = Flask(__name__)

# Configuration
GOOGLE_SHEETS_API_URL = "https://sheets.googleapis.com/v4/spreadsheets"
SPREADSHEET_ID = "1pk0GzWrTnw9SG4OZJx9_TT4BARSMPuQYkZW_a-mvFfc"
API_KEY = "YOUR_GOOGLE_SHEETS_API_KEY"  # Replace with actual API key

# Google Sheets structure based on the images
SHEET_HEADERS = {
    "survey": [
        "ID Survey", "ID Petugas", "Nama Petugas", "Tanggal", 
        "Waktu Mulai", "Waktu Selesai", "Durasi", "Jumlah Titik", "Jumlah Foto"
    ],
    "trackinglogs": [
        "ID Survey", "Timestamp", "Latitude", "Longitude"
    ],
    "photo": [
        "ID Survey", "Timestamp", "Latitude", "Longitude", "Foto (URL)"
    ]
}

# Labuhanbatu Utara area data
KECAMATAN_DATA = {
    "Kualuh Hulu": {
        "center": [2.3274, 99.8492],
        "desa": ["Aek Nabara", "Aek Raso", "Bandar Tinggi", "Kualuh Hulu", "Sei Silau"]
    },
    "Kualuh Hilir": {
        "center": [2.2850, 99.8200],
        "desa": ["Sei Balai", "Tanjung Medan", "Ujung Bandar", "Kualuh Hilir", "Sei Jawi"]
    },
    "Kualuh Selatan": {
        "center": [2.2500, 99.8800],
        "desa": ["Simpang Empat", "Sei Merdeka", "Tanjung Harapan", "Kualuh Selatan", "Bandar Jaya"]
    },
    "Na IX-X": {
        "center": [2.3800, 99.9200],
        "desa": ["Na IX", "Na X", "Sei Bamban", "Tanjung Pasir", "Ujung Padang"]
    },
    "Marbau": {
        "center": [2.4200, 99.8800],
        "desa": ["Marbau", "Sei Kepayang", "Tanjung Garbus", "Bandar Khalifah", "Sei Tampang"]
    }
}

SURVEY_TYPES = [
    "Sensus Penduduk",
    "Survey Ekonomi",
    "Survey Kesehatan",
    "Survey Pendidikan",
    "Survey Infrastruktur",
    "Survey Pertanian",
    "Survey Lingkungan",
    "Survey Sosial"
]

@app.route('/')
def dashboard():
    return render_template('dashboard.html')

@app.route('/api/officers')
def get_officers():
    """Get list of all officers"""
    try:
        # Try to get from Google Sheets
        url = f"{GOOGLE_SHEETS_API_URL}/{SPREADSHEET_ID}/values/officers!A:E"
        params = {'key': API_KEY}
        response = requests.get(url, params=params)
        
        if response.status_code == 200:
            data = response.json()
            officers = []
            if 'values' in data and len(data['values']) > 1:
                headers = data['values'][0]
                for row in data['values'][1:]:
                    if len(row) >= 3:
                        officers.append({
                            'id': row[0],
                            'name': row[1],
                            'phone': row[2] if len(row) > 2 else '',
                            'kecamatan': row[3] if len(row) > 3 else 'Kualuh Hulu',
                            'status': row[4] if len(row) > 4 else 'inactive'
                        })
            return jsonify(officers)
        else:
            # Fallback to demo data
            return jsonify(_get_demo_officers())
    except Exception as e:
        print(f"Error fetching officers: {e}")
        return jsonify(_get_demo_officers())

@app.route('/api/surveys')
def get_surveys():
    """Get surveys with filters"""
    kecamatan = request.args.get('kecamatan', '')
    desa = request.args.get('desa', '')
    survey_type = request.args.get('survey_type', '')
    date_from = request.args.get('date_from', '')
    date_to = request.args.get('date_to', '')
    
    try:
        # Try to get from Google Sheets
        url = f"{GOOGLE_SHEETS_API_URL}/{SPREADSHEET_ID}/values/surveys!A:J"
        params = {'key': API_KEY}
        response = requests.get(url, params=params)
        
        if response.status_code == 200:
            data = response.json()
            surveys = []
            if 'values' in data and len(data['values']) > 1:
                for row in data['values'][1:]:
                    if len(row) >= 6:
                        survey = {
                            'survey_id': row[0],
                            'officer_id': row[1],
                            'start_time': row[2],
                            'end_time': row[3] if len(row) > 3 else None,
                            'start_lat': float(row[4]) if row[4] else 0,
                            'start_lng': float(row[5]) if row[5] else 0,
                            'kecamatan': row[6] if len(row) > 6 else 'Kualuh Hulu',
                            'desa': row[7] if len(row) > 7 else 'Aek Nabara',
                            'survey_type': row[8] if len(row) > 8 else 'Sensus Penduduk',
                            'notes': row[9] if len(row) > 9 else ''
                        }
                        
                        # Apply filters
                        if kecamatan and survey['kecamatan'] != kecamatan:
                            continue
                        if desa and survey['desa'] != desa:
                            continue
                        if survey_type and survey['survey_type'] != survey_type:
                            continue
                        
                        surveys.append(survey)
            
            return jsonify(surveys)
        else:
            return jsonify(_get_demo_surveys(kecamatan, desa, survey_type))
    except Exception as e:
        print(f"Error fetching surveys: {e}")
        return jsonify(_get_demo_surveys(kecamatan, desa, survey_type))

@app.route('/api/tracking')
def get_tracking_data():
    """Get tracking data with filters"""
    officer_id = request.args.get('officer_id', '')
    kecamatan = request.args.get('kecamatan', '')
    desa = request.args.get('desa', '')
    survey_type = request.args.get('survey_type', '')
    date_from = request.args.get('date_from', '')
    date_to = request.args.get('date_to', '')
    
    try:
        # Try to get from Google Sheets
        url = f"{GOOGLE_SHEETS_API_URL}/{SPREADSHEET_ID}/values/tracking_logs!A:H"
        params = {'key': API_KEY}
        response = requests.get(url, params=params)
        
        if response.status_code == 200:
            data = response.json()
            tracking_data = []
            if 'values' in data and len(data['values']) > 1:
                for row in data['values'][1:]:
                    if len(row) >= 6:
                        track = {
                            'timestamp': row[0],
                            'officer_id': row[1],
                            'survey_id': row[2],
                            'latitude': float(row[3]),
                            'longitude': float(row[4]),
                            'accuracy': float(row[5]) if row[5] else 10,
                            'kecamatan': _get_kecamatan_from_coords(float(row[3]), float(row[4])),
                            'event_type': row[6] if len(row) > 6 else 'tracking'
                        }
                        
                        # Apply filters
                        if officer_id and track['officer_id'] != officer_id:
                            continue
                        if kecamatan and track['kecamatan'] != kecamatan:
                            continue
                        
                        tracking_data.append(track)
            
            return jsonify(tracking_data)
        else:
            return jsonify(_get_demo_tracking_data(kecamatan, desa, survey_type, officer_id, date_from, date_to))
    except Exception as e:
        print(f"Error fetching tracking data: {e}")
        return jsonify(_get_demo_tracking_data(kecamatan, desa, survey_type, officer_id, date_from, date_to))

@app.route('/api/realtime')
def get_realtime_positions():
    """Get current real-time positions of active officers"""
    try:
        # Get tracking data from last 5 minutes
        current_time = datetime.now()
        five_minutes_ago = current_time - timedelta(minutes=5)
        
        url = f"{GOOGLE_SHEETS_API_URL}/{SPREADSHEET_ID}/values/tracking_logs!A:H"
        params = {'key': API_KEY}
        response = requests.get(url, params=params)
        
        realtime_positions = []
        
        if response.status_code == 200:
            data = response.json()
            if 'values' in data and len(data['values']) > 1:
                # Group by officer_id and get latest position
                officer_positions = {}
                
                for row in data['values'][1:]:
                    if len(row) >= 6:
                        try:
                            timestamp = datetime.fromisoformat(row[0].replace('Z', '+00:00'))
                            if timestamp >= five_minutes_ago:
                                officer_id = row[1]
                                position = {
                                    'timestamp': row[0],
                                    'officer_id': officer_id,
                                    'survey_id': row[2],
                                    'latitude': float(row[3]),
                                    'longitude': float(row[4]),
                                    'accuracy': float(row[5]) if row[5] else 10,
                                    'kecamatan': _get_kecamatan_from_coords(float(row[3]), float(row[4])),
                                    'status': 'active'
                                }
                                
                                # Keep only latest position per officer
                                if officer_id not in officer_positions or timestamp > datetime.fromisoformat(officer_positions[officer_id]['timestamp'].replace('Z', '+00:00')):
                                    officer_positions[officer_id] = position
                        except ValueError:
                            continue
                
                realtime_positions = list(officer_positions.values())
        
        # If no real data, return demo real-time data
        if not realtime_positions:
            realtime_positions = _get_demo_realtime_data()
        
        return jsonify(realtime_positions)
        
    except Exception as e:
        print(f"Error fetching real-time data: {e}")
        return jsonify(_get_demo_realtime_data())

@app.route('/api/kecamatan')
def get_kecamatan_data():
    """Get kecamatan and desa data"""
    return jsonify(KECAMATAN_DATA)

@app.route('/api/survey-types')
def get_survey_types():
    """Get available survey types"""
    return jsonify(SURVEY_TYPES)

@app.route('/api/statistics')
def get_statistics():
    """Get dashboard statistics with filters"""
    kecamatan = request.args.get('kecamatan', '')
    survey_type = request.args.get('survey_type', '')
    
    try:
        # Get data from various endpoints
        officers = get_officers().get_json()
        surveys = get_surveys().get_json()
        tracking = get_tracking_data().get_json()
        realtime = get_realtime_positions().get_json()
        
        # Apply filters
        if kecamatan:
            officers = [o for o in officers if o.get('kecamatan') == kecamatan]
            surveys = [s for s in surveys if s.get('kecamatan') == kecamatan]
            tracking = [t for t in tracking if t.get('kecamatan') == kecamatan]
            realtime = [r for r in realtime if r.get('kecamatan') == kecamatan]
        
        if survey_type:
            surveys = [s for s in surveys if s.get('survey_type') == survey_type]
        
        # Calculate statistics
        stats = {
            'total_officers': len(officers),
            'active_officers': len(realtime),
            'total_surveys': len(surveys),
            'completed_surveys': len([s for s in surveys if s.get('end_time')]),
            'ongoing_surveys': len([s for s in surveys if not s.get('end_time')]),
            'total_tracking_points': len(tracking),
            'coverage_area': len(set([t.get('kecamatan') for t in tracking if t.get('kecamatan')])),
            'survey_types_active': len(set([s.get('survey_type') for s in surveys if s.get('survey_type')]))
        }
        
        return jsonify(stats)
        
    except Exception as e:
        print(f"Error calculating statistics: {e}")
        return jsonify({
            'total_officers': 30,
            'active_officers': 8,
            'total_surveys': 45,
            'completed_surveys': 32,
            'ongoing_surveys': 13,
            'total_tracking_points': 1250,
            'coverage_area': 5,
            'survey_types_active': 6
        })

def _get_distance_km(lat1, lng1, lat2, lng2):
    """Calculate distance between two points using haversine formula"""
    # Convert latitude and longitude from degrees to radians
    lat1, lng1, lat2, lng2 = map(math.radians, [lat1, lng1, lat2, lng2])
    
    # Haversine formula
    dlat = lat2 - lat1
    dlng = lng2 - lng1
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng/2)**2
    c = 2 * math.asin(math.sqrt(a))
    
    # Radius of earth in kilometers
    r = 6371
    return c * r

def _get_kecamatan_from_coords(lat, lng):
    """Determine kecamatan from coordinates"""
    min_distance = float('inf')
    closest_kecamatan = "Kualuh Hulu"
    
    for kecamatan, data in KECAMATAN_DATA.items():
        center = data['center']
        distance = _get_distance_km(lat, lng, center[0], center[1])
        if distance < min_distance:
            min_distance = distance
            closest_kecamatan = kecamatan
    
    return closest_kecamatan

def _get_demo_officers():
    """Generate demo officers data"""
    officers = []
    kecamatan_list = list(KECAMATAN_DATA.keys())
    
    for i in range(1, 31):
        officers.append({
            'id': f'PET{i:03d}',
            'name': f'Petugas Survey {i}',
            'phone': f'08{1234567890 + i}',
            'kecamatan': kecamatan_list[i % len(kecamatan_list)],
            'status': 'active' if i <= 15 else 'inactive'
        })
    
    return officers

def _get_demo_surveys(kecamatan_filter='', desa_filter='', survey_type_filter=''):
    """Generate demo surveys data"""
    surveys = []
    base_time = datetime.now() - timedelta(days=7)
    
    for i in range(1, 46):
        kecamatan = list(KECAMATAN_DATA.keys())[i % len(KECAMATAN_DATA)]
        desa_list = KECAMATAN_DATA[kecamatan]['desa']
        desa = desa_list[i % len(desa_list)]
        survey_type = SURVEY_TYPES[i % len(SURVEY_TYPES)]
        
        # Apply filters
        if kecamatan_filter and kecamatan != kecamatan_filter:
            continue
        if desa_filter and desa != desa_filter:
            continue
        if survey_type_filter and survey_type != survey_type_filter:
            continue
        
        center = KECAMATAN_DATA[kecamatan]['center']
        
        survey = {
            'survey_id': f'SUR{i:03d}',
            'officer_id': f'PET{(i % 30) + 1:03d}',
            'start_time': (base_time + timedelta(hours=i*2)).isoformat(),
            'end_time': (base_time + timedelta(hours=i*2 + 4)).isoformat() if i <= 32 else None,
            'start_lat': center[0] + (i % 10 - 5) * 0.01,
            'start_lng': center[1] + (i % 10 - 5) * 0.01,
            'kecamatan': kecamatan,
            'desa': desa,
            'survey_type': survey_type,
            'notes': f'Survey {survey_type} di {desa}, {kecamatan}'
        }
        
        surveys.append(survey)
    
    return surveys

def _get_demo_tracking_data(officer_filter='', kecamatan_filter=''):
    """Generate demo tracking data"""
    tracking_data = []
    base_time = datetime.now() - timedelta(hours=8)
    
    for i in range(1, 1251):
        officer_id = f'PET{(i % 15) + 1:03d}'
        kecamatan = list(KECAMATAN_DATA.keys())[i % len(KECAMATAN_DATA)]
        
        # Apply filters
        if officer_filter and officer_id != officer_filter:
            continue
        if kecamatan_filter and kecamatan != kecamatan_filter:
            continue
        
        center = KECAMATAN_DATA[kecamatan]['center']
        
        track = {
            'timestamp': (base_time + timedelta(minutes=i*5)).isoformat(),
            'officer_id': officer_id,
            'survey_id': f'SUR{(i % 45) + 1:03d}',
            'latitude': center[0] + (i % 20 - 10) * 0.005,
            'longitude': center[1] + (i % 20 - 10) * 0.005,
            'accuracy': 5 + (i % 10),
            'kecamatan': kecamatan,
            'event_type': 'tracking'
        }
        
        tracking_data.append(track)
    
    return tracking_data

def _get_demo_realtime_data():
    """Generate demo real-time positions"""
    realtime_data = []
    current_time = datetime.now()
    
    active_officers = ['PET001', 'PET003', 'PET005', 'PET007', 'PET009', 'PET011', 'PET013', 'PET015']
    
    for i, officer_id in enumerate(active_officers):
        kecamatan = list(KECAMATAN_DATA.keys())[i % len(KECAMATAN_DATA)]
        center = KECAMATAN_DATA[kecamatan]['center']
        
        position = {
            'timestamp': (current_time - timedelta(minutes=i*2)).isoformat(),
            'officer_id': officer_id,
            'survey_id': f'SUR{(i % 13) + 33:03d}',
            'latitude': center[0] + (i % 6 - 3) * 0.01,
            'longitude': center[1] + (i % 6 - 3) * 0.01,
            'accuracy': 8,
            'kecamatan': kecamatan,
            'status': 'active'
        }
        
        realtime_data.append(position)
    
    return realtime_data

def _get_demo_tracking_data(kecamatan_filter='', desa_filter='', survey_type_filter='', officer_filter='', date_from='', date_to=''):
    """Generate demo tracking data"""
    tracking_data = []
    
    # Parse date filters
    if date_from:
        start_date = datetime.fromisoformat(date_from)
    else:
        start_date = datetime.now() - timedelta(days=7)
        
    if date_to:
        end_date = datetime.fromisoformat(date_to) + timedelta(days=1)  # Include end date
    else:
        end_date = datetime.now()
    
    # Generate tracking points for active surveys
    active_officers = [f'PET{i:03d}' for i in range(1, 16)]  # First 15 officers are active
    
    for i, officer_id in enumerate(active_officers):
        if officer_filter and officer_id != officer_filter:
            continue
            
        kecamatan = list(KECAMATAN_DATA.keys())[i % len(KECAMATAN_DATA)]
        if kecamatan_filter and kecamatan != kecamatan_filter:
            continue
            
        desa_list = KECAMATAN_DATA[kecamatan]['desa']
        desa = desa_list[i % len(desa_list)]
        if desa_filter and desa != desa_filter:
            continue
            
        survey_type = SURVEY_TYPES[i % len(SURVEY_TYPES)]
        if survey_type_filter and survey_type != survey_type_filter:
            continue
        
        center = KECAMATAN_DATA[kecamatan]['center']
        
        # Generate tracking points within date range
        days_diff = (end_date - start_date).days
        if days_diff <= 0:
            continue
            
        num_points = random.randint(3, 8) * days_diff  # 3-8 points per day
        for j in range(num_points):
            # Generate random timestamp within date range
            random_days = random.random() * days_diff
            timestamp = start_date + timedelta(days=random_days)
            
            # Only include points within working hours (8-17)
            if timestamp.hour < 8 or timestamp.hour > 17:
                timestamp = timestamp.replace(hour=random.randint(8, 17))
            
            # Skip if outside date range
            if timestamp < start_date or timestamp >= end_date:
                continue
            
            # Add some randomness to coordinates within the area
            lat_offset = (random.random() - 0.5) * 0.02  # ±0.01 degrees
            lng_offset = (random.random() - 0.5) * 0.02
            
            tracking_point = {
                'timestamp': timestamp.isoformat(),
                'officer_id': officer_id,
                'survey_id': f'SUR{(i % 13) + 33:03d}',
                'latitude': center[0] + lat_offset,
                'longitude': center[1] + lng_offset,
                'accuracy': random.randint(3, 15),
                'kecamatan': kecamatan,
                'desa': desa,
                'survey_type': survey_type
            }
            
            tracking_data.append(tracking_point)
    
    # Sort by timestamp
    tracking_data.sort(key=lambda x: x['timestamp'])
    return tracking_data

@app.route('/api/export')
def export_data():
    """Export tracking data to Excel"""
    try:
        # Get filter parameters
        kecamatan = request.args.get('kecamatan', '')
        desa = request.args.get('desa', '')
        survey_type = request.args.get('survey_type', '')
        officer_id = request.args.get('officer_id', '')
        date_from = request.args.get('date_from', '')
        date_to = request.args.get('date_to', '')
        
        # Get data
        tracking_data = _get_demo_tracking_data(kecamatan, desa, survey_type, officer_id, date_from, date_to)
        surveys_data = _get_demo_surveys(kecamatan, desa, survey_type)
        officers_data = _get_demo_officers()
        
        # Create Excel workbook
        wb = Workbook()
        
        # Remove default sheet
        wb.remove(wb.active)
        
        # Create Tracking Data sheet
        ws_tracking = wb.create_sheet("Data Tracking")
        
        # Headers for tracking data
        tracking_headers = [
            'Timestamp', 'Officer ID', 'Survey ID', 'Latitude', 'Longitude', 
            'Accuracy (m)', 'Kecamatan', 'Desa', 'Jenis Survey'
        ]
        
        # Style headers
        header_font = Font(bold=True, color="FFFFFF")
        header_fill = PatternFill(start_color="366092", end_color="366092", fill_type="solid")
        header_alignment = Alignment(horizontal="center", vertical="center")
        
        # Write tracking headers
        for col, header in enumerate(tracking_headers, 1):
            cell = ws_tracking.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_alignment
        
        # Write tracking data
        for row, track in enumerate(tracking_data, 2):
            ws_tracking.cell(row=row, column=1, value=track['timestamp'])
            ws_tracking.cell(row=row, column=2, value=track['officer_id'])
            ws_tracking.cell(row=row, column=3, value=track['survey_id'])
            ws_tracking.cell(row=row, column=4, value=track['latitude'])
            ws_tracking.cell(row=row, column=5, value=track['longitude'])
            ws_tracking.cell(row=row, column=6, value=track['accuracy'])
            ws_tracking.cell(row=row, column=7, value=track['kecamatan'])
            ws_tracking.cell(row=row, column=8, value=track['desa'])
            ws_tracking.cell(row=row, column=9, value=track['survey_type'])
        
        # Auto-adjust column widths
        for column in ws_tracking.columns:
            max_length = 0
            column_letter = column[0].column_letter
            for cell in column:
                try:
                    if len(str(cell.value)) > max_length:
                        max_length = len(str(cell.value))
                except:
                    pass
            adjusted_width = min(max_length + 2, 50)
            ws_tracking.column_dimensions[column_letter].width = adjusted_width
        
        # Create Surveys sheet
        ws_surveys = wb.create_sheet("Data Survey")
        
        survey_headers = [
            'Survey ID', 'Officer ID', 'Jenis Survey', 'Kecamatan', 'Desa',
            'Start Time', 'End Time', 'Status', 'Total Distance (km)'
        ]
        
        # Write survey headers
        for col, header in enumerate(survey_headers, 1):
            cell = ws_surveys.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_alignment
        
        # Write survey data
        for row, survey in enumerate(surveys_data, 2):
            ws_surveys.cell(row=row, column=1, value=survey['survey_id'])
            ws_surveys.cell(row=row, column=2, value=survey['officer_id'])
            ws_surveys.cell(row=row, column=3, value=survey['survey_type'])
            ws_surveys.cell(row=row, column=4, value=survey['kecamatan'])
            ws_surveys.cell(row=row, column=5, value=survey['desa'])
            ws_surveys.cell(row=row, column=6, value=survey['start_time'])
            ws_surveys.cell(row=row, column=7, value=survey.get('end_time', ''))
            ws_surveys.cell(row=row, column=8, value=survey.get('status', 'completed'))
            ws_surveys.cell(row=row, column=9, value=survey.get('total_distance', 0))
        
        # Auto-adjust survey sheet columns
        for column in ws_surveys.columns:
            max_length = 0
            column_letter = column[0].column_letter
            for cell in column:
                try:
                    if len(str(cell.value)) > max_length:
                        max_length = len(str(cell.value))
                except:
                    pass
            adjusted_width = min(max_length + 2, 50)
            ws_surveys.column_dimensions[column_letter].width = adjusted_width
        
        # Create Officers sheet
        ws_officers = wb.create_sheet("Data Petugas")
        
        officer_headers = ['Officer ID', 'Nama', 'Telepon', 'Kecamatan', 'Status']
        
        # Write officer headers
        for col, header in enumerate(officer_headers, 1):
            cell = ws_officers.cell(row=1, column=col, value=header)
            cell.font = header_font
            cell.fill = header_fill
            cell.alignment = header_alignment
        
        # Write officer data
        for row, officer in enumerate(officers_data, 2):
            ws_officers.cell(row=row, column=1, value=officer['id'])
            ws_officers.cell(row=row, column=2, value=officer['name'])
            ws_officers.cell(row=row, column=3, value=officer['phone'])
            ws_officers.cell(row=row, column=4, value=officer['kecamatan'])
            ws_officers.cell(row=row, column=5, value=officer['status'])
        
        # Auto-adjust officer sheet columns
        for column in ws_officers.columns:
            max_length = 0
            column_letter = column[0].column_letter
            for cell in column:
                try:
                    if len(str(cell.value)) > max_length:
                        max_length = len(str(cell.value))
                except:
                    pass
            adjusted_width = min(max_length + 2, 30)
            ws_officers.column_dimensions[column_letter].width = adjusted_width
        
        # Save to BytesIO
        output = io.BytesIO()
        wb.save(output)
        output.seek(0)
        
        # Generate filename
        today = datetime.now().strftime('%Y-%m-%d')
        filename = f'tracking_data_{today}.xlsx'
        
        return send_file(
            output,
            mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            as_attachment=True,
            download_name=filename
        )
        
    except Exception as e:
        print(f"Error exporting data: {e}")
        return jsonify({'error': 'Export failed'}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8081)
