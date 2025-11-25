import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiSubjectService {
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

  // Get Filter Options for Subject Filters
  static Future<Map<String, dynamic>> getSubjectFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mata-pelajaran/filter-options'),
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
          'status_options': [],
        }
      };
    } catch (e) {
      print('Error getting filter options: $e');
      rethrow;
    }
  }

  // Get Subjects with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getSubjectsPaginated({
    int page = 1,
    int limit = 10,
    String? status,
    String? search,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    // Build query string
    String queryString = Uri(queryParameters: queryParams).query;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mata-pelajaran?$queryString'),
        headers: await _getHeaders(),
      );

      print('GET /mata-pelajaran?$queryString - Status: ${response.statusCode}');

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
        }
      };
    } catch (e) {
      print('Error getting paginated subjects: $e');
      rethrow;
    }
  }

  // Legacy method (keep for backward compatibility)
  // Now handles paginated response from backend
  Future<List<dynamic>> getSubject() async {
    final result = await ApiService().get('/mata-pelajaran');
    
    // Handle new pagination format
    if (result is Map<String, dynamic>) {
      return result['data'] ?? [];
    }
    
    // Handle old format (List)
    return result is List ? result : [];
  }

  Future<dynamic> addSubject(Map<String, dynamic> data) async {
    return await ApiService().post('/mata-pelajaran', data);
  }

  Future<void> updateSubject(String id, Map<String, dynamic> data) async {
    await ApiService().put('/mata-pelajaran/$id', data);
  }

  Future<void> deleteSubject(String id) async {
    await ApiService().delete('/mata-pelajaran/$id');
  }

  static Future<List<dynamic>> getContentMateri({
    required String subBabId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/konten-materi?sub_bab_id=$subBabId'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<List<dynamic>> getBabMateri({String? mataPelajaranId}) async {
    String url = '$baseUrl/bab-materi?';
    if (mataPelajaranId != null) url += 'mata_pelajaran_id=$mataPelajaranId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Sub Bab Materi
  static Future<List<dynamic>> getSubBabMateri({required String babId}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/sub-bab-materi?bab_id=$babId'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Tambah Bab Materi
  static Future<dynamic> addBabMateri(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bab-materi'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Tambah Sub Bab Materi
  static Future<dynamic> addSubBabMateri(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sub-bab-materi'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Tambah Konten Materi
  static Future<dynamic> addContentMateri(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/konten-materi'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Update Bab Materi
  static Future<void> updateBabMateri(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/bab-materi/$id'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    _handleResponse(response);
  }

  // Update Sub Bab Materi
  static Future<void> updateSubBabMateri(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/sub-bab-materi/$id'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    _handleResponse(response);
  }

  // Update Konten Materi
  static Future<void> updateContentMateri(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/konten-materi/$id'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    _handleResponse(response);
  }

  // Delete Bab Materi
  static Future<void> deleteBabMateri(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/bab-materi/$id'),
      headers: await _getHeaders(),
    );

    _handleResponse(response);
  }

  // Delete Sub Bab Materi
  static Future<void> deleteSubBabMateri(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/sub-bab-materi/$id'),
      headers: await _getHeaders(),
    );

    _handleResponse(response);
  }

  // Delete Konten Materi
  static Future<void> deleteContentMateri(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/konten-materi/$id'),
      headers: await _getHeaders(),
    );

    _handleResponse(response);
  }

  // Materi
  static Future<List<dynamic>> getMateri({
    String? teacherId,
    String? subjectId,
  }) async {
    String url = '$baseUrl/materi?';
    if (teacherId != null) url += 'guru_id=$teacherId&';
    if (subjectId != null) url += 'mata_pelajaran_id=$subjectId&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<dynamic> addMateri(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/materi'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<dynamic> saveRPP(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/rpp'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<List<dynamic>> getRPPByTeacher(String guruId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/rpp?guru_id=$guruId'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<Map<String, dynamic>> importSubjectFromExcel(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/mata-pelajaran/import'),
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

  static Future<String> downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mata-pelajaran/template'),
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

  // ==================== MATERI PROGRESS METHODS ====================

  // Get Materi Progress (checked state) for a teacher and subject
  static Future<List<dynamic>> getMateriProgress({
    required String guruId,
    required String mataPelajaranId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/materi-progress?guru_id=$guruId&mata_pelajaran_id=$mataPelajaranId'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Save or Update single materi progress (toggle checked state)
  static Future<dynamic> saveMateriProgress(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/materi-progress'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Batch save materi progress (for saving multiple checkboxes at once)
  static Future<dynamic> batchSaveMateriProgress(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/materi-progress/batch'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Mark materi as generated (after RPP/activity generation)
  static Future<dynamic> markMateriGenerated(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/materi-progress/mark-generated'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Reset generated status (to allow regeneration)
  static Future<dynamic> resetMateriGenerated(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/materi-progress/reset-generated'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }
}
