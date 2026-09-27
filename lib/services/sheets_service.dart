import 'dart:convert';
import 'dart:io' as io;
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class SheetsService {
  static SheetsService? _instance;
  static SheetsService get instance => _instance ??= SheetsService._();
  SheetsService._();
  
  SheetsApi? _sheetsApi;
  
  // Konfigurasi Google Sheets - GANTI DENGAN ID SPREADSHEET ANDA
  static const String _spreadsheetId = 'YOUR_SPREADSHEET_ID_HERE';
  static const List<String> _scopes = [
    SheetsApi.spreadsheetsScope,
    SheetsApi.driveScope,
  ];
  
  // Initialize Google Sheets API
  Future<void> initialize() async {
    try {
      // Gunakan service account credentials
      final credentials = ServiceAccountCredentials.fromJson({
        "type": "service_account",
        "project_id": "your-project-id",
        "private_key_id": "your-private-key-id",
        "private_key": "-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY\n-----END PRIVATE KEY-----\n",
        "client_email": "your-service-account@your-project.iam.gserviceaccount.com",
        "client_id": "your-client-id",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40your-project.iam.gserviceaccount.com"
      });
      
      final client = await clientViaServiceAccount(credentials, _scopes);
      _sheetsApi = SheetsApi(client);
      
      // Setup sheets jika belum ada
      await _setupSheets();
      
    } catch (e) {
      print('Error initializing Sheets API: $e');
      rethrow;
    }
  }
  
  // Setup struktur sheets
  Future<void> _setupSheets() async {
    if (_sheetsApi == null) return;
    
    try {
      // Cek apakah sheet sudah ada
      final spreadsheet = await _sheetsApi!.spreadsheets.get(_spreadsheetId);
      
      List<String> existingSheets = spreadsheet.sheets!
          .map((sheet) => sheet.properties!.title!)
          .toList();
      
      // Buat sheet yang belum ada
      List<String> requiredSheets = [
        'officers',
        'surveys', 
        'tracking_logs',
        'photo_logs',
        'warnings'
      ];
      
      for (String sheetName in requiredSheets) {
        if (!existingSheets.contains(sheetName)) {
          await _createSheet(sheetName);
        }
      }
      
      // Setup headers jika sheet kosong
      await _setupHeaders();
      
    } catch (e) {
      print('Error setting up sheets: $e');
    }
  }
  
  // Buat sheet baru
  Future<void> _createSheet(String title) async {
    final request = Request()
      ..addSheet = AddSheetRequest()
      ..addSheet!.properties = SheetProperties()
      ..addSheet!.properties!.title = title;
    
    final batchRequest = BatchUpdateSpreadsheetRequest()
      ..requests = [request];
    
    await _sheetsApi!.spreadsheets.batchUpdate(batchRequest, _spreadsheetId);
  }
  
  // Setup headers untuk setiap sheet
  Future<void> _setupHeaders() async {
    // Headers untuk officers
    await _updateSheetHeaders('officers', [
      'id', 'name', 'phone', 'email', 'status', 'created_at'
    ]);
    
    // Headers untuk surveys
    await _updateSheetHeaders('surveys', [
      'survey_id', 'officer_id', 'officer_name', 'start_time', 'end_time', 
      'start_lat', 'start_lng', 'end_lat', 'end_lng', 'duration_minutes', 
      'total_photos', 'status'
    ]);
    
    // Headers untuk tracking_logs
    await _updateSheetHeaders('tracking_logs', [
      'timestamp', 'officer_id', 'survey_id', 'latitude', 'longitude', 
      'accuracy', 'altitude', 'speed', 'heading', 'type'
    ]);
    
    // Headers untuk photo_logs
    await _updateSheetHeaders('photo_logs', [
      'timestamp', 'officer_id', 'survey_id', 'latitude', 'longitude', 
      'photo_url', 'accuracy', 'description'
    ]);
    
    // Headers untuk warnings
    await _updateSheetHeaders('warnings', [
      'timestamp', 'officer_id', 'survey_id', 'warning_type', 'message', 'severity'
    ]);
  }
  
  // Update headers sheet
  Future<void> _updateSheetHeaders(String sheetName, List<String> headers) async {
    try {
      // Cek apakah sudah ada data di row 1
      final range = '$sheetName!A1:Z1';
      final response = await _sheetsApi!.spreadsheets.values.get(_spreadsheetId, range);
      
      if (response.values == null || response.values!.isEmpty) {
        // Tambahkan headers
        final valueRange = ValueRange()
          ..values = [headers];
        
        await _sheetsApi!.spreadsheets.values.update(
          valueRange,
          _spreadsheetId,
          range,
          valueInputOption: 'RAW',
        );
      }
    } catch (e) {
      print('Error updating headers for $sheetName: $e');
    }
  }
  
  // Tambah data petugas
  Future<void> addOfficer(Map<String, dynamic> officerData) async {
    await _appendToSheet('officers', [
      officerData['id'],
      officerData['name'],
      officerData['phone'] ?? '',
      officerData['email'] ?? '',
      officerData['status'] ?? 'active',
      DateTime.now().toIso8601String(),
    ]);
  }
  
  // Mulai survey baru
  Future<void> startSurvey(Map<String, dynamic> surveyData) async {
    await _appendToSheet('surveys', [
      surveyData['survey_id'],
      surveyData['officer_id'],
      surveyData['officer_name'],
      surveyData['start_time'],
      '', // end_time (kosong)
      surveyData['start_lat'],
      surveyData['start_lng'],
      '', // end_lat (kosong)
      '', // end_lng (kosong)
      '', // duration_minutes (kosong)
      0, // total_photos
      'active',
    ]);
  }
  
  // Selesai survey
  Future<void> endSurvey(String surveyId, Map<String, dynamic> endData) async {
    // Update survey yang sudah ada
    await _updateSurveyRow(surveyId, {
      'end_time': endData['end_time'],
      'end_lat': endData['end_lat'],
      'end_lng': endData['end_lng'],
      'duration_minutes': endData['duration_minutes'],
      'status': 'completed',
    });
  }
  
  // Update row survey
  Future<void> _updateSurveyRow(String surveyId, Map<String, dynamic> updates) async {
    try {
      // Cari row dengan survey_id yang sesuai
      final range = 'surveys!A:L';
      final response = await _sheetsApi!.spreadsheets.values.get(_spreadsheetId, range);
      
      if (response.values != null) {
        for (int i = 1; i < response.values!.length; i++) { // Skip header
          List<dynamic> row = response.values![i];
          if (row.isNotEmpty && row[0] == surveyId) {
            // Update kolom yang sesuai
            if (updates.containsKey('end_time')) row[4] = updates['end_time'];
            if (updates.containsKey('end_lat')) row[7] = updates['end_lat'];
            if (updates.containsKey('end_lng')) row[8] = updates['end_lng'];
            if (updates.containsKey('duration_minutes')) row[9] = updates['duration_minutes'];
            if (updates.containsKey('status')) row[11] = updates['status'];
            
            // Update row
            final updateRange = 'surveys!A${i + 1}:L${i + 1}';
            final valueRange = ValueRange()..values = [row];
            
            await _sheetsApi!.spreadsheets.values.update(
              valueRange,
              _spreadsheetId,
              updateRange,
              valueInputOption: 'RAW',
            );
            break;
          }
        }
      }
    } catch (e) {
      print('Error updating survey row: $e');
    }
  }
  
  // Tambah tracking log (overloaded method)
  Future<void> addTrackingLog(String officerId, Position position) async {
    await _appendToSheet('tracking_logs', [
      DateTime.now().toIso8601String(),
      officerId,
      '', // survey_id will be set by location service
      position.latitude,
      position.longitude,
      position.accuracy,
      position.altitude,
      position.speed,
      position.heading,
      'tracking',
    ]);
  }
  
  // Tambah tracking log dengan data lengkap
  Future<void> addTrackingLogWithData(Map<String, dynamic> locationData) async {
    await _appendToSheet('tracking_logs', [
      locationData['timestamp'],
      locationData['officer_id'],
      locationData['survey_id'],
      locationData['latitude'],
      locationData['longitude'],
      locationData['accuracy'],
      locationData['altitude'],
      locationData['speed'],
      locationData['heading'],
      locationData['type'],
    ]);
  }
  
  // Tambah photo log (overloaded method)
  Future<void> addPhotoLog(String officerId, String photoUrl, Position position) async {
    await _appendToSheet('photo_logs', [
      DateTime.now().toIso8601String(),
      officerId,
      '', // survey_id will be set by survey provider
      position.latitude,
      position.longitude,
      photoUrl,
      position.accuracy,
      'Survey photo',
    ]);
  }
  
  // Tambah photo log dengan data lengkap
  Future<void> addPhotoLogWithData(Map<String, dynamic> photoData) async {
    await _appendToSheet('photo_logs', [
      photoData['timestamp'],
      photoData['officer_id'],
      photoData['survey_id'],
      photoData['latitude'],
      photoData['longitude'],
      photoData['photo_url'],
      photoData['accuracy'],
      photoData['description'] ?? '',
    ]);
  }
  
  // Tambah warning log
  Future<void> addWarning(String officerId, String? surveyId, String warningType, String message, String severity) async {
    await _appendToSheet('warnings', [
      DateTime.now().toIso8601String(),
      officerId,
      surveyId ?? '',
      warningType,
      message,
      severity,
    ]);
  }
  
  // Upload foto ke Google Drive dan simpan URL ke Sheets
  Future<String> uploadPhoto(String photoPath, Position position) async {
    try {
      final file = io.File(photoPath);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(photoPath)}';
      
      // Demo mode - return local file reference
      final downloadUrl = 'https://drive.google.com/file/d/demo_${fileName}/view';
      
      // TODO: Implement Google Drive API upload
      // final driveApi = DriveApi(_authClient);
      // final media = Media(file.openRead(), file.lengthSync());
      // final driveFile = await driveApi.files.create(
      //   File()..name = fileName,
      //   uploadMedia: media,
      // );
      
      print('Demo: Photo uploaded - $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading photo: $e');
      rethrow;
    }
  }
  
  // Initialize default officers
  Future<void> initializeDefaultOfficers() async {
    try {
      final officers = await getOfficers();
      for (final officer in officers) {
        await addOfficer({
          'id': officer['id']!,
          'name': officer['name']!,
          'phone': officer['phone']!,
          'email': '',
          'status': 'active',
        });
      }
    } catch (e) {
      print('Error initializing default officers: $e');
    }
  }
  
  // Helper method untuk append data ke sheet
  Future<void> _appendToSheet(String sheetName, List<dynamic> values) async {
    try {
      final range = '$sheetName!A:Z';
      final valueRange = ValueRange()
        ..values = [values];
      
      await _sheetsApi!.spreadsheets.values.append(
        valueRange,
        _spreadsheetId,
        range,
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );
    } catch (e) {
      print('Error appending to $sheetName: $e');
    }
  }
  
  
  // Get officers list. Data petugas produksi berasal dari Supabase/Admin.
  Future<List<Map<String, dynamic>>> getOfficers() async {
    return [];
  }

  // Check if service is initialized
  bool get isInitialized => _sheetsApi != null;
}
