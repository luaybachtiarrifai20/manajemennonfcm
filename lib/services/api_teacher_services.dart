import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiTeacherService {
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

  // Download template Excel untuk guru
  static Future<String> downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/guru/template'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Save file locally
        final directory = await getExternalStorageDirectory();
        final filePath = '${directory?.path}/template_import_guru.xlsx';
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

  // Get Filter Options for Teacher Filters
  static Future<Map<String, dynamic>> getTeacherFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/guru/filter-options'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback
      return {
        'success': false,
        'data': {'kelas': [], 'gender_options': []},
      };
    } catch (e) {
      print('Error getting filter options: $e');
      rethrow;
    }
  }

  // Get Teachers with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getTeachersPaginated({
    int page = 1,
    int limit = 10,
    String? classId,
    String? gender,
    String? search,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (classId != null && classId.isNotEmpty) {
      queryParams['kelas_id'] = classId;
    }
    if (gender != null && gender.isNotEmpty) {
      queryParams['jenis_kelamin'] = gender;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    // Build query string
    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/guru?$queryString'),
        headers: await _getHeaders(),
      );

      print('GET /guru?$queryString - Status: ${response.statusCode}');

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
      print('Error getting paginated teachers: $e');
      rethrow;
    }
  }

  // Existing methods tetap dipertahankan...
  Future<List<dynamic>> getTeacher() async {
    final result = await ApiService().get('/guru');

    // Handle new pagination format
    if (result is Map<String, dynamic>) {
      return result['data'] ?? [];
    }

    // Handle old format (List)
    return result is List ? result : [];
  }

  Future<dynamic> getTeacherById(String id) async {
    return await ApiService().get('/guru/$id');
  }

  Future<dynamic> addTeacher(Map<String, dynamic> data) async {
    return await ApiService().post('/guru', data);
  }

  Future<void> updateTeacher(String id, Map<String, dynamic> data) async {
    final cleanData = Map<String, dynamic>.from(data);
    cleanData.remove('mata_pelajaran_id');
    await ApiService().put('/guru/$id', cleanData);
  }

  Future<void> deleteTeacher(String id) async {
    await ApiService().delete('/guru/$id');
  }

  Future<List<dynamic>> getSubjectByTeacher(String guruId) async {
    try {
      final result = await ApiService().get('/guru/$guruId/mata-pelajaran');
      return result is List ? result : [];
    } catch (e) {
      print('Error getting mata pelajaran by guru: $e');
      return [];
    }
  }

  // Get Subjects by Teacher with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getSubjectsByTeacherPaginated({
    required String guruId,
    int page = 1,
    int limit = 10,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    // Build query string
    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/guru/$guruId/mata-pelajaran?$queryString'),
        headers: await _getHeaders(),
      );

      print(
        'GET /guru/$guruId/mata-pelajaran?$queryString - Status: ${response.statusCode}',
      );

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
      print('Error getting paginated subjects by teacher: $e');
      rethrow;
    }
  }

  Future<dynamic> addSubjectToTeacher(
    String guruId,
    String mataPelajaranId,
  ) async {
    try {
      final result = await ApiService().post('/guru/$guruId/mata-pelajaran', {
        'mata_pelajaran_id': mataPelajaranId,
      });
      return result;
    } catch (e) {
      print('Error adding mata pelajaran to guru: $e');
      rethrow;
    }
  }

  Future<void> removeSubjectFromTeacher(
    String guruId,
    String mataPelajaranId,
  ) async {
    try {
      await ApiService().delete(
        '/guru/$guruId/mata-pelajaran/$mataPelajaranId',
      );
    } catch (e) {
      print('Error removing mata pelajaran from guru: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> importTeachersFromExcel(File file) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/guru/import'),
      );

      // Add authorization header
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      request.headers['Authorization'] = 'Bearer $token';
      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: 'import_guru.xlsx',
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseData);
      } else {
        throw Exception('Failed to import teachers: ${responseData}');
      }
    } catch (e) {
      throw Exception('Failed to import teachers: $e');
    }
  }

  // Download teacher template
  Future<void> downloadTeacherTemplate() async {
    try {
      final response = await ApiService().get('/guru/template');

      // Handle response untuk download file
      // Implementasi download file sesuai kebutuhan
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }
}
