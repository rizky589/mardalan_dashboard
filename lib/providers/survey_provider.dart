import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../services/location_service.dart';
import '../services/simple_sheets_service.dart';
import '../services/gps_service.dart';

class SurveyProvider extends ChangeNotifier {
  bool _isSurveyActive = false;
  String? _currentSurveyId;
  DateTime? _surveyStartTime;
  int _photoCount = 0;
  String? _error;
  bool _isLoading = false;
  List<String> _gpsWarnings = [];
  
  // GPS Status
  bool _isGpsValid = true;
  String? _gpsError;
  
  // Getters
  bool get isSurveyActive => _isSurveyActive;
  String? get currentSurveyId => _currentSurveyId;
  DateTime? get surveyStartTime => _surveyStartTime;
  int get photoCount => _photoCount;
  String? get error => _error;
  bool get isLoading => _isLoading;
  List<String> get gpsWarnings => _gpsWarnings;
  bool get isGpsValid => _isGpsValid;
  String? get gpsError => _gpsError;
  
  // Duration survey
  Duration get surveyDuration {
    if (_surveyStartTime == null) return Duration.zero;
    return DateTime.now().difference(_surveyStartTime!);
  }
  
  SurveyProvider() {
    _initializeGPSMonitoring();
  }
  
  // Initialize GPS monitoring
  void _initializeGPSMonitoring() {
    // Listen to GPS warnings dari LocationService
    LocationService.instance.warningStream.listen((warning) {
      _addGpsWarning(warning);
    });
  }
  
  // Mulai survey
  Future<bool> startSurvey(String officerId, String officerName) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Validasi GPS terlebih dahulu
      final gpsResult = await GPSService.validateGPSIntegrity();
      if (!gpsResult.isValid) {
        _error = gpsResult.error;
        _isGpsValid = false;
        _gpsError = gpsResult.error;
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      _isGpsValid = true;
      _gpsError = null;
      
      // Generate survey ID
      _currentSurveyId = Uuid().v4();
      _surveyStartTime = DateTime.now();
      _photoCount = 0;
      _gpsWarnings.clear();
      
      // Simpan data survey ke Google Sheets
      await SimpleSheetsService.instance.startSurvey({
        'survey_id': _currentSurveyId,
        'officer_id': officerId,
        'officer_name': officerName,
        'start_time': _surveyStartTime!.toIso8601String(),
        'start_lat': gpsResult.position!.latitude,
        'start_lng': gpsResult.position!.longitude,
      });
      
      // Mulai location tracking
      await LocationService.instance.startTracking(officerId, _currentSurveyId!);
      
      _isSurveyActive = true;
      _isLoading = false;
      notifyListeners();
      
      return true;
      
    } catch (e) {
      _error = 'Gagal memulai survey: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Selesai survey
  Future<bool> endSurvey() async {
    if (!_isSurveyActive || _currentSurveyId == null) {
      _error = 'Survey tidak aktif atau ID survey tidak ditemukan';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Dapatkan lokasi akhir (optional untuk web)
      Position? currentLocation;
      try {
        currentLocation = await LocationService.instance.getCurrentLocation();
      } catch (e) {
        print('Warning: Tidak dapat mendapatkan lokasi akhir (normal untuk web): $e');
        // Untuk web, gunakan lokasi default atau skip
      }
      
      // Hitung durasi
      final duration = surveyDuration;
      
      // Stop location tracking
      try {
        await LocationService.instance.stopTracking();
      } catch (e) {
        print('Warning: Error stopping location tracking: $e');
      }
      
      // Update data survey di Google Sheets (demo mode)
      try {
        await SimpleSheetsService.instance.endSurvey(_currentSurveyId!, {
          'end_time': DateTime.now().toIso8601String(),
          'end_lat': currentLocation?.latitude ?? 0.0,
          'end_lng': currentLocation?.longitude ?? 0.0,
          'duration_minutes': duration.inMinutes,
        });
      } catch (e) {
        print('Demo mode: Survey ended - $e');
      }
      
      // Reset state
      _isSurveyActive = false;
      _currentSurveyId = null;
      _surveyStartTime = null;
      _photoCount = 0;
      _isLoading = false;
      notifyListeners();
      
      return true;
      
    } catch (e) {
      _error = 'Gagal mengakhiri survey: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Upload foto
  Future<bool> uploadPhoto(String photoPath) async {
    if (!_isSurveyActive) {
      _error = 'Survey tidak aktif';
      notifyListeners();
      return false;
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Upload foto dengan geotag
      await LocationService.instance.uploadPhotoWithLocation(photoPath);
      
      _photoCount++;
      _isLoading = false;
      notifyListeners();
      
      return true;
      
    } catch (e) {
      _error = 'Gagal upload foto: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Validasi GPS secara manual
  Future<void> validateGPS() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final gpsResult = await GPSService.validateGPSIntegrity();
      _isGpsValid = gpsResult.isValid;
      _gpsError = gpsResult.error;
      
      if (!gpsResult.isValid) {
        _addGpsWarning(gpsResult.error!);
        
        // Simpan warning ke sheets jika survey aktif
        if (_isSurveyActive && _currentSurveyId != null) {
          await SimpleSheetsService.instance.addWarning(
            LocationService.instance.currentOfficerId ?? '',
            _currentSurveyId,
            'GPS_VALIDATION',
            gpsResult.error!,
            gpsResult.warningLevel.toString(),
          );
        }
      }
      
    } catch (e) {
      _gpsError = 'Error validasi GPS: $e';
      _isGpsValid = false;
    }
    
    _isLoading = false;
    notifyListeners();
  }
  
  // Tambah GPS warning
  void _addGpsWarning(String warning) {
    _gpsWarnings.insert(0, '${DateTime.now().toString().substring(11, 19)}: $warning');
    
    // Simpan maksimal 20 warning terakhir
    if (_gpsWarnings.length > 20) {
      _gpsWarnings = _gpsWarnings.sublist(0, 20);
    }
    
    notifyListeners();
  }
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Clear GPS warnings
  void clearGpsWarnings() {
    _gpsWarnings.clear();
    notifyListeners();
  }
  
  // Force stop survey (untuk emergency)
  Future<void> forceStopSurvey() async {
    try {
      await LocationService.instance.stopTracking();
      
      _isSurveyActive = false;
      _currentSurveyId = null;
      _surveyStartTime = null;
      _photoCount = 0;
      notifyListeners();
      
    } catch (e) {
      print('Error force stopping survey: $e');
    }
  }
  
  @override
  void dispose() {
    LocationService.instance.dispose();
    super.dispose();
  }
}
