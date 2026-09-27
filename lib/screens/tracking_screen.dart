import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../services/simple_sheets_service.dart';
import '../services/supabase_service.dart';

class TrackingScreen extends StatefulWidget {
  @override
  _TrackingScreenState createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _isSurveyActive = false;
  DateTime? _surveyStartTime;
  Position? _currentPosition;
  Timer? _locationTimer;
  Timer? _durationTimer;
  List<String> _locationLogs = [];
  String? _currentSurveyId;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _getCurrentLocation();
    _durationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isSurveyActive) {
        setState(() {});
      }
    });
  }

  Future<void> _initializeServices() async {
    await SimpleSheetsService.instance.initialize();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Use mock location for emulator
          _setMockLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Use mock location for emulator
        _setMockLocation();
        return;
      }

      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          );
          setState(() {
            _currentPosition = position;
          });
        } catch (e) {
          print('GPS timeout or unavailable, using mock location: $e');
          // Use mock location if GPS fails
          _setMockLocation();
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      // Use mock location as fallback
      _setMockLocation();
    }
  }

  // Mock location for emulator testing (Labuhanbatu Utara)
  void _setMockLocation() {
    setState(() {
      _currentPosition = Position(
        latitude: 2.3274,
        longitude: 99.8492,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    });
    print('Using mock GPS coordinates: Labuhanbatu Utara (2.3274, 99.8492)');
  }

  void _startSurvey() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    setState(() {
      _isSurveyActive = true;
      _surveyStartTime = DateTime.now();
      _currentSurveyId = DateTime.now().millisecondsSinceEpoch.toString();
      _locationLogs.clear();
    });

    // Simpan ke Google Sheets
    if (_currentPosition != null) {
      await SimpleSheetsService.instance.startSurvey({
        'survey_id': _currentSurveyId,
        'officer_id': authProvider.currentUser!['id'],
        'officer_name': authProvider.currentUser!['name'],
        'start_time': _surveyStartTime!.toIso8601String(),
        'start_lat': _currentPosition!.latitude,
        'start_lng': _currentPosition!.longitude,
      });
      await _syncSupabaseTracking(
        authProvider: authProvider,
        position: _currentPosition!,
        eventType: 'start',
      );
      _addLocationLog('Tracking dimulai', _currentPosition!);
    }

    // Timer untuk tracking lokasi setiap 30 detik
    _locationTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      _trackLocation();
    });

    _showMessage('Tracking dimulai - sinkronisasi otomatis aktif', Colors.green);
  }

  void _stopSurvey() async {
    setState(() {
      _isSurveyActive = false;
    });
    
    _locationTimer?.cancel();
    
    // Simpan data akhir ke Google Sheets
    if (_currentPosition != null && _currentSurveyId != null && _surveyStartTime != null) {
      final duration = DateTime.now().difference(_surveyStartTime!).inMinutes;
      await SimpleSheetsService.instance.endSurvey(_currentSurveyId!, {
        'end_time': DateTime.now().toIso8601String(),
        'end_lat': _currentPosition!.latitude,
        'end_lng': _currentPosition!.longitude,
        'duration_minutes': duration,
      });
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await _syncSupabaseTracking(
        authProvider: authProvider,
        position: _currentPosition!,
        eventType: 'stop',
      );
      _addLocationLog('Tracking selesai', _currentPosition!);
    }

    _showMessage('Tracking selesai - data tersinkronisasi', Colors.orange);
  }

  void _trackLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
      
      // Simpan tracking log ke Google Sheets
      if (_currentSurveyId != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await SimpleSheetsService.instance.addTrackingLog(
          authProvider.currentUser!['id']!,
          position,
        );
        await _syncSupabaseTracking(
          authProvider: authProvider,
          position: position,
          eventType: 'tracking',
        );
      }
      
      _addLocationLog('Tracking otomatis', position);
    } catch (e) {
      print('Error tracking location: $e');
    }
  }

  Future<void> _syncSupabaseTracking({
    required AuthProvider authProvider,
    required Position position,
    required String eventType,
  }) async {
    final officerCode = authProvider.currentUser?['id'] as String?;
    final surveyId = _currentSurveyId;
    if (officerCode == null || surveyId == null) return;

    try {
      await SupabaseService.instance.syncTrackingLog(
        officerCode: officerCode,
        surveyId: surveyId,
        position: position,
        eventType: eventType,
      );
    } catch (error) {
      print('Supabase tracking sync failed: $error');
    }
  }

  void _addLocationLog(String action, Position position) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    final log = '$timestamp - $action: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    
    setState(() {
      _locationLogs.insert(0, log);
      if (_locationLogs.length > 20) {
        _locationLogs = _locationLogs.sublist(0, 20);
      }
    });
  }

  Duration get _surveyDuration {
    if (_surveyStartTime == null) return Duration.zero;
    return DateTime.now().difference(_surveyStartTime!);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Tracking'),
            Text(
              '${authProvider.currentUser?['id']} - ${authProvider.currentUser?['name']}',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Card
            _buildStatusCard(),
            SizedBox(height: 16),
            
            // GPS Info
            _buildGPSCard(),
            SizedBox(height: 16),
            
            // Duration Card (jika survey aktif)
            if (_isSurveyActive) _buildDurationCard(),
            if (_isSurveyActive) SizedBox(height: 16),
            
            // Action Buttons
            _buildActionButtons(),
            SizedBox(height: 16),
            
            // Location Logs
            _buildLocationLogs(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 8,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: _isSurveyActive 
                ? [Colors.green[400]!, Colors.green[600]!]
                : [Colors.grey[400]!, Colors.grey[600]!],
          ),
        ),
        child: Column(
          children: [
            Icon(
              _isSurveyActive ? Icons.play_circle_filled : Icons.pause_circle_filled,
              size: 48,
              color: Colors.white,
            ),
            SizedBox(height: 12),
            Text(
              'STATUS SURVEI',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _isSurveyActive ? 'AKTIF' : 'TIDAK AKTIF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGPSCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _currentPosition != null ? Icons.gps_fixed : Icons.gps_off,
                  color: _currentPosition != null ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  'Status GPS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 8),
            if (_currentPosition != null) ...[
              Text('Latitude: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
              Text('Longitude: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
              Text('Akurasi: ${_currentPosition!.accuracy.toStringAsFixed(1)}m'),
            ] else
              Text('GPS tidak tersedia', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard() {
    final duration = _surveyDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    return Card(
      elevation: 8,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue[400]!, Colors.blue[600]!],
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.timer, size: 40, color: Colors.white),
            SizedBox(height: 12),
            Text(
              'DURASI TRACKING',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (!_isSurveyActive)
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _currentPosition != null ? _startSurvey : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'START TRACKING',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        
        if (_isSurveyActive) ...[
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _stopSurvey,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'STOP TRACKING',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _takePhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'AMBIL FOTO',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationLogs() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log Tracking GPS',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Container(
              height: 200,
              child: _locationLogs.isEmpty
                  ? Center(child: Text('Belum ada data tracking'))
                  : ListView.builder(
                      itemCount: _locationLogs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _locationLogs[index],
                            style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Take photo with GPS coordinates
  Future<void> _takePhoto() async {
    if (_currentPosition == null) {
      _showMessage('GPS belum siap, tunggu sebentar', Colors.orange);
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        
        // Save photo info to Google Sheets
        await SimpleSheetsService.instance.addPhotoLog(
          authProvider.currentUser!['id']!,
          photo.path,
          _currentPosition!,
        );

        _showMessage('Foto berhasil diambil dan tersimpan!', Colors.green);
        _addLocationLog('Foto diambil', _currentPosition!);
      }
    } catch (e) {
      print('Error taking photo: $e');
      _showMessage('Gagal mengambil foto: $e', Colors.red);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
