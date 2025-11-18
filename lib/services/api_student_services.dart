import 'dart:convert';
import 'dart:io';
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

      // Handle specific authentication errors
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

  // Import siswa dari Excel
  static Future<Map<String, dynamic>> importStudentsFromExcel(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/siswa/import'),
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

  // Download template Excel
  static Future<String> downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/siswa/template'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Save file locally
        final directory = await getExternalStorageDirectory();
        final filePath = '${directory?.path}/template_import_siswa.xlsx';
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

  static Future<String> downloadTemplateGuru() async {
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

  // Get parent user
  static Future<Map<String, dynamic>?> getParentUser(String studentId) async {
    try {
      final response = await ApiService().get('users?siswa_id=$studentId');
      if (response != null && response is List && response.isNotEmpty) {
        return response.first;
      }
      return null;
    } catch (e) {
      print('Error getting parent user: $e');
      return null;
    }
  }

  // Kelola Siswa (Deprecated - use getStudentPaginated)
  static Future<List<dynamic>> getStudent() async {
    final response = await http.get(
      Uri.parse('$baseUrl/siswa'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    
    // Handle new pagination format
    if (result is Map<String, dynamic>) {
      // New format: { success, data, pagination }
      return (result['data'] as List?) ?? [];
    }
    
    // Backward compatibility: old format (direct list)
    return result is List ? result : [];
  }

  // Get Filter Options for Student Filters
  static Future<Map<String, dynamic>> getStudentFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/siswa/filter-options'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      
      if (result is Map<String, dynamic>) {
        return result;
      }
      
      // Fallback
      return {
        'success': false,
        'data': {
          'grade_levels': [],
          'kelas': [],
          'gender_options': [
            {'value': 'L', 'label': 'Laki-laki'},
            {'value': 'P', 'label': 'Perempuan'}
          ],
          'status_options': [
            {'value': 'active', 'label': 'Aktif'},
            {'value': 'inactive', 'label': 'Tidak Aktif'}
          ]
        }
      };
    } catch (e) {
      print('Error getting filter options: $e');
      rethrow;
    }
  }

  // Get Students with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getStudentPaginated({
    int page = 1,
    int limit = 10,
    String? kelasId,
    String? gradeLevel,
    String? jenisKelamin,
    String? search,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (kelasId != null && kelasId.isNotEmpty) {
      queryParams['kelas_id'] = kelasId;
    }
    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      queryParams['grade_level'] = gradeLevel;
    }
    if (jenisKelamin != null && jenisKelamin.isNotEmpty) {
      queryParams['jenis_kelamin'] = jenisKelamin;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    // Build URI with query parameters
    String queryString = Uri(queryParameters: queryParams).query;
    
    final response = await http.get(
      Uri.parse('$baseUrl/siswa?$queryString'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    
    // Return full response with pagination metadata
    if (result is Map<String, dynamic>) {
      return result;
    }
    
    // Fallback for old format
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
      }
    };
  }

  static Future<dynamic> addStudent(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/siswa'),
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
      Uri.parse('$baseUrl/siswa/$id'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );
    _handleResponse(response);
  }

  static Future<void> deleteStudent(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/siswa/$id'),
      headers: await _getHeaders(),
    );
    _handleResponse(response);
  }

  static Future<List<dynamic>> getStudentByClass(String kelasId) async {
    try {
      final semuaSiswa = await getStudent();
      return semuaSiswa.where((siswa) {
        return siswa['kelas_id'] == kelasId;
      }).toList();
    } catch (e) {
      print('Error filtering siswa by kelas: $e');
      return [];
    }
  }
}
