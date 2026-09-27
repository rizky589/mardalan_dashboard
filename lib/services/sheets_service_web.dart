import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:geolocator/geolocator.dart';

class SheetsService {
  static SheetsService? _instance;
  static SheetsService get instance => _instance ??= SheetsService._();
  SheetsService._();
  
  SheetsApi? _sheetsApi;
  
  // Konfigurasi Google Sheets
  static const String _spreadsheetId = 'TEMP_SPREADSHEET_ID'; // Ganti dengan ID spreadsheet Anda
  static const List<String> _scopes = [
    SheetsApi.spreadsheetsScope,
    SheetsApi.driveScope,
  ];
  
  // Service Account Credentials (untuk production, simpan di file terpisah)
  static const String _serviceAccountJson = '''
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "your-private-key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\\nYOUR_PRIVATE_KEY\\n-----END PRIVATE KEY-----\\n",
  "client_email": "your-service-account@your-project-id.iam.gserviceaccount.com",
  "client_id": "your-client-id",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/your-service-account%40your-project-id.iam.gserviceaccount.com"
}
''';

  Future<void> initialize() async {
    try {
      print('Initializing Google Sheets service...');
      // For web demo, we'll simulate the connection
      await Future.delayed(Duration(seconds: 1));
      print('Google Sheets service initialized (demo mode)');
    } catch (e) {
      print('Error initializing Sheets service: $e');
    }
  }

  Future<void> createSheetsStructure() async {
    try {
      print('Creating sheets structure (demo mode)...');
      await Future.delayed(Duration(milliseconds: 500));
      print('Sheets structure created successfully');
    } catch (e) {
      print('Error creating sheets structure: $e');
    }
  }

  Future<void> addOfficer(String officerId, String name, String phone) async {
    try {
      print('Adding officer: $officerId - $name (demo mode)');
      await Future.delayed(Duration(milliseconds: 200));
    } catch (e) {
      print('Error adding officer: $e');
    }
  }

  Future<void> startSurvey(String officerId, Position position) async {
    try {
      print('Starting survey for $officerId at ${position.latitude}, ${position.longitude} (demo mode)');
      await Future.delayed(Duration(milliseconds: 200));
    } catch (e) {
      print('Error starting survey: $e');
    }
  }

  Future<void> endSurvey(String officerId, Position position, Duration duration) async {
    try {
      print('Ending survey for $officerId. Duration: ${duration.inMinutes} minutes (demo mode)');
      await Future.delayed(Duration(milliseconds: 200));
    } catch (e) {
      print('Error ending survey: $e');
    }
  }

  Future<void> addTrackingLog(String officerId, Position position) async {
    try {
      print('Adding tracking log for $officerId (demo mode)');
      await Future.delayed(Duration(milliseconds: 100));
    } catch (e) {
      print('Error adding tracking log: $e');
    }
  }

  Future<void> addPhotoLog(String officerId, String photoUrl, Position position) async {
    try {
      print('Adding photo log for $officerId (demo mode)');
      await Future.delayed(Duration(milliseconds: 200));
    } catch (e) {
      print('Error adding photo log: $e');
    }
  }

  Future<void> addWarning(String officerId, String warningType, String description, Position position) async {
    try {
      print('Adding warning for $officerId: $warningType (demo mode)');
      await Future.delayed(Duration(milliseconds: 200));
    } catch (e) {
      print('Error adding warning: $e');
    }
  }
}
