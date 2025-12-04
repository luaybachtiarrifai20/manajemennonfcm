import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiStudentService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static dynamic _handleResponse(http.Response response) {
    final responseBody = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      final errorMessage =
          responseBody['error'] ??
          'Request failed with status: ${response.statusCode}';

      if (response.statusCode == 401) {
        _handleAuthenticationError();
      }

      throw Exception(errorMessage);
    }
  }

  static void _handleAuthenticationError() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); // Clear invalid token
    // You can also navigate to login page here
    // Navigator.of(context).pushReplacementNamed('/login');
  }

  static Future<Map<String, dynamic>> importStudentsFromExcel(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/student/import'),
      );

      // Add headers
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      request.headers['Authorization'] = 'Bearer $token';

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: file.path.split('/').last,
        ),
      );

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (kDebugMode) {
        print('Import Response Status: ${response.statusCode}');
      }
      if (kDebugMode) {
        print('Import Response Body: $responseBody');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw Exception(
          'Import failed with status: ${response.statusCode}. Response: $responseBody',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Import error details: $e');
      }
      throw Exception('Import error: $e');
    }
  }

  static Future<String> downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/student/template'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final directory = await getExternalStorageDirectory();
        final filePath = '${directory?.path}/template_import_siswa.xlsx';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        if (kDebugMode) {
          print('Template downloaded to: $filePath');
        }
        return filePath;
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Download template error: $e');
      }
      throw Exception('Failed to download template: $e');
    }
  }

  static Future<Directory?> getExternalStorageDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getParentUser(String studentId) async {
    try {
      final response = await ApiService().get('users?student_id=$studentId');
      if (response != null && response is List && response.isNotEmpty) {
        return response.first;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting parent user: $e');
      }
      return null;
    }
  }

  static Future<List<dynamic>> getStudent() async {
    final response = await http.get(
      Uri.parse('$baseUrl/student'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);

    if (result is Map<String, dynamic>) {
      return (result['data'] as List?) ?? [];
    }

    return result is List ? result : [];
  }

  static Future<Map<String, dynamic>> getStudentFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/student/filter-options'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      return {
        'success': false,
        'data': {
          'grade_levels': [],
          'kelas': [],
          'gender_options': [
            {'value': 'L', 'label': 'Laki-laki'},
            {'value': 'P', 'label': 'Perempuan'},
          ],
          'status_options': [
            {'value': 'active', 'label': 'Aktif'},
            {'value': 'inactive', 'label': 'Tidak Aktif'},
          ],
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting filter options: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getStudentPaginated({
    int page = 1,
    int limit = 10,
    String? classId,
    String? gradeLevel,
    String? gender,
    String? search,
  }) async {
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryParams['grade_level'] = gradeLevel;
    }
    if (gender != null && gender.isNotEmpty) {
      queryParams['gender'] = gender;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    String queryString = Uri(queryParameters: queryParams).query;

    final response = await http.get(
      Uri.parse('$baseUrl/student?$queryString'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);

    if (result is Map<String, dynamic>) {
      return result;
    }

    return {
      'success': true,
      'data': result is List ? result : [],
      'pagination': {
        'total_items': result is List ? result.length : 0,
        'total_pages': 1,
        'current_page': 1,
        'per_page': limit,
        'has_next_page': false,
        'has_prev_page': false,
      },
    };
  }

  static Future<dynamic> addStudent(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/student'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    return _handleResponse(response);
  }

  static Future<void> updateStudent(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/student/$id'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    _handleResponse(response);
  }

  static Future<void> deleteStudent(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/student/$id'),
      headers: await _getHeaders(),
    );
    _handleResponse(response);
  }

  static Future<List<dynamic>> getStudentByClass(String classId) async {
    try {
      final semuaSiswa = await getStudent();
      return semuaSiswa.where((siswa) {
        return siswa['class_id'] == classId;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error filtering siswa by kelas: $e');
      }
      return [];
    }
  }
}
