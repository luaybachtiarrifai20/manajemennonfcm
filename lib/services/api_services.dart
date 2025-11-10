import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:manajemensekolah/main.dart';
import 'package:manajemensekolah/screen/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // static const String baseUrl = 'http://10.0.2.2:3000/api'; // Android emulator
  static const String baseUrl =
      'http://localhost:3000/api'; // iOS simulator atau web

  // static const String baseUrl = 'https://backendmanajemensekolah2.vercel.app/api';
  // static const String baseUrl = 'https://libra.web.id/apimanajemen';

  // static const String baseUrl = 'http://aieasytech.id/api';
  // static const String baseUrl = 'http://192.168.1.100:3000/api';

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ GET Error on $endpoint: $e');
      }
      // If it's a network error or critical error, logout user
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        await _handleAuthenticationErrorWithMessage(
          'Connection failed. Please check your internet connection and try again.',
        );
      } else if (e.toString().contains('Timeout')) {
        await _handleAuthenticationErrorWithMessage(
          'Request timeout. Please try again.',
        );
      }
      rethrow;
    }
  }

  // Instance method untuk POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: json.encode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ POST Error on $endpoint: $e');
      }
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        await _handleAuthenticationErrorWithMessage(
          'Connection failed. Please check your internet connection and try again.',
        );
      } else if (e.toString().contains('Timeout')) {
        await _handleAuthenticationErrorWithMessage(
          'Request timeout. Please try again.',
        );
      }
      rethrow;
    }
  }

  // Instance method untuk PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: json.encode(data),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ PUT Error on $endpoint: $e');
      }
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        await _handleAuthenticationErrorWithMessage(
          'Connection failed. Please check your internet connection and try again.',
        );
      } else if (e.toString().contains('Timeout')) {
        await _handleAuthenticationErrorWithMessage(
          'Request timeout. Please try again.',
        );
      }
      rethrow;
    }
  }

  // Dalam ApiService class
  Future<List<dynamic>> getNilaiByMataPelajaran(String mataPelajaranId) async {
    try {
      final semuaNilai = await get('/nilai');
      if (semuaNilai is List) {
        return semuaNilai.where((nilai) {
          return nilai['mata_pelajaran_id'] == mataPelajaranId;
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error filtering nilai: $e');
      return [];
    }
  }

  // Instance method untuk DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ DELETE Error on $endpoint: $e');
      }
      if (e is SocketException || e.toString().contains('Failed host lookup')) {
        await _handleAuthenticationErrorWithMessage(
          'Connection failed. Please check your internet connection and try again.',
        );
      } else if (e.toString().contains('Timeout')) {
        await _handleAuthenticationErrorWithMessage(
          'Request timeout. Please try again.',
        );
      }
      rethrow;
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // Validate token exists
      if (token == null || token.isEmpty) {
        await _redirectToLogin();
        return {'Content-Type': 'application/json'};
      }

      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting headers: $e');
      }
      await _redirectToLogin();
      return {'Content-Type': 'application/json'};
    }
  }

  static Future<void> _redirectToLogin() async {
    await _handleAuthenticationErrorWithMessage(
      'Authentication required. Please login.',
    );
  }

  static dynamic _handleResponse(http.Response response) {
    try {
      final responseBody = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        final errorMessage =
            responseBody['error'] ??
            'Request failed with status: ${response.statusCode}';

        // Handle specific authentication errors (should logout)
        if (response.statusCode == 401) {
          _handleAuthenticationErrorWithMessage(
            'Session expired. Please login again.',
          );
        } else if (response.statusCode == 403) {
          _handleAuthenticationErrorWithMessage(
            'Access forbidden. Please login again.',
          );
        }
        // For 500+ errors, just throw the exception without logging out
        // The UI will handle displaying the error to the user

        throw Exception(errorMessage);
      }
    } catch (e) {
      // Handle JSON decode errors
      if (e is FormatException) {
        _handleAuthenticationErrorWithMessage(
          'Invalid server response. Please try again.',
        );
      }
      rethrow;
    }
  }

  static Future<void> _handleAuthenticationErrorWithMessage(
    String errorMessage,
  ) async {
    try {
      if (kDebugMode) {
        print('🔴 Handling authentication error: $errorMessage');
      }

      // Clear all stored data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Delay sedikit untuk memastikan context sudah ready
      await Future.delayed(const Duration(milliseconds: 300));

      // Navigate to login with error message
      if (navigatorKey.currentState != null &&
          navigatorKey.currentState!.mounted) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginScreen(initialError: errorMessage),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error during authentication cleanup: $e');
      }
      // Fallback ke named route
      try {
        navigatorKey.currentState?.pushReplacementNamed('/login');
      } catch (_) {
        // If all navigation fails, we're likely in a bad state
        if (kDebugMode) {
          print('🚨 Critical: Unable to navigate to login');
        }
      }
    }
  }

  // Public method untuk logout dengan custom message
  static Future<void> logoutWithMessage(String message) async {
    await _handleAuthenticationErrorWithMessage(message);
  }

  Future<List<dynamic>> getData(String endpoint) async {
    final response = await http.get(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        // Add authorization header if needed
      },
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load data');
    }
  }

  // Login dengan sekolah
  static Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? sekolahId,
    String? role,
  }) async {
    try {
      final Map<String, dynamic> body = {'email': email, 'password': password};

      if (sekolahId != null) {
        body['sekolah_id'] = sekolahId;
      }

      if (role != null) {
        body['role'] = role;
      }

      if (kDebugMode) {
        print('📤 Login request: ${body.keys}');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (kDebugMode) {
        print('📥 Login response status: ${response.statusCode}');
        print('📥 Login response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Handle semua kemungkinan flow
        if (responseData['pilih_sekolah'] == true) {
          if (kDebugMode) {
            print('🔄 Login flow: Need to select school');
          }
          return responseData;
        }

        // PERBAIKAN: Handle jika setelah pilih sekolah, perlu pilih role
        if (responseData['pilih_role'] == true) {
          if (kDebugMode) {
            print('🔄 Login flow: Need to select role after school selection');
          }
          return responseData;
        }

        // Hanya validasi token untuk login sukses langsung
        if (responseData['token'] == null) {
          throw Exception('Server tidak mengembalikan token');
        }

        if (responseData['user'] == null) {
          throw Exception('Server tidak mengembalikan data user');
        }

        return responseData;
      } else {
        final errorResponse = json.decode(response.body);
        throw Exception(
          errorResponse['error'] ??
              'Login failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ApiService login error: $e');
      }
      rethrow;
    }
  }

  static Future<List<dynamic>> getUserRoles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/roles'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result['available_roles'] is List ? result['available_roles'] : [];
  }

  // Switch role
  static Future<Map<String, dynamic>> switchRole(String role) async {
    final response = await http.post(
      Uri.parse('$baseUrl/switch-role'),
      headers: await _getHeaders(),
      body: json.encode({'role': role}),
    );

    return _handleResponse(response);
  }

  // Get sekolah yang bisa diakses user
  static Future<List<dynamic>> getUserSchools() async {
    final response = await http.get(
      Uri.parse('$baseUrl/user/schools'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Switch sekolah
  static Future<Map<String, dynamic>> switchSchool(String sekolahId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/switch-school'),
      headers: await _getHeaders(),
      body: json.encode({'sekolah_id': sekolahId}),
    );

    return _handleResponse(response);
  }

  // Nilai
  static Future<List<dynamic>> getNilai({
    String? siswaId,
    String? guruId,
    String? mataPelajaranId,
    String? jenis,
  }) async {
    String url = '$baseUrl/nilai?';
    if (siswaId != null) url += 'siswa_id=$siswaId&';
    if (guruId != null) url += 'guru_id=$guruId&';
    if (mataPelajaranId != null) url += 'mata_pelajaran_id=$mataPelajaranId&';
    if (jenis != null) url += 'jenis=$jenis&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<dynamic> tambahNilai(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/nilai'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // RPP methods
  static Future<List<dynamic>> getRPP({String? guruId, String? status}) async {
    String url = '$baseUrl/rpp?';
    if (guruId != null) url += 'guru_id=$guruId&';
    if (status != null) url += 'status=$status&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<dynamic> tambahRPP(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rpp'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> updateRPP(
    String rppId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/rpp/$rppId'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> updateStatusRPP(
    String rppId,
    String status, {
    String? catatan,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/rpp/$rppId/status'),
      headers: await _getHeaders(),
      body: json.encode({'status': status, 'catatan': catatan}),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> deleteRPP(String rppId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/rpp/$rppId'),
      headers: await _getHeaders(),
    );

    return _handleResponse(response);
  }

  // Di api_services.dart - Perbaiki fungsi uploadFileRPP
  static Future<dynamic> uploadFileRPP(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/rpp'),
      );

      // Add headers
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      request.headers['Authorization'] = 'Bearer $token';

      // Add file dengan cara yang benar
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // Nama field harus sesuai dengan backend
          file.path,
          filename: file.path.split('/').last,
        ),
      );

      // Send request dan dapatkan response
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      print('Upload Response Status: ${response.statusCode}');
      print('Upload Response Body: $responseBody');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw Exception(
          'Upload failed with status: ${response.statusCode}. Response: $responseBody',
        );
      }
    } catch (e) {
      print('Upload error details: $e');
      throw Exception('Upload error: $e');
    }
  }

  // Absensi
  static Future<List<dynamic>> getAbsensi({
    String? guruId,
    String? tanggal,
    String? mataPelajaranId,
    String? siswaId,
  }) async {
    String url = '$baseUrl/absensi?';
    if (guruId != null) url += 'guru_id=$guruId&';
    if (tanggal != null) url += 'tanggal=$tanggal&';
    if (mataPelajaranId != null) url += 'mata_pelajaran_id=$mataPelajaranId&';
    if (siswaId != null) url += 'siswa_id=$siswaId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<List<dynamic>> getAbsensiSummary({String? guruId}) async {
    String url = '$baseUrl/absensi-summary?';
    if (guruId != null) url += 'guru_id=$guruId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<dynamic> tambahAbsensi(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/absensi'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Dalam class ApiService di api_services.dart
  Future<List<int>> getGradeLevels() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/school-configs/grade-levels'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result is List
          ? result.cast<int>()
          : [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting grade levels: $e');
      }
      return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]; // fallback
    }
  }

  // Get kelas by mata pelajaran
  Future<List<dynamic>> getKelasByMataPelajaran(String mataPelajaranId) async {
    try {
      final result = await get(
        '/kelas-by-mata-pelajaran?mata_pelajaran_id=$mataPelajaranId',
      );
      return result is List ? result : [];
    } catch (e) {
      print('Error getting kelas by mata pelajaran: $e');
      return [];
    }
  }

  Future<dynamic> createNilai(Map<String, dynamic> data) async {
    // Sanitize data - ubah undefined menjadi null
    final sanitizedData = _sanitizeData(data);
    return await post('/nilai', sanitizedData);
  }

  Future<dynamic> updateNilai(String id, Map<String, dynamic> data) async {
    // Sanitize data - ubah undefined menjadi null
    final sanitizedData = _sanitizeData(data);
    return await put('/nilai/$id', sanitizedData);
  }

  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    sanitized.removeWhere(
      (key, value) => value == null || value == 'undefined',
    );
    sanitized.forEach((key, value) {
      if (value == 'undefined') {
        sanitized[key] = null;
      }
    });
    return sanitized;
  }

  // Get mata pelajaran with kelas data
  Future<List<dynamic>> getMataPelajaranWithKelas() async {
    try {
      final result = await get('/mata-pelajaran-with-kelas');
      return result is List ? result : [];
    } catch (e) {
      print('Error getting mata pelajaran with kelas: $e');
      return [];
    }
  }

  Future<dynamic> uploadFile(
    String endpoint,
    File file, {
    Map<String, dynamic>? data,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );

      // Add headers dengan authorization
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Deteksi MIME type yang benar
      String? mimeType;
      final extension = file.path.toLowerCase().split('.').last;

      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'pdf':
          mimeType = 'application/pdf';
          break;
        default:
          mimeType = 'image/jpeg'; // fallback
      }

      print('Uploading file: ${file.path}');
      print('File extension: $extension');
      print('MIME type: $mimeType');

      // Add file dengan MIME type yang benar
      request.files.add(
        await http.MultipartFile.fromPath(
          'bukti_bayar',
          file.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      // Add other data
      if (data != null) {
        data.forEach((key, value) {
          request.fields[key] = value.toString();
        });
      }

      print('Request fields: ${request.fields}');
      print('Request files: ${request.files.length}');

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print('Upload Response Status: ${response.statusCode}');
      print('Upload Response Body: $responseData');

      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        throw Exception(
          'Upload failed: ${response.statusCode} - $responseData',
        );
      }
    } catch (error) {
      print('Upload error: $error');
      throw Exception('Upload error: $error');
    }
  }

  // Check server health
  static Future<Map<String, dynamic>> checkHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));
    return _handleResponse(response);
  }

  // Manual payment entry by admin (for offline/cash payments)
  Future<dynamic> inputPembayaranManual(Map<String, dynamic> data) async {
    try {
      return await post('/pembayaran/manual', data);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error input pembayaran manual: $e');
      }
      rethrow;
    }
  }
}
