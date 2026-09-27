import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_config.dart';

class SupabaseAuthSession {
  const SupabaseAuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.authUserId,
    required this.profile,
  });

  final String accessToken;
  final String refreshToken;
  final String authUserId;
  final Map<String, dynamic> profile;
}

class SupabaseAuthService {
  static SupabaseAuthService? _instance;
  static SupabaseAuthService get instance => _instance ??= SupabaseAuthService._();
  SupabaseAuthService._();

  Uri _authUri(String path, [Map<String, String>? query]) {
    final base = SupabaseConfig.url.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base/auth/v1/$path').replace(queryParameters: query);
  }

  Uri _restUri(String table, [Map<String, String>? query]) {
    final base = SupabaseConfig.url.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base/rest/v1/$table').replace(queryParameters: query);
  }

  Map<String, String> get _anonHeaders => {
        'apikey': SupabaseConfig.anonKey,
        'Content-Type': 'application/json',
      };

  Map<String, String> _authHeaders(String accessToken) => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  Future<void> registerPendingProfile({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String role,
    required String kabupaten,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('Supabase belum dikonfigurasi.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    String authUserId = '';
    String? accessToken;

    final signUpResponse = await http.post(
      _authUri('signup'),
      headers: _anonHeaders,
      body: jsonEncode({
        'email': normalizedEmail,
        'password': password,
      }),
    );

    if (signUpResponse.statusCode == 429) {
      throw Exception(
        'Terlalu banyak percobaan registrasi. Tunggu beberapa menit lalu coba lagi.',
      );
    }

    if (signUpResponse.statusCode >= 200 && signUpResponse.statusCode < 300) {
      final signUpData = jsonDecode(signUpResponse.body) as Map<String, dynamic>;
      accessToken = signUpData['access_token'] as String?;
      authUserId =
          signUpData['id'] as String? ?? signUpData['user']?['id'] as String? ?? '';
    } else {
      final signInResponse = await _passwordGrant(
        email: normalizedEmail,
        password: password,
      );

      if (signInResponse.statusCode < 200 || signInResponse.statusCode >= 300) {
        throw Exception(
          'Registrasi Supabase Auth gagal: ${signUpResponse.statusCode} ${signUpResponse.body}',
        );
      }

      final signInData = jsonDecode(signInResponse.body) as Map<String, dynamic>;
      accessToken = signInData['access_token'] as String?;
      authUserId = signInData['user']?['id'] as String? ?? '';
    }

    if (authUserId.isEmpty && accessToken != null) {
      authUserId = _jwtSub(accessToken);
    }

    if (authUserId.isEmpty) {
      throw Exception('Akun Auth berhasil dibuat, tetapi ID user tidak terbaca.');
    }

    final existingProfileResponse = await http.get(
      _restUri('profiles', {
        'select': 'id,status',
        'email': 'eq.$normalizedEmail',
        'limit': '1',
      }),
      headers: accessToken != null ? _authHeaders(accessToken) : _anonHeaders,
    );

    if (existingProfileResponse.statusCode >= 200 &&
        existingProfileResponse.statusCode < 300) {
      final existingRows = jsonDecode(existingProfileResponse.body) as List<dynamic>;
      if (existingRows.isNotEmpty) {
        return;
      }
    }

    final officerCode = normalizedEmail.split('@').first.toUpperCase();
    final appRole = role == 'PML' ? 'supervisor' : 'petugas';

    final profileResponse = await http.post(
      _restUri('profiles'),
      headers: {
        ...(accessToken != null ? _authHeaders(accessToken) : _anonHeaders),
        'Prefer': 'return=representation',
      },
      body: jsonEncode({
        'auth_user_id': authUserId,
        'officer_code': officerCode,
        'full_name': fullName.trim(),
        'email': normalizedEmail,
        'phone': phone.trim(),
        'role': appRole,
        'status': 'pending',
        'kecamatan': kabupaten.trim(),
      }),
    );

    if (profileResponse.statusCode < 200 || profileResponse.statusCode >= 300) {
      throw Exception(
        'Registrasi profile pending gagal: ${profileResponse.statusCode} ${profileResponse.body}',
      );
    }
  }

  Future<http.Response> _passwordGrant({
    required String email,
    required String password,
  }) {
    return http.post(
      _authUri('token', {'grant_type': 'password'}),
      headers: _anonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
  }

  Future<SupabaseAuthSession> signIn({
    required String email,
    required String password,
  }) async {
    if (!SupabaseConfig.isConfigured) {
      throw Exception('Supabase belum dikonfigurasi.');
    }

    final response = await _passwordGrant(
      email: email,
      password: password,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Login Supabase gagal: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String? ?? '';
    final authUserId = data['user']?['id'] as String? ?? '';
    final profile = await loadOwnProfile(accessToken);

    if (profile['status'] != 'approved') {
      throw Exception('Akun belum disetujui Admin Kab/Kota.');
    }

    return SupabaseAuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      authUserId: authUserId,
      profile: profile,
    );
  }

  Future<Map<String, dynamic>> loadOwnProfile(String accessToken) async {
    final response = await http.get(
      _restUri('profiles', {
        'select': 'id,auth_user_id,officer_code,full_name,email,phone,role,status,kecamatan',
        'auth_user_id': 'eq.${_jwtSub(accessToken)}',
        'limit': '1',
      }),
      headers: _authHeaders(accessToken),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Gagal membaca profil: ${response.statusCode} ${response.body}');
    }

    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) {
      throw Exception('Profil belum terhubung dengan akun Supabase Auth.');
    }

    return rows.first as Map<String, dynamic>;
  }

  String _jwtSub(String accessToken) {
    final parts = accessToken.split('.');
    if (parts.length < 2) return '';
    final normalized = base64Url.normalize(parts[1]);
    final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
    return payload['sub'] as String? ?? '';
  }
}
