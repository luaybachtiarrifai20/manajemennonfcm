import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:manajemensekolah/components/error_handler.dart';
import 'package:manajemensekolah/components/token_service.dart';
import 'package:manajemensekolah/firebase_options.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/fcm_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/screen/dashboard.dart';
import 'package:manajemensekolah/screen/login_screen.dart';
import 'package:manajemensekolah/utils/language_utils.dart';

// Global navigator key for navigation without context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ApiService FIRST (before anything else)
  await ApiService.init();
  if (kDebugMode) {
    print('✅ ApiService initialized');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      print('✅ Firebase initialized');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Firebase initialization error: $e');
      print('⚠️ Please configure Firebase using FlutterFire CLI or update firebase_options.dart');
    }
  }

  await initializeDateFormatting('id_ID', null);
  
  // Initialize language provider and load saved language
  await languageProvider.loadSavedLanguage();
  
  // Setup error handling (non-blocking)
  _setupErrorHandling();
  
  runApp(SchoolManagementApp());
}

void _setupErrorHandling() {
  try {
    AppErrorHandler.setupErrorHandling();
  } catch (e) {
    print('Error setting up error handling: $e');
  }
}

class SchoolManagementApp extends StatefulWidget {
  const SchoolManagementApp({super.key});

  @override
  State<SchoolManagementApp> createState() => _SchoolManagementAppState();
}

class _SchoolManagementAppState extends State<SchoolManagementApp> {
  final TokenService _tokenService = TokenService();
  StreamSubscription<Exception>? _errorSubscription;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() async {
    try {
      // Clear any existing force logout flag on app start
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('force_logout', false);
      
      // Setup error handling
      _setupErrorHandling();
      
      // Initialize FCM Service
      try {
        await FCMService().initialize();
        if (kDebugMode) {
          print('✅ FCM Service initialized in app');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ FCM Service initialization failed (non-critical): $e');
        }
      }
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('App initialization error: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _setupErrorHandling() {
    _errorSubscription = AppErrorHandler.errorStream.listen((error) async {
      await _handleGlobalError(error);
    });
  }

  Future<void> _handleGlobalError(Exception error) async {
    if (kDebugMode) {
      print('🔴 Global error: $error');
    }
    
    // Hanya handle error yang terkait authentication
    if (_isAuthError(error)) {
      if (kDebugMode) {
        print('🔐 Auth error detected, logging out...');
      }
      
      await _tokenService.logout();
      
      // Navigate to login screen safely
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigatorKey.currentState?.mounted ?? false) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginScreen()),
            (route) => false,
          );
        }
      });
    }
  }

  bool _isAuthError(Exception error) {
    final errorString = error.toString().toLowerCase();
    
    // Hanya handle error yang benar-benar terkait auth
    return errorString.contains('token expired') ||
           errorString.contains('jwt expired') ||
           errorString.contains('authentication failed') ||
           errorString.contains('401') ||
           errorString.contains('invalid token');
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    AppErrorHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing...'),
              ],
            ),
          ),
        ),
      );
    }

    return ChangeNotifierProvider<LanguageProvider>(
      create: (context) => languageProvider,
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: languageProvider.getTranslatedText({
              'en': 'School Management',
              'id': 'Manajemen Sekolah',
            }),
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            home: FutureBuilder(
              future: _checkAuthStatus(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingScreen(languageProvider);
                } else {
                  final isAuthenticated = snapshot.data ?? false;
                  if (kDebugMode) {
                    print('🏠 Home decision: authenticated = $isAuthenticated');
                  }
                  
                  if (isAuthenticated) {
                    return _redirectToDashboard(languageProvider);
                  } else {
                    return LoginScreen();
                  }
                }
              },
            ),
            routes: {
              '/admin': (context) => Dashboard(role: 'admin'),
              '/guru': (context) => Dashboard(role: 'guru'),
              '/staff': (context) => Dashboard(role: 'staff'),
              '/wali': (context) => Dashboard(role: 'wali'),
              '/login': (context) => LoginScreen(),
            },
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen(LanguageProvider languageProvider) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Loading...',
                'id': 'Memuat...',
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkAuthStatus() async {
    try {
      if (kDebugMode) {
        print('🔐 Checking auth status...');
      }
      
      final isLoggedIn = await _tokenService.isLoggedIn();
      
      if (kDebugMode) {
        print('🔐 Auth status result: $isLoggedIn');
      }
      
      return isLoggedIn;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Auth check error: $e');
      }
      // Jika ada error, anggap tidak authenticated
      return false;
    }
  }

  Widget _redirectToDashboard(LanguageProvider languageProvider) {
    return FutureBuilder(
      future: _getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildRedirectingScreen(languageProvider);
        } else {
          final role = snapshot.data ?? 'guru';
          if (kDebugMode) {
            print('🎯 Redirecting to dashboard with role: $role');
          }
          return Dashboard(role: role);
        }
      },
    );
  }

  Widget _buildRedirectingScreen(LanguageProvider languageProvider) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Redirecting...',
                'id': 'Mengalihkan...',
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getUserRole() async {
    try {
      final userData = await _tokenService.getUserData();
      final role = userData?['role']?.toString() ?? 'guru';
      
      if (kDebugMode) {
        print('👤 User role: $role');
      }
      
      return role;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Get user role error: $e');
      }
      return 'guru';
    }
  }
}