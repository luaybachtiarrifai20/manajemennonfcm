import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level handler untuk background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('🔔 Background message received: ${message.messageId}');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');
  }

  // Show notification when app is in background
  if (message.notification != null) {
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    // Initialize with basic settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await localNotifications.initialize(settings);

    // Show notification
    await localNotifications.show(
      message.notification.hashCode,
      message.notification!.title,
      message.notification!.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );

    if (kDebugMode) {
      print('✅ Background notification displayed');
    }
  }
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Initialize FCM
  Future<void> initialize() async {
    try {
      if (kDebugMode) {
        print('🔧 Initializing FCM Service...');
      }

      // Request permission
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      if (kDebugMode) {
        print('✅ Permission status: ${settings.authorizationStatus}');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize local notifications
        await _initializeLocalNotifications();

        // Get FCM token
        _fcmToken = await _firebaseMessaging.getToken();
        if (kDebugMode) {
          print('📱 FCM Token: $_fcmToken');
        }

        // Save token locally
        if (_fcmToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', _fcmToken!);
        }

        // Listen to token refresh
        _firebaseMessaging.onTokenRefresh.listen((newToken) async {
          if (kDebugMode) {
            print('🔄 FCM Token refreshed: $newToken');
          }
          _fcmToken = newToken;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fcm_token', newToken);

          // Send updated token to backend
          await sendTokenToBackend(newToken);
        });

        // Setup message handlers
        _setupMessageHandlers();

        // Set background message handler
        FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler,
        );

        if (kDebugMode) {
          print('✅ FCM Service initialized successfully');
        }
      } else {
        if (kDebugMode) {
          print('❌ Notification permission denied');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing FCM: $e');
      }
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // Setup message handlers
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('🔔 Foreground message received: ${message.messageId}');
        print('Title: ${message.notification?.title}');
        print('Body: ${message.notification?.body}');
        print('Data: ${message.data}');
      }

      // Show local notification when app is in foreground
      _showLocalNotification(message);
    });

    // Background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('🔔 Background message opened: ${message.messageId}');
      }
      _handleNotificationTap(message.data);
    });

    // Check for initial message (when app is opened from terminated state)
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          print('🔔 Initial message: ${message.messageId}');
        }
        _handleNotificationTap(message.data);
      }
    });
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription:
                'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  // Handle notification tap from local notification
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _handleNotificationTap(data);
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing notification payload: $e');
        }
      }
    }
  }

  // Handle notification tap action
  void _handleNotificationTap(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('🔔 Notification tapped with data: $data');
    }

    // You can navigate to specific screens based on notification type
    final type = data['type'];

    if (type == 'absensi') {
      // Navigate to presence screen
      // This will be handled by the app's navigation system
      if (kDebugMode) {
        print('Navigate to absensi screen for siswa: ${data['student_id']}');
      }
    } else if (type == 'class_activity') {
      // Navigate to class activity screen
      // This will be handled by the app's navigation system
      if (kDebugMode) {
        print(
          'Navigate to class activity for kegiatan: ${data['activity_id']}',
        );
        print('Student: ${data['student_name']}, Subject: ${data['subject']}');
      }
    } else if (type == 'pengumuman') {
      // Navigate to announcement screen
      // This will be handled by the app's navigation system
      if (kDebugMode) {
        print('Navigate to pengumuman: ${data['announcement_id']}');
        print('Title: ${data['title']}, Priority: ${data['priority']}');
        print('Target: ${data['target_role']}, Class: ${data['class_name']}');
      }
    } else if (type == 'tagihan') {
      // Navigate to tagihan (billing) screen
      // This will be handled by the app's navigation system
      if (kDebugMode) {
        print('Navigate to tagihan: ${data['bill_id']}');
        print('Siswa: ${data['student_name']}');
        print('Jenis: ${data['payment_type_name']}');
        print('Jumlah: Rp ${data['amount']}');
        print('Jatuh Tempo: ${data['due_date']}');
      }
    }
  }

  // Send token to backend
  Future<bool> sendTokenToBackend(String token) async {
    try {
      if (kDebugMode) {
        print('📤 Sending FCM token to backend...');
      }

      await ApiService.sendFCMToken(token, 'mobile');

      if (kDebugMode) {
        print('✅ FCM token sent to backend successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending FCM token to backend: $e');
      }
      return false;
    }
  }

  // Delete token from backend (on logout)
  Future<void> deleteTokenFromBackend() async {
    try {
      if (_fcmToken != null) {
        if (kDebugMode) {
          print('🗑️ Deleting FCM token from backend...');
        }

        await ApiService.deleteFCMToken(_fcmToken!);

        if (kDebugMode) {
          print('✅ FCM token deleted from backend');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting FCM token from backend: $e');
      }
    }
  }

  // Get saved token from local storage
  Future<String?> getSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('fcm_token');
    } catch (e) {
      if (kDebugMode) {
        print('Error getting saved token: $e');
      }
      return null;
    }
  }

  // Clear local token
  Future<void> clearLocalToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      _fcmToken = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing local token: $e');
      }
    }
  }

  // Force refresh FCM token
  Future<String?> forceRefreshToken() async {
    try {
      if (kDebugMode) {
        print('🔄 Force refreshing FCM token...');
      }

      // Delete the old token
      await _firebaseMessaging.deleteToken();

      // Get new token
      _fcmToken = await _firebaseMessaging.getToken();

      if (kDebugMode) {
        print('📱 New FCM Token: $_fcmToken');
      }

      // Save new token locally
      if (_fcmToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);

        // Send to backend
        await sendTokenToBackend(_fcmToken!);
      }

      return _fcmToken;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error force refreshing token: $e');
      }
      return null;
    }
  }
}
