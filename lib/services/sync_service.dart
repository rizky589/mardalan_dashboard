import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'connectivity_service.dart';
import 'offline_storage_service.dart';
import 'simple_sheets_service.dart';
import 'supabase_service.dart';
import 'package:geolocator/geolocator.dart';

class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();
  
  bool _isSyncing = false;
  Timer? _syncTimer;
  StreamSubscription<bool>? _connectivitySubscription;
  
  Future<void> initialize() async {
    // Listen to connectivity changes
    _connectivitySubscription = ConnectivityService.instance.connectionStream.listen(
      (isConnected) {
        if (isConnected && !_isSyncing) {
          _startAutoSync();
        }
      },
    );
    
    // Start periodic sync check (every 5 minutes)
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (ConnectivityService.instance.isConnected && !_isSyncing) {
        _syncPendingData();
      }
    });
  }
  
  Future<void> _startAutoSync() async {
    await Future.delayed(Duration(seconds: 2)); // Wait a bit after connection
    await _syncPendingData();
  }
  
  Future<void> _syncPendingData() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    
    try {
      final counts = await OfflineStorageService.instance.getUnsyncedCounts();
      final totalPending = counts['total'] ?? 0;
      
      if (totalPending == 0) {
        _isSyncing = false;
        return;
      }
      
      // Show sync notification
      await ConnectivityService.instance.showDataSyncNotification(totalPending);
      
      // Sync tracking logs
      await _syncTrackingLogs();
      
      // Sync surveys
      await _syncSurveys();
      
      // Sync photo logs
      await _syncPhotoLogs();
      
      // Sync problem reports
      await _syncProblemReports();
      
      // Hide sync notification
      await ConnectivityService.instance.hideSyncNotification();
      
      // Show completion notification
      await _showSyncCompleteNotification(totalPending);
      
      // Clean old synced data
      await OfflineStorageService.instance.clearOldSyncedData();
      
    } catch (e) {
      print('Sync error: $e');
      await _showSyncErrorNotification(e.toString());
    } finally {
      _isSyncing = false;
    }
  }
  
  Future<void> _syncTrackingLogs() async {
    final logs = await OfflineStorageService.instance.getUnsyncedTrackingLogs();
    
    for (final log in logs) {
      try {
        final position = Position(
          latitude: log['latitude'],
          longitude: log['longitude'],
          timestamp: DateTime.parse(log['timestamp']),
          accuracy: log['accuracy'],
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 1.0,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        );
        
        final synced = await SupabaseService.instance.syncTrackingLog(
          officerCode: log['officer_id'],
          surveyId: log['survey_id'],
          position: position,
          eventType: log['event_type'],
          recordedAt: DateTime.parse(log['timestamp']),
        );
        
        if (synced) {
          await OfflineStorageService.instance.markAsSynced('tracking_logs', log['id']);
        }
      } catch (e) {
        print('Error syncing tracking log ${log['id']}: $e');
      }
    }
  }
  
  Future<void> _syncSurveys() async {
    final surveys = await OfflineStorageService.instance.getUnsyncedSurveys();
    
    for (final survey in surveys) {
      try {
        // Add survey start
        await SimpleSheetsService.instance.addSurvey(survey['officer_id'], {
          'survey_id': survey['survey_id'],
          'officer_id': survey['officer_id'],
          'start_time': survey['start_time'],
          'start_latitude': survey['start_latitude'],
          'start_longitude': survey['start_longitude'],
          'end_time': survey['end_time'],
          'end_latitude': survey['end_latitude'],
          'end_longitude': survey['end_longitude'],
          'notes': survey['notes'],
        });
        
        await OfflineStorageService.instance.markAsSynced('surveys', survey['id']);
      } catch (e) {
        print('Error syncing survey ${survey['id']}: $e');
      }
    }
  }
  
  Future<void> _syncPhotoLogs() async {
    final photos = await OfflineStorageService.instance.getUnsyncedPhotoLogs();
    
    for (final photo in photos) {
      try {
        final position = Position(
          latitude: photo['latitude'],
          longitude: photo['longitude'],
          timestamp: DateTime.parse(photo['timestamp']),
          accuracy: 10.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 1.0,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
        );
        
        // Upload photo and get URL (implement actual upload logic)
        final photoUrl = await _uploadPhotoToCloud(photo['photo_path']);
        
        await SimpleSheetsService.instance.addPhotoLog(
          photo['officer_id'],
          photoUrl,
          position
        );
        
        await OfflineStorageService.instance.markAsSynced('photo_logs', photo['id']);
      } catch (e) {
        print('Error syncing photo ${photo['id']}: $e');
      }
    }
  }
  
  Future<void> _syncProblemReports() async {
    final reports = await OfflineStorageService.instance.getUnsyncedProblemReports();
    
    for (final report in reports) {
      try {
        Position? position;
        if (report['latitude'] != null && report['longitude'] != null) {
          position = Position(
            latitude: report['latitude'],
            longitude: report['longitude'],
            timestamp: DateTime.parse(report['timestamp']),
            accuracy: 10.0,
            altitude: 0.0,
            heading: 0.0,
            speed: 0.0,
            speedAccuracy: 1.0,
            altitudeAccuracy: 1.0,
            headingAccuracy: 1.0,
          );
        }
        
        await SimpleSheetsService.instance.addProblemReport(report['officer_id'], {
          'officer_id': report['officer_id'],
          'survey_id': report['survey_id'],
          'problem_type': report['problem_type'],
          'description': report['description'],
          'latitude': position?.latitude,
          'longitude': position?.longitude,
          'timestamp': report['timestamp'],
        });
        
        await OfflineStorageService.instance.markAsSynced('problem_reports', report['id']);
      } catch (e) {
        print('Error syncing problem report ${report['id']}: $e');
      }
    }
  }
  
  Future<String> _uploadPhotoToCloud(String localPath) async {
    // Implement actual photo upload to cloud storage
    // For now, return a placeholder URL
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'https://storage.googleapis.com/tracking-photos/photo_$timestamp.jpg';
  }
  
  Future<void> _showSyncCompleteNotification(int syncedCount) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sync_channel',
      'Data Sync',
      channelDescription: 'Notifikasi sinkronisasi data',
      importance: Importance.low,
      priority: Priority.low,
      icon: '@drawable/ic_stat_sync',
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await FlutterLocalNotificationsPlugin().show(
      4,
      '✅ Sinkronisasi Selesai',
      '$syncedCount data berhasil dikirim ke server',
      platformChannelSpecifics,
    );
  }
  
  Future<void> _showSyncErrorNotification(String error) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sync_channel',
      'Data Sync',
      channelDescription: 'Notifikasi sinkronisasi data',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_sync_problem',
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await FlutterLocalNotificationsPlugin().show(
      5,
      '❌ Sinkronisasi Gagal',
      'Error: ${error.length > 50 ? error.substring(0, 50) + '...' : error}',
      platformChannelSpecifics,
    );
  }
  
  // Manual sync trigger
  Future<bool> forceSyncNow() async {
    if (!ConnectivityService.instance.isConnected) {
      return false;
    }
    
    await _syncPendingData();
    return true;
  }
  
  // Get sync status
  Future<Map<String, dynamic>> getSyncStatus() async {
    final counts = await OfflineStorageService.instance.getUnsyncedCounts();
    return {
      'is_syncing': _isSyncing,
      'pending_data': counts,
      'is_connected': ConnectivityService.instance.isConnected,
    };
  }
  
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
