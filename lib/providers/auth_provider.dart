import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_auth_service.dart';
import '../services/supabase_config.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  Map<String, dynamic>? _currentOfficer;
  List<Map<String, dynamic>> _officers = [];
  bool _isLoading = false;
  String? _error;
  String? _accessToken;
  String? _refreshToken;

  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get currentUser => _currentOfficer;
  List<Map<String, dynamic>> get officers => _officers;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get accessToken => _accessToken;
  bool get hasAccessToken => _accessToken != null && _accessToken!.isNotEmpty;

  AuthProvider() {
    _loadSavedLogin();
  }

  // Load saved login dari SharedPreferences
  Future<void> _loadSavedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final officerId = prefs.getString('logged_officer_id');
      final officerName = prefs.getString('logged_officer_name');
      _accessToken = prefs.getString('supabase_access_token');
      _refreshToken = prefs.getString('supabase_refresh_token');
      
      if (officerId != null && officerName != null) {
        final officerRole = prefs.getString('logged_officer_role') ?? 'PCL';
        _currentOfficer = {
          'id': officerId,
          'name': officerName,
          'role': officerRole,
        };
        _isLoggedIn = true;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading saved login: $e');
    }
  }

  // Load daftar petugas dari Google Sheets
  Future<void> loadOfficers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _officers = [];
    } catch (e) {
      _error = 'Gagal memuat daftar petugas: $e';
      print('Error loading officers: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Login petugas. Jika Supabase dikonfigurasi, gunakan Supabase Auth.
  // Jika belum, fallback lokal tetap tersedia untuk demo/offline development.
  Future<bool> login(String officerId, String officerName, String phone, {String role = 'PCL'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (SupabaseConfig.isConfigured && officerId.contains('@')) {
        final session = await SupabaseAuthService.instance.signIn(
          email: officerId,
          password: phone,
        );
        final profile = session.profile;

        _accessToken = session.accessToken;
        _refreshToken = session.refreshToken;
        _currentOfficer = {
          'id': profile['officer_code'] ?? profile['id'],
          'profile_id': profile['id'],
          'auth_user_id': profile['auth_user_id'],
          'name': profile['full_name'],
          'email': profile['email'],
          'phone': profile['phone'],
          'role': profile['role'],
        };
        _isLoggedIn = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_officer_id', _currentOfficer!['id'] as String);
        await prefs.setString('logged_profile_id', _currentOfficer!['profile_id'] as String);
        await prefs.setString('logged_officer_name', _currentOfficer!['name'] as String);
        await prefs.setString('logged_officer_role', _currentOfficer!['role'] as String);
        await prefs.setString('supabase_access_token', session.accessToken);
        await prefs.setString('supabase_refresh_token', session.refreshToken);

        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Simpan login langsung dengan data yang diberikan
      _currentOfficer = {
        'id': officerId,
        'name': officerName,
        'phone': phone,
        'role': role,
      };
      _isLoggedIn = true;

      // Simpan ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logged_officer_id', officerId);
      await prefs.setString('logged_officer_name', officerName);
      await prefs.setString('logged_officer_role', role);

      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _error = 'Gagal login: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('logged_officer_id');
      await prefs.remove('logged_profile_id');
      await prefs.remove('logged_officer_name');
      await prefs.remove('logged_officer_role');
      await prefs.remove('supabase_access_token');
      await prefs.remove('supabase_refresh_token');

      _currentOfficer = null;
      _accessToken = null;
      _refreshToken = null;
      _isLoggedIn = false;
      notifyListeners();

    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
