import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';

const _blue = Color(0xFF005BAC);
const _orange = Color(0xFFF7941D);
const _white = Color(0xFFFFFFFF);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _goNext();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/survei');
    } else if (onboardingDone) {
      Navigator.pushReplacementNamed(context, '/welcome');
    } else {
      Navigator.pushReplacementNamed(context, '/onboarding');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _blue,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapBackgroundPainter())),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _blue.withOpacity(.92),
                    _blue.withOpacity(.76),
                    const Color(0xFF003B73),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 86,
            right: 38,
            child: _MapPin(size: 42, color: _orange.withOpacity(.9)),
          ),
          Positioned(
            left: 30,
            bottom: 132,
            child: _MapPin(size: 34, color: _white.withOpacity(.88)),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _GpsLoadingPainter(progress: _controller.value),
                          child: child,
                        );
                      },
                      child: Container(
                        width: 172,
                        height: 172,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.18),
                              blurRadius: 36,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    const Text(
                      'MARDALAN',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Monitoring Aktivitas dan Rute Petugas Lapangan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _white.withOpacity(.9),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Mengunci sinyal GPS...',
                          style: TextStyle(
                            color: _white.withOpacity(.92),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.location_on, color: color, size: size);
  }
}

class _GpsLoadingPainter extends CustomPainter {
  _GpsLoadingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * .72;

    for (var i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * .33)) % 1;
      final radius = 82 + (maxRadius - 82) * waveProgress;
      final paint = Paint()
        ..color = _orange.withOpacity((1 - waveProgress) * .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;
      canvas.drawCircle(center, radius, paint);
    }

    final sweepPaint = Paint()
      ..color = _orange.withOpacity(.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 92),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GpsLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = _white.withOpacity(.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final minorRoadPaint = Paint()
      ..color = _white.withOpacity(.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final routePaint = Paint()
      ..color = _orange.withOpacity(.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    for (var i = -2; i < 8; i++) {
      final y = size.height * (i / 7);
      final path = Path()
        ..moveTo(-20, y + 38)
        ..cubicTo(
          size.width * .25,
          y - 42,
          size.width * .52,
          y + 72,
          size.width + 24,
          y - 18,
        );
      canvas.drawPath(path, i.isEven ? roadPaint : minorRoadPaint);
    }

    for (var i = -1; i < 6; i++) {
      final x = size.width * (i / 5);
      final path = Path()
        ..moveTo(x + 34, -20)
        ..cubicTo(
          x - 46,
          size.height * .28,
          x + 78,
          size.height * .58,
          x - 18,
          size.height + 30,
        );
      canvas.drawPath(path, minorRoadPaint);
    }

    final route = Path()
      ..moveTo(size.width * .16, size.height * .72)
      ..cubicTo(
        size.width * .34,
        size.height * .54,
        size.width * .46,
        size.height * .75,
        size.width * .62,
        size.height * .48,
      )
      ..cubicTo(
        size.width * .74,
        size.height * .29,
        size.width * .86,
        size.height * .36,
        size.width * .92,
        size.height * .18,
      );
    canvas.drawPath(route, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
