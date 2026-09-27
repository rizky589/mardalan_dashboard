import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_storage_service.dart';
import 'connectivity_service.dart';
import 'simple_sheets_service.dart';
import 'gps_service.dart';
import 'supabase_service.dart';

class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();
  
  Timer? _trackingTimer;
  bool _isTracking = false;
  Position? _lastPosition;
  String? _currentSurveyId;
  String? _currentOfficerId;
  
  // Stream controllers
  StreamController<Position> _positionController = StreamController<Position>.broadcast();
  StreamController<String> _warningController = StreamController<String>.broadcast();
  
  // Getters
  Stream<Position> get positionStream => _positionController.stream;
  Stream<String> get warningStream => _warningController.stream;
  String? get currentOfficerId => _currentOfficerId;
  
  // Start tracking untuk survey
  Future<void> startTracking(String officerId, String surveyId) async {
    _currentOfficerId = officerId;
    _currentSurveyId = surveyId;
    _isTracking = true;
    
    // Validasi GPS integrity
    final gpsResult = await GPSService.validateGPSIntegrity();
    if (!gpsResult.isValid) {
      throw Exception(gpsResult.error);
    }
    
    // Save initial location (offline first, then sync if online)
    await _saveLocationOfflineFirst(gpsResult.position!, 'survey_start');
    
    // Start GPS monitoring
    GPSService.startGPSMonitoring(
      onStatusChange: (result) {
        if (!result.isValid && result.warningLevel == WarningLevel.critical) {
          _handleGPSWarning(result.error!);
        }
      },
    );
    
    // Start periodic tracking (45 seconds)
    _trackingTimer = Timer.periodic(Duration(seconds: 45), (timer) {
      if (_isTracking) {
        sendLocationUpdate();
      }
    });
  }
  
  // Stop tracking
  Future<void> stopTracking() async {
    _isTracking = false;
    _trackingTimer?.cancel();
    GPSService.stopGPSMonitoring();
    
    // Simpan koordinat akhir
    if (_lastPosition != null) {
      await _saveLocationOfflineFirst(_lastPosition!, 'survey_end');
    }
    
    _currentSurveyId = null;
    _currentOfficerId = null;
  }
  
  // Kirim update lokasi
  Future<void> sendLocationUpdate() async {
    if (!_isTracking || _currentSurveyId == null) return;
    
    try {
      // Validasi GPS
      final gpsResult = await GPSService.validateGPSIntegrity();
      if (!gpsResult.isValid) {
        _handleGPSWarning(gpsResult.error!);
        return;
      }
      
      Position position = gpsResult.position!;
      
      // Cek teleportasi
      if (_lastPosition != null) {
        bool isTeleport = GPSService.detectTeleportation(_lastPosition, position);
        if (isTeleport) {
          _handleGPSWarning('Pergerakan tidak wajar terdeteksi!');
          return;
        }
      }
      
      // Simpan ke offline storage first
      await _saveLocationOfflineFirst(position, 'tracking');
      _lastPosition = position;
      
    } catch (e) {
      print('Error sending location update: $e');
    }
  }
  
  // Save location offline first, then sync if online
  Future<void> _saveLocationOfflineFirst(Position position, String type) async {
    try {
      // Always save to offline storage first
      await OfflineStorageService.instance.saveTrackingLog(
        officerId: _currentOfficerId!,
        surveyId: _currentSurveyId!,
        position: position,
        eventType: type,
      );
      
      // If online, also try to sync to Supabase. Offline data remains queued if this fails.
      if (ConnectivityService.instance.isConnected) {
        try {
          final synced = await SupabaseService.instance.syncTrackingLog(
            officerCode: _currentOfficerId!,
            surveyId: _currentSurveyId!,
            position: position,
            eventType: type,
          );
          if (!synced) {
            await SimpleSheetsService.instance.addTrackingLog(_currentOfficerId!, position);
          }
        } catch (e) {
          print('Online sync failed, data saved offline: $e');
        }
      }
      
    } catch (e) {
      print('Error saving location: $e');
    }
  }
  
  // Handle GPS warning
  void _handleGPSWarning(String message) {
    // Simpan warning ke local storage
    _saveWarningLog(message);
    
    // Kirim notifikasi ke UI
    _warningController.add(message);
  }
  
  // Simpan log warning
  Future<void> _saveWarningLog(String message) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> warnings = prefs.getStringList('gps_warnings') ?? [];
    warnings.add('${DateTime.now().toIso8601String()}: $message');
    
    // Simpan maksimal 50 warning terakhir
    if (warnings.length > 50) {
      warnings = warnings.sublist(warnings.length - 50);
    }
    
    await prefs.setStringList('gps_warnings', warnings);
  }
  
  // Initialize service
  Future<void> initialize() async {
    // Request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }
  }
  
  // Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _positionController.add(position);
      return position;
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }
  
  // Get current location (alias)
  Future<Position?> getCurrentLocation() async {
    return getCurrentPosition();
  }
  
  // Upload photo with location
  Future<void> uploadPhotoWithLocation(String photoPath) async {
    try {
      final position = await getCurrentPosition();
      if (position != null && _currentOfficerId != null) {
        await _saveLocationOfflineFirst(position, 'photo');
      }
    } catch (e) {
      print('Error uploading photo with location: $e');
    }
  }
  
  // Status tracking
  bool get isTracking => _isTracking;
  String? get currentSurveyId => _currentSurveyId;
  Position? get lastPosition => _lastPosition;
  
  // Dispose resources
  void dispose() {
    _trackingTimer?.cancel();
    GPSService.stopGPSMonitoring();
    _positionController.close();
    _warningController.close();
  }
}
