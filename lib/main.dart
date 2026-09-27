import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/survey_provider.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/survey_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize local notifications - removed for web compatibility
  
  // Initialize services
  await _initializeServices();
  
  runApp(MyApp());
}

// Notifications removed for web compatibility

Future<void> _initializeServices() async {
  try {
    // Initialize connectivity service
    await ConnectivityService.instance.initialize();
    
    // Initialize sync service
    await SyncService.instance.initialize();
    
    print('All services initialized successfully');
  } catch (e) {
    print('Error initializing services: $e');
  }
}

// Background service initialization removed for web compatibility

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SurveyProvider()),
      ],
      child: MaterialApp(
        title: 'mardalan',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            elevation: 2,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => LoginScreen(),
          '/survei': (context) => SurveyScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
