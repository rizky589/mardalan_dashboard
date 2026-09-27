import 'package:geolocator/geolocator.dart';

class SimpleSheetsService {
  static SimpleSheetsService? _instance;
  static SimpleSheetsService get instance => _instance ??= SimpleSheetsService._();
  SimpleSheetsService._();
  
  bool _isInitialized = false;
  
  // Demo mode - tidak perlu Google Sheets credentials untuk testing
  Future<void> initialize() async {
    await Future.delayed(Duration(milliseconds: 500)); // Simulate initialization
    _isInitialized = true;
    print('SimpleSheetsService initialized in demo mode');
  }
  
  // Get officers list. Data petugas produksi berasal dari Supabase/Admin.
  Future<List<Map<String, dynamic>>> getOfficers() async {
    return [];
  }
  
  // Add officer (demo - just print)
  Future<void> addOfficer(Map<String, dynamic> officerData) async {
    print('Demo: Adding officer ${officerData['id']} - ${officerData['name']}');
  }
  
  // Start survey (demo - just print)
  Future<void> startSurvey(Map<String, dynamic> surveyData) async {
    print('Demo: Starting survey ${surveyData['survey_id']} for ${surveyData['officer_name']}');
    print('Start coordinates: ${surveyData['start_lat']}, ${surveyData['start_lng']}');
  }
  
  // End survey (demo - just print)
  Future<void> endSurvey(String surveyId, Map<String, dynamic> endData) async {
    print('Demo: Ending survey $surveyId');
    print('End coordinates: ${endData['end_lat']}, ${endData['end_lng']}');
    print('Duration: ${endData['duration_minutes']} minutes');
  }
  
  // Add tracking log (demo - just print)
  Future<void> addTrackingLog(String officerId, Position position) async {
    print('Demo: Tracking log for $officerId at ${position.latitude}, ${position.longitude}');
  }
  
  // Add survey (demo - just print)
  Future<void> addSurvey(String officerId, Map<String, dynamic> surveyData) async {
    print('Demo: Adding survey ${surveyData['survey_id']} for $officerId');
  }
  
  // Add photo log (demo - just print)
  Future<void> addPhotoLog(String officerId, String photoUrl, Position position) async {
    print('Demo: Photo uploaded by $officerId at ${position.latitude}, ${position.longitude}');
  }
  
  // Add problem report (demo - just print)
  Future<void> addProblemReport(String officerId, Map<String, dynamic> reportData) async {
    print('Demo: Problem report from $officerId: ${reportData['problem_type']}');
  }
  
  // Add warning (demo - just print)
  Future<void> addWarning(String officerId, String? surveyId, String warningType, String message, String severity) async {
    print('Demo: Warning for $officerId - $warningType: $message ($severity)');
  }
  
  bool get isInitialized => _isInitialized;
}
