import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();
  ConnectivityService._();
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  bool _isConnected = true;
  bool _hasNotifiedOffline = false;
  
  // Stream controllers
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  // Getters
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;
  
  // Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    final ConnectivityResult result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }
  
  void _updateConnectionStatus(ConnectivityResult result) {
    bool wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    // Notify listeners
    _connectionController.add(_isConnected);
    
    // Show notifications for connection changes
    if (wasConnected && !_isConnected) {
      _showOfflineNotification();
      _hasNotifiedOffline = true;
    } else if (!wasConnected && _isConnected && _hasNotifiedOffline) {
      _showOnlineNotification();
      _hasNotifiedOffline = false;
    }
  }
  
  Future<void> _showOfflineNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'connectivity_channel',
      'Connectivity Status',
      channelDescription: 'Notifikasi status koneksi internet',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_signal_wifi_off',
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await FlutterLocalNotificationsPlugin().show(
      1,
      '📶 Koneksi Internet Hilang',
      'Data akan disimpan offline dan dikirim saat koneksi kembali',
      platformChannelSpecifics,
    );
  }
  
  Future<void> _showOnlineNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'connectivity_channel',
      'Connectivity Status',
      channelDescription: 'Notifikasi status koneksi internet',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_signal_wifi_4_bar',
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await FlutterLocalNotificationsPlugin().show(
      2,
      '📶 Koneksi Internet Kembali',
      'Sinkronisasi data offline dimulai...',
      platformChannelSpecifics,
    );
  }
  
  Future<void> showDataSyncNotification(int pendingCount) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sync_channel',
      'Data Sync',
      channelDescription: 'Notifikasi sinkronisasi data',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showProgress: true,
      maxProgress: 100,
      progress: 0,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await FlutterLocalNotificationsPlugin().show(
      3,
      '🔄 Sinkronisasi Data',
      '$pendingCount data belum terkirim ke server',
      platformChannelSpecifics,
    );
  }
  
  Future<void> hideSyncNotification() async {
    await FlutterLocalNotificationsPlugin().cancel(3);
  }
  
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
  }
}
