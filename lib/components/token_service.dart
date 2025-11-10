// services/token_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class TokenService {
  static final TokenService _instance = TokenService._internal();
  factory TokenService() => _instance;
  TokenService._internal();

  static const String _tokenKey = 'token';
  static const String _userKey = 'user';

  Future<bool> isTokenValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString(_tokenKey);
      
      if (token == null || token.isEmpty) {
        return false;
      }

      // Debug logging
      if (kDebugMode) {
        print('🔐 Checking token validity...');
        print('📝 Token length: ${token.length}');
      }

      // Check if token is a valid JWT format first
      if (!_isValidJWTFormat(token)) {
        if (kDebugMode) {
          print('❌ Token format invalid');
        }
        await logout();
        return false;
      }

      // Check if token is expired using jwt_decoder
      try {
        bool isExpired = JwtDecoder.isExpired(token);
        if (kDebugMode) {
          print('⏰ Token expired: $isExpired');
          if (!isExpired) {
            final expirationDate = JwtDecoder.getExpirationDate(token);
            print('📅 Token expires at: $expirationDate');
          }
        }
        
        if (isExpired) {
          await logout();
          return false;
        }
        
        return true;
      } catch (jwtError) {
        if (kDebugMode) {
          print('❌ JWT Decoder error: $jwtError');
        }
        // Jika gagal decode, anggap token invalid
        await logout();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Token validation error: $e');
      }
      await logout();
      return false;
    }
  }

  bool _isValidJWTFormat(String token) {
    // Basic JWT format validation (3 parts separated by dots)
    final parts = token.split('.');
    return parts.length == 3;
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userString = prefs.getString(_userKey);
      
      if (userString == null || userString.isEmpty) {
        return null;
      }

      return json.decode(userString);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Get user data error: $e');
      }
      return null;
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> logout() async {
    try {
      if (kDebugMode) {
        print('🚪 Logging out user...');
      }
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      
      // Set force logout flag untuk mencegah loop
      await prefs.setBool('force_logout', true);
      
      if (kDebugMode) {
        print('✅ Logout completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during logout: $e');
      }
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      // Check force logout flag first
      final prefs = await SharedPreferences.getInstance();
      final forceLogout = prefs.getBool('force_logout') ?? false;
      if (forceLogout) {
        if (kDebugMode) {
          print('🚫 Force logout flag detected');
        }
        await prefs.setBool('force_logout', false);
        return false;
      }
      
      final token = await getToken();
      final isValid = token != null && token.isNotEmpty && await isTokenValid();
      
      if (kDebugMode) {
        print('🔐 Login status: $isValid');
      }
      
      return isValid;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Login check error: $e');
      }
      return false;
    }
  }

  // Method untuk clear force logout flag (dipanggil setelah login sukses)
  Future<void> clearForceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('force_logout', false);
    if (kDebugMode) {
      print('✅ Force logout flag cleared');
    }
  }
}