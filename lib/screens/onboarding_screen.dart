import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _orange = Color(0xFFFF9800);
const _cream = Color(0xFFFFF7ED);
const _ink = Color(0xFF2D2F35);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  final _items = const [
    _OnboardingItem(
      title: 'Aplikasi Tracking Petugas Survei',
      body:
          'Koordinat petugas dikirim berkala agar pengawasan wilayah berjalan lebih akurat.',
    ),
    _OnboardingItem(
      title: 'Wilayah Tugas Terjaga',
      body:
          'Sistem membantu mendeteksi petugas yang keluar dari batas wilayah kerja SLS.',
    ),
    _OnboardingItem(
      title: 'Tetap Aman Saat Offline',
      body:
          'Data tracking disimpan di perangkat terlebih dahulu dan disinkronkan saat jaringan tersedia.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  void _next() {
    if (_index == _items.length - 1) {
      _finish();
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text(
                    'Lewati',
                    style:
                        TextStyle(color: _orange, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) =>
                      _OnboardingPage(item: _items[index]),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _items.length,
                  (itemIndex) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: _index == itemIndex ? 28 : 9,
                    height: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _index == itemIndex
                          ? _orange
                          : const Color(0xFFE6D8C9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _index == _items.length - 1 ? 'Mulai' : 'Lanjut',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.item});

  final _OnboardingItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 148,
          height: 148,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.07),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 38),
        Text(
          item.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          item.body,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}
