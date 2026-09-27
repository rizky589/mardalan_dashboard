import 'package:flutter/material.dart';

const _orange = Color(0xFFFF9800);
const _cream = Color(0xFFFFF7ED);
const _ink = Color(0xFF2D2F35);

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.08),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Selamat Datang di MARDALAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Monitoring Aktivitas dan Rute Petugas Lapangan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Masuk',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Copyright \u00A9 TIM IPDS 2026. All rights reserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
