import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_config.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  SupabaseService._();

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('supabase_access_token');

    return {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${accessToken ?? SupabaseConfig.anonKey}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };
  }

  Uri _restUri(String table, [Map<String, String>? query]) {
    final base = SupabaseConfig.url.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base/rest/v1/$table').replace(queryParameters: query);
  }

  Future<bool> syncTrackingLog({
    required String officerCode,
    required String surveyId,
    required Position position,
    required String eventType,
    DateTime? recordedAt,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      print('Supabase belum dikonfigurasi. Tracking tetap disimpan lokal.');
      return false;
    }

    final headers = await _headers();
    final profile = await _findProfileByOfficerCode(officerCode);
    if (profile == null) {
      throw Exception('Petugas $officerCode belum ada/approved di Supabase.');
    }

    final assignment = await _findActiveAssignment(profile['id'] as String, surveyId);
    if (assignment == null) {
      throw Exception('Penugasan aktif untuk $officerCode belum ada di Supabase.');
    }

    final payload = {
      'officer_id': profile['id'],
      'assignment_id': assignment['id'],
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'event_type': eventType,
      'sync_status': 'synced',
      'recorded_at': (recordedAt ?? position.timestamp).toIso8601String(),
    };

    final response = await http.post(
      _restUri('tracking_logs'),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal sync tracking Supabase: ${response.statusCode} ${response.body}');
    }

    return true;
  }

  Future<Map<String, dynamic>?> _findProfileByOfficerCode(String officerCode) async {
    final response = await http.get(
      _restUri('profiles', {
        'select': 'id,officer_code,full_name,status',
        'officer_code': 'eq.$officerCode',
        'status': 'eq.approved',
        'limit': '1',
      }),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal membaca profile Supabase: ${response.statusCode} ${response.body}');
    }

    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) return null;
    return rows.first as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> _findActiveAssignment(String officerId, String surveyId) async {
    final response = await http.get(
      _restUri('assignments', {
        'select': 'id,survey_type,officer_id,status',
        'officer_id': 'eq.$officerId',
        'status': 'eq.active',
        'limit': '1',
      }),
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal membaca assignment Supabase: ${response.statusCode} ${response.body}');
    }

    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) return null;
    return rows.first as Map<String, dynamic>;
  }
}
