import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../providers/survey_provider.dart';
import '../services/offline_storage_service.dart';
import '../services/gps_service.dart';

class NotesScreen extends StatefulWidget {
  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _problemController = TextEditingController();
  
  String _selectedProblemType = 'GPS';
  Position? _currentPosition;
  bool _isLoading = false;
  
  final List<String> _problemTypes = [
    'GPS',
    'Koneksi Internet',
    'Aplikasi Error',
    'Perangkat Rusak',
    'Cuaca Buruk',
    'Akses Lokasi Terblokir',
    'Baterai Lemah',
    'Lainnya'
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final gpsResult = await GPSService.validateGPSIntegrity();
      if (gpsResult.isValid && gpsResult.position != null) {
        setState(() {
          _currentPosition = gpsResult.position;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Catatan & Laporan'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Survei Notes Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.note_add, color: Colors.blue[700], size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Catatan Survei',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Tulis catatan survei, kondisi lapangan, atau informasi penting lainnya...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.blue[700]!),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveNotes,
                        icon: _isLoading 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(Icons.save),
                        label: Text(_isLoading ? 'Menyimpan...' : 'Simpan Catatan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Problem Report Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.report_problem, color: Colors.orange[700], size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Lapor Masalah',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    
                    // Problem Type Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedProblemType,
                      decoration: InputDecoration(
                        labelText: 'Jenis Masalah',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange[700]!),
                        ),
                      ),
                      items: _problemTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedProblemType = value!;
                        });
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Problem Description
                    TextField(
                      controller: _problemController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Jelaskan masalah yang dihadapi secara detail...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.orange[700]!),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Location Info
                    if (_currentPosition != null)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lokasi: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _reportProblem,
                        icon: _isLoading 
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(Icons.send),
                        label: Text(_isLoading ? 'Mengirim...' : 'Kirim Laporan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Quick Actions
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aksi Cepat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _quickReport('GPS Bermasalah'),
                            icon: Icon(Icons.gps_off, size: 18),
                            label: Text('GPS Error', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[600],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _quickReport('Koneksi Internet Hilang'),
                            icon: Icon(Icons.wifi_off, size: 18),
                            label: Text('No Internet', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _quickReport('Baterai Lemah'),
                            icon: Icon(Icons.battery_alert, size: 18),
                            label: Text('Low Battery', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber[600],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNotes() async {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Catatan tidak boleh kosong'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final surveyProvider = Provider.of<SurveyProvider>(context, listen: false);
      
      // Update survey notes
      if (surveyProvider.currentSurveyId != null) {
        await OfflineStorageService.instance.updateSurveyEnd(
          surveyId: surveyProvider.currentSurveyId!,
          endTime: DateTime.now(),
          endPosition: _currentPosition ?? Position(
            latitude: 2.3274,
            longitude: 99.8492,
            timestamp: DateTime.now(),
            accuracy: 10.0,
            altitude: 50.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 1.0,
            altitudeAccuracy: 1.0,
            headingAccuracy: 1.0,
          ),
          notes: _notesController.text.trim(),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Catatan berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
      
      _notesController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error menyimpan catatan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reportProblem() async {
    if (_problemController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deskripsi masalah tidak boleh kosong'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final surveyProvider = Provider.of<SurveyProvider>(context, listen: false);
      
      await OfflineStorageService.instance.saveProblemReport(
        officerId: authProvider.currentUser?['id'] ?? 'UNKNOWN',
        surveyId: surveyProvider.currentSurveyId,
        problemType: _selectedProblemType,
        description: _problemController.text.trim(),
        position: _currentPosition,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan masalah berhasil dikirim'),
          backgroundColor: Colors.green,
        ),
      );
      
      _problemController.clear();
      setState(() => _selectedProblemType = 'GPS');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error mengirim laporan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _quickReport(String problem) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final surveyProvider = Provider.of<SurveyProvider>(context, listen: false);
      
      String problemType = 'Lainnya';
      if (problem.contains('GPS')) problemType = 'GPS';
      else if (problem.contains('Internet')) problemType = 'Koneksi Internet';
      else if (problem.contains('Baterai')) problemType = 'Baterai Lemah';
      
      await OfflineStorageService.instance.saveProblemReport(
        officerId: authProvider.currentUser?['id'] ?? 'UNKNOWN',
        surveyId: surveyProvider.currentSurveyId,
        problemType: problemType,
        description: problem,
        position: _currentPosition,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Laporan "$problem" berhasil dikirim'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error mengirim laporan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _problemController.dispose();
    super.dispose();
  }
}
