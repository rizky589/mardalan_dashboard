import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_config.dart';
import 'survey_screen.dart';

const _orange = Color(0xFFFF9800);
const _cream = Color(0xFFFFF7ED);
const _ink = Color(0xFF2D2F35);

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _kabupatenController = TextEditingController(text: 'Labuhanbatu Utara');
  bool _isSignUp = false;
  bool _hidePassword = true;
  String _selectedRole = 'PCL';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _kabupatenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 26, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              SizedBox(height: 28),
              _isSignUp ? _buildSignUpForm() : _buildSignInForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 18)
            ],
          ),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
        SizedBox(height: 18),
        Text(
          _isSignUp ? 'Create Account' : 'Welcome to MARDALAN',
          style:
              TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink),
        ),
        SizedBox(height: 6),
        Text(
          _isSignUp
              ? 'Daftar akun petugas lapangan'
              : 'Monitoring Aktivitas dan Rute Petugas Lapangan',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSignInForm() {
    return Column(
      children: [
        _field(_emailController, 'Email', Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        SizedBox(height: 14),
        _field(_passwordController, 'Password', Icons.lock_outline,
            obscure: _hidePassword),
        SizedBox(height: 14),
        _roleSelector(),
        SizedBox(height: 22),
        _primaryButton('Sign In', _canSignIn() ? _signIn : null),
        SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Don\'t have an account? ',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            GestureDetector(
              onTap: () => setState(() => _isSignUp = true),
              child: Text('Sign Up',
                  style: TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
          ],
        ),
        SizedBox(height: 18),
        Text(
          '',
          textAlign: TextAlign.center,
          style:
              TextStyle(color: Colors.grey[700], height: 1.45, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
      children: [
        _field(_nameController, 'Full Name', Icons.person_outline),
        SizedBox(height: 12),
        _field(_emailController, 'Email', Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        SizedBox(height: 12),
        _field(_passwordController, 'Password', Icons.lock_outline,
            obscure: _hidePassword),
        SizedBox(height: 12),
        _field(
            _confirmPasswordController, 'Confirm Password', Icons.lock_outline,
            obscure: _hidePassword),
        SizedBox(height: 12),
        _field(_phoneController, 'Phone Number', Icons.phone_outlined,
            keyboardType: TextInputType.phone),
        SizedBox(height: 12),
        _field(_kabupatenController, 'Kabupaten', Icons.location_city_outlined),
        SizedBox(height: 22),
        _primaryButton('Sign Up', _submitSignUp),
        SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account? ',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            GestureDetector(
              onTap: () => setState(() => _isSignUp = false),
              child: Text('Sign In',
                  style: TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
          ],
        ),
        SizedBox(height: 18),
        Text(
          'Petugas yang belum memiliki akun dapat mendaftar mandiri dengan mengisi identitas. Selanjutnya Admin Kab/Kota menyetujui akun melalui mardalan Web.',
          textAlign: TextAlign.center,
          style:
              TextStyle(color: Colors.grey[700], height: 1.45, fontSize: 12.5),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: _orange, size: 20),
        suffixIcon: hint.toLowerCase().contains('password')
            ? IconButton(
                icon: Icon(
                    _hidePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19),
                onPressed: () => setState(() => _hidePassword = !_hidePassword),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Color(0xFFE7E1DA))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Color(0xFFE7E1DA))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: _orange, width: 1.5)),
      ),
    );
  }

  Widget _roleSelector() {
    return Container(
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE7E1DA)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(child: _roleOption('PCL')),
          Expanded(child: _roleOption('PML')),
        ],
      ),
    );
  }

  Widget _roleOption(String role) {
    final active = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? _orange : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          role,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : _ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          disabledBackgroundColor: Colors.grey[300],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          elevation: 0,
        ),
        child: Text(label, style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  bool _canSignIn() {
    return _emailController.text.trim().contains('@') &&
        _passwordController.text.isNotEmpty;
  }

  bool _canSignUp() {
    return _nameController.text.trim().isNotEmpty &&
        _emailController.text.trim().contains('@') &&
        _passwordController.text.length >= 6 &&
        _passwordController.text == _confirmPasswordController.text &&
        _phoneController.text.trim().isNotEmpty &&
        _kabupatenController.text.trim().isNotEmpty;
  }

  String? _signUpValidationMessage() {
    if (_nameController.text.trim().isEmpty) return 'Nama lengkap wajib diisi.';
    if (!_emailController.text.trim().contains('@')) {
      return 'Email wajib diisi dengan format yang benar.';
    }
    if (_passwordController.text.length < 6) {
      return 'Password minimal 6 karakter.';
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      return 'Confirm Password harus sama dengan Password.';
    }
    if (_phoneController.text.trim().isEmpty) return 'Nomor HP wajib diisi.';
    if (_kabupatenController.text.trim().isEmpty) return 'Kabupaten wajib diisi.';
    return null;
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim().toLowerCase();
    final success =
        await Provider.of<AuthProvider>(context, listen: false).login(
      email,
      email,
      _passwordController.text,
      role: _selectedRole,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => SurveyScreen()));
      return;
    }

    final error = Provider.of<AuthProvider>(context, listen: false).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Login gagal. Periksa email dan password.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _submitSignUp() async {
    final validationMessage = _signUpValidationMessage();
    if (validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      if (!SupabaseConfig.isConfigured) {
        throw Exception('Supabase belum dikonfigurasi.');
      }

      await SupabaseAuthService.instance.registerPendingProfile(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phone: _phoneController.text,
        role: _selectedRole,
        kabupaten: _kabupatenController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Registrasi terkirim. Admin Kab/Kota akan melakukan approval akun.'),
          backgroundColor: _orange,
        ),
      );
      setState(() => _isSignUp = false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registrasi gagal: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
