import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClassService {
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
      throw Exception(
        responseBody['error'] ??
            'Request failed with status: ${response.statusCode}',
      );
    }
  }

  // Import kelas dari Excel
  static Future<Map<String, dynamic>> importClassesFromExcel(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/class/import'),
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

      print('Import Response Status: ${response.statusCode}');
      print('Import Response Body: $responseBody');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw Exception(
          'Import failed with status: ${response.statusCode}. Response: $responseBody',
        );
      }
    } catch (e) {
      print('Import error details: $e');
      throw Exception('Import error: $e');
    }
  }

  // Download template Excel untuk kelas
  static Future<String> downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/class/template'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Save file locally
        final directory = await getExternalStorageDirectory();
        final filePath = '${directory?.path}/template_import_kelas.xlsx';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);

        print('Template downloaded to: $filePath');
        return filePath;
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Download template error: $e');
      throw Exception('Failed to download template: $e');
    }
  }

  // Get external storage directory (helper function)
  static Future<Directory?> getExternalStorageDirectory() async {
    try {
      // For mobile
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    } catch (e) {
      // For web or other platforms
      return null;
    }
  }

  // Get Filter Options for Class Filters
  static Future<Map<String, dynamic>> getClassFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/class/filter-options'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback
      return {
        'success': false,
        'data': {'grade_levels': [], 'wali_kelas': []},
      };
    } catch (e) {
      print('Error getting filter options: $e');
      rethrow;
    }
  }

  // Get Classes with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getClassPaginated({
    int page = 1,
    int limit = 10,
    String? gradeLevel,
    String? waliclassId,
    String? search,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryParams['grade_level'] = gradeLevel;
    }
    if (waliclassId != null && waliclassId.isNotEmpty) {
      queryParams['homeroom_teacher_id'] = waliclassId;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    // Build query string
    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/class?$queryString'),
        headers: await _getHeaders(),
      );

      print('GET /class?$queryString - Status: ${response.statusCode}');

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback untuk backward compatibility
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
    } catch (e) {
      print('Error getting paginated classes: $e');
      rethrow;
    }
  }

  // Existing methods...
  Future<List<dynamic>> getClass() async {
    try {
      final result = await ApiService().get('/class');

      // Handle new pagination format
      if (result is Map<String, dynamic>) {
        return result['data'] ?? [];
      }

      // Handle old format (List)
      return result is List ? result : [];
    } catch (e) {
      print('Error getting classes: $e');
      return [];
    }
  }

  // Get class by ID
  Future<dynamic> getClassById(String id) async {
    try {
      final result = await ApiService().get('/class/$id');
      return result;
    } catch (e) {
      print('Error getting class by ID: $e');
      throw Exception('Gagal mengambil data kelas: $e');
    }
  }

  // Add new class (POST)
  Future<dynamic> addClass(Map<String, dynamic> data) async {
    try {
      // Validasi data required
      if (data['nama'] == null || data['nama'].toString().isEmpty) {
        throw Exception('Nama kelas harus diisi');
      }

      if (data['grade_level'] == null) {
        throw Exception('Grade level harus dipilih');
      }

      print('Adding class with data: $data');
      final result = await ApiService().post('/class', data);
      print('Add class result: $result');
      return result;
    } catch (e) {
      print('Error adding class: $e');
      throw Exception('Gagal menambah kelas: $e');
    }
  }

  // Update existing class (PUT)
  Future<dynamic> updateClass(String id, Map<String, dynamic> data) async {
    try {
      // Validasi data required
      if (data['nama'] == null || data['nama'].toString().isEmpty) {
        throw Exception('Nama kelas harus diisi');
      }

      if (data['grade_level'] == null) {
        throw Exception('Grade level harus dipilih');
      }

      print('Updating class $id with data: $data');
      final result = await ApiService().put('/class/$id', data);
      print('Update class result: $result');
      return result;
    } catch (e) {
      print('Error updating class: $e');
      throw Exception('Gagal mengupdate kelas: $e');
    }
  }

  // Delete class
  Future<void> deleteClass(String id) async {
    try {
      await ApiService().delete('/class/$id');
    } catch (e) {
      print('Error deleting class: $e');
      throw Exception('Gagal menghapus kelas: $e');
    }
  }

  // Get students by class ID
  Future<List<dynamic>> getStudentsByClassId(String classId) async {
    try {
      final result = await ApiService().get('/student/class/$classId');

      // Handle Map format (pagination or error response)
      if (result is Map<String, dynamic>) {
        if (result.containsKey('data')) {
          return result['data'] ?? [];
        }
        return [];
      }

      // Handle List format (direct response)
      return result is List ? result : [];
    } catch (e) {
      print('Error getting students by class: $e');
      return [];
    }
  }
}
