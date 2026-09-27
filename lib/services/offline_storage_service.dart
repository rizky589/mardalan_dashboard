import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:geolocator/geolocator.dart';

class OfflineStorageService {
  static OfflineStorageService? _instance;
  static OfflineStorageService get instance => _instance ??= OfflineStorageService._();
  OfflineStorageService._();
  
  Database? _database;
  
  Future<void> initialize() async {
    if (_database != null) return;
    
    // Skip database initialization on web
    if (kIsWeb) {
      print('Offline storage disabled on web platform');
      return;
    }
    
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'tracking_offline.db');
    
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    await initialize();
    return _database!;
  }
  
  Future<void> _createTables(Database db, int version) async {
    // Table untuk tracking logs offline
    await db.execute('''
      CREATE TABLE tracking_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        officer_id TEXT NOT NULL,
        survey_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL NOT NULL,
        timestamp TEXT NOT NULL,
        event_type TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Table untuk survey data offline
    await db.execute('''
      CREATE TABLE surveys (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        survey_id TEXT NOT NULL,
        officer_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        start_latitude REAL NOT NULL,
        start_longitude REAL NOT NULL,
        end_latitude REAL,
        end_longitude REAL,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Table untuk photo logs offline
    await db.execute('''
      CREATE TABLE photo_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        officer_id TEXT NOT NULL,
        survey_id TEXT NOT NULL,
        photo_path TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp TEXT NOT NULL,
        notes TEXT,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    
    // Table untuk problem reports offline
    await db.execute('''
      CREATE TABLE problem_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        officer_id TEXT NOT NULL,
        survey_id TEXT,
        problem_type TEXT NOT NULL,
        description TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        timestamp TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }
  
  // Save tracking log offline
  Future<void> saveTrackingLog({
    required String officerId,
    required String surveyId,
    required Position position,
    required String eventType,
  }) async {
    // Skip database operations on web
    if (kIsWeb) {
      print('Demo: Tracking log saved offline for $officerId');
      return;
    }
    
    final db = await database;
    
    await db.insert('tracking_logs', {
      'officer_id': officerId,
      'survey_id': surveyId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'timestamp': DateTime.now().toIso8601String(),
      'event_type': eventType,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  // Save survey data offline
  Future<int> saveSurvey({
    required String surveyId,
    required String officerId,
    required DateTime startTime,
    required double startLatitude,
    required double startLongitude,
    String? notes,
  }) async {
    // Skip database operations on web
    if (kIsWeb) {
      print('Demo: Survey saved offline for $officerId');
      return 1;
    }
    
    final db = await database;
    
    return await db.insert('surveys', {
      'survey_id': surveyId,
      'officer_id': officerId,
      'start_time': startTime.toIso8601String(),
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'notes': notes,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  // Update survey end data
  Future<int> updateSurveyEnd({
    required String surveyId,
    required DateTime endTime,
    required Position endPosition,
    String? notes,
  }) async {
    // Skip database operations on web
    if (kIsWeb) {
      print('Demo: Survey end updated offline for $surveyId');
      return 1;
    }
    
    final db = await database;
    
    return await db.update(
      'surveys',
      {
        'end_time': endTime.toIso8601String(),
        'end_latitude': endPosition.latitude,
        'end_longitude': endPosition.longitude,
        'notes': notes,
        'synced': 0,
      },
      where: 'survey_id = ?',
      whereArgs: [surveyId],
    );
  }
  
  // Save photo log offline
  Future<void> savePhotoLog({
    required String officerId,
    required String surveyId,
    required String photoPath,
    required Position position,
    String? notes,
  }) async {
    // Skip database operations on web
    if (kIsWeb) {
      print('Demo: Photo log saved offline for $officerId');
      return;
    }
    
    final db = await database;
    
    await db.insert('photo_logs', {
      'officer_id': officerId,
      'survey_id': surveyId,
      'photo_path': photoPath,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'notes': notes,
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  // Save problem report offline
  Future<void> saveProblemReport({
    required String officerId,
    String? surveyId,
    required String problemType,
    required String description,
    Position? position,
  }) async {
    // Skip database operations on web
    if (kIsWeb) {
      print('Demo: Problem report saved offline for $officerId');
      return;
    }
    
    final db = await database;
    
    await db.insert('problem_reports', {
      'officer_id': officerId,
      'survey_id': surveyId,
      'problem_type': problemType,
      'description': description,
      'latitude': position?.latitude,
      'longitude': position?.longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  // Get unsynced data count
  Future<Map<String, int>> getUnsyncedDataCount() async {
    if (kIsWeb) {
      return {
        'tracking': 0,
        'surveys': 0,
        'photos': 0,
        'problems': 0,
        'total': 0,
      };
    }
    
    final db = await database;
    
    final trackingCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM tracking_logs WHERE synced = 0')
    ) ?? 0;
    
    final surveyCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM surveys WHERE synced = 0')
    ) ?? 0;
    
    final photoCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM photo_logs WHERE synced = 0')
    ) ?? 0;
    
    final problemCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM problem_reports WHERE synced = 0')
    ) ?? 0;
    
    return {
      'tracking': trackingCount,
      'surveys': surveyCount,
      'photos': photoCount,
      'problems': problemCount,
      'total': trackingCount + surveyCount + photoCount + problemCount,
    };
  }
  
  // Get unsynced tracking logs
  Future<List<Map<String, dynamic>>> getUnsyncedTrackingLogs() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query(
      'tracking_logs',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }
  
  // Get unsynced surveys
  Future<List<Map<String, dynamic>>> getUnsyncedSurveys() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query(
      'surveys',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }
  
  // Get unsynced photo logs
  Future<List<Map<String, dynamic>>> getUnsyncedPhotoLogs() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query(
      'photo_logs',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }
  
  // Get unsynced problem reports
  Future<List<Map<String, dynamic>>> getUnsyncedProblemReports() async {
    if (kIsWeb) return [];
    final db = await database;
    return await db.query(
      'problem_reports',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
  }
  
  // Mark data as synced
  Future<void> markAsSynced(String table, int id) async {
    if (kIsWeb) return;
    final db = await database;
    await db.update(
      table,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // Get counts of unsynced data
  Future<Map<String, int>> getUnsyncedCounts() async {
    if (kIsWeb) {
      return {
        'tracking_logs': 0,
        'surveys': 0,
        'photo_logs': 0,
        'problem_reports': 0,
      };
    }
    
    final db = await database;
    final trackingCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tracking_logs WHERE synced = 0')) ?? 0;
    final surveyCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM surveys WHERE synced = 0')) ?? 0;
    final photoCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM photo_logs WHERE synced = 0')) ?? 0;
    final problemCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM problem_reports WHERE synced = 0')) ?? 0;
    
    return {
      'tracking_logs': trackingCount,
      'surveys': surveyCount,
      'photo_logs': photoCount,
      'problem_reports': problemCount,
    };
  }

  // Clear old synced data (older than 7 days)
  Future<void> clearOldSyncedData() async {
    if (kIsWeb) return;
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: 7)).toIso8601String();
    
    await db.delete('tracking_logs', where: 'synced = 1 AND created_at < ?', whereArgs: [cutoffDate]);
    await db.delete('surveys', where: 'synced = 1 AND created_at < ?', whereArgs: [cutoffDate]);
    await db.delete('photo_logs', where: 'synced = 1 AND created_at < ?', whereArgs: [cutoffDate]);
    await db.delete('problem_reports', where: 'synced = 1 AND created_at < ?', whereArgs: [cutoffDate]);
  }
}
