import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiScheduleService {
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

  // Get Hari
  static Future<List<dynamic>> getHari() async {
    final response = await http.get(
      Uri.parse('$baseUrl/day'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Get Semester
  static Future<List<dynamic>> getSemester() async {
    final response = await http.get(
      Uri.parse('$baseUrl/semester'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Get Jam Pelajaran
  static Future<List<dynamic>> getJamPelajaran() async {
    final response = await http.get(
      Uri.parse('$baseUrl/lesson-hour'),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Add Jam Pelajaran
  static Future<dynamic> addJamPelajaran(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lesson-hour'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  // Get Filter Options for Teaching Schedule Filters
  static Future<Map<String, dynamic>> getScheduleFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teaching-schedule/filter-options'),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback
      return {
        'success': false,
        'data': {'teachers': [], 'classes': [], 'days': [], 'semesters': []},
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting schedule filter options: $e');
      }
      rethrow;
    }
  }

  // Get Teaching Schedules with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getSchedulesPaginated({
    int page = 1,
    int limit = 10,
    String? guruId,
    String? classId,
    String? hariId,
    String? semesterId,
    String? tahunAjaran,
    String? search,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (guruId != null && guruId.isNotEmpty) {
      queryParams['teacher_id'] = guruId;
    }
    if (classId != null && classId.isNotEmpty) {
      queryParams['class_id'] = classId;
    }
    if (hariId != null && hariId.isNotEmpty) {
      queryParams['day_id'] = hariId;
    }
    if (semesterId != null && semesterId.isNotEmpty) {
      queryParams['semester_id'] = semesterId;
    }
    if (tahunAjaran != null && tahunAjaran.isNotEmpty) {
      queryParams['academic_year'] = tahunAjaran;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    // Build query string
    String queryString = Uri(queryParameters: queryParams).query;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teaching-schedule?$queryString'),
        headers: await _getHeaders(),
      );

      if (kDebugMode) {
        print(
          'GET /teaching-schedule?$queryString - Status: ${response.statusCode}',
        );
      }

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
      if (kDebugMode) {
        print('Error getting paginated schedules: $e');
      }
      rethrow;
    }
  }

  // Jadwal Mengajar dengan struktur baru (Legacy - use getSchedulesPaginated instead)
  static Future<List<dynamic>> getSchedule({
    String? guruId,
    String? classId,
    String? hariId,
    String? semesterId,
    String? tahunAjaran,
  }) async {
    String url = '$baseUrl/teaching-schedule?';
    if (guruId != null) url += 'teacher_id=$guruId&';
    if (classId != null) url += 'class_id=$classId&';
    if (hariId != null) url += 'day_id=$hariId&';
    if (semesterId != null) url += 'semester_id=$semesterId&';
    if (tahunAjaran != null) url += 'academic_year=$tahunAjaran&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  static Future<dynamic> addSchedule(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/teaching-schedule'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    return _handleResponse(response);
  }

  static Future<void> updateSchedule(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/teaching-schedule/$id'),
      headers: await _getHeaders(),
      body: json.encode(data),
    );

    _handleResponse(response);
  }

  static Future<void> deleteSchedule(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/teaching-schedule/$id'),
      headers: await _getHeaders(),
    );

    _handleResponse(response);
  }

  // Tambahkan method untuk mendapatkan jam pelajaran berdasarkan filter
  static Future<List<dynamic>> getJamPelajaranByFilter({
    String? hariId,
    String? semesterId,
    String? classId,
    String? academicYear,
  }) async {
    String url = '$baseUrl/lesson-hour-filter?';
    if (hariId != null) url += 'day_id=$hariId&';
    if (semesterId != null) url += 'semester_id=$semesterId&';
    if (classId != null) url += 'class_id=$classId&';
    if (academicYear != null) url += 'academic_year=$academicYear&';

    final response = await http.get(
      Uri.parse(url),
      headers: await _getHeaders(),
    );

    final result = _handleResponse(response);
    return result is List ? result : [];
  }

  // Tambahkan method ini di class ApiScheduleService
  static Future<List<dynamic>> getConflictingSchedules({
    required String hariId,
    required String classId,
    required String semesterId,
    required String tahunAjaran,
    required String jamPelajaranId,
    String? excludeScheduleId, // Untuk edit, exclude jadwal yang sedang diedit
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/conflicts?';
      url += 'day_id=$hariId&';
      url += 'class_id=$classId&';
      url += 'semester_id=$semesterId&';
      url += 'academic_year=$tahunAjaran&';
      url += 'lesson_hour_id=$jamPelajaranId&';

      if (excludeScheduleId != null) {
        url += 'exclude_id=$excludeScheduleId&';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error checking conflicts: $e');
      }
      return [];
    }
  }

  // Di class ApiScheduleService, tambahkan method berikut:

  // Get Jadwal Mengajar by Guru ID
  static Future<List<dynamic>> getScheduleByGuru({
    required String guruId,
    String? hariId,
    String? semesterId,
    String? tahunAjaran,
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/teacher/$guruId?';
      if (hariId != null && hariId.isNotEmpty) url += 'day_id=$hariId&';
      if (semesterId != null) url += 'semester_id=$semesterId&';
      if (tahunAjaran != null) url += 'academic_year=$tahunAjaran&';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading schedule by guru: $e');
      }
      return [];
    }
  }

  // Get Jadwal Mengajar for Current User
  static Future<List<dynamic>> getCurrentUserSchedule({
    String? hariId,
    String? semesterId,
    String? tahunAjaran,
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/current?';
      if (hariId != null && hariId.isNotEmpty) url += 'day_id=$hariId&';
      if (semesterId != null) url += 'semester_id=$semesterId&';
      if (tahunAjaran != null) url += 'academic_year=$tahunAjaran&';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading current user schedule: $e');
      }
      return [];
    }
  }

  // Tambahkan method ini di ApiScheduleService
  static Future<List<dynamic>> getFilteredSchedule({
    required String guruId,
    String? hari,
    String? semester,
    String? tahunAjaran,
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/filtered?';
      url += 'teacher_id=$guruId&';

      if (hari != null && hari != 'Semua Hari') {
        url += 'day=$hari&';
      }

      if (semester != null && semester != 'Semua Semester') {
        url += 'semester=$semester&';
      }

      if (tahunAjaran != null) {
        url += 'academic_year=$tahunAjaran&';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      final result = _handleResponse(response);
      return result is List ? result : [];
    } catch (e) {
      if (kDebugMode) {
        print('Error loading filtered schedule: $e');
      }
      return [];
    }
  }

  // Tambahkan method berikut di class ApiScheduleService

  // Download template jadwal mengajar
  static Future<String> downloadScheduleTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teaching-schedule/template'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Get directory
        final directory = await getApplicationDocumentsDirectory();
        final filePath =
            '${directory.path}/template_import_jadwal_mengajar.xlsx';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to download template: $e');
    }
  }

  // Import jadwal mengajar dari Excel
  static Future<Map<String, dynamic>> importSchedulesFromExcel(
    File file,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/teaching-schedule/import'),
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

      print('Import Schedule Response Status: ${response.statusCode}');
      print('Import Schedule Response Body: $responseBody');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw Exception(
          'Import failed with status: ${response.statusCode}. Response: $responseBody',
        );
      }
    } catch (e) {
      print('Import schedule error details: $e');
      throw Exception('Import error: $e');
    }
  }

  // Debug Excel untuk jadwal mengajar
  static Future<Map<String, dynamic>> debugExcelSchedule(File file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/debug/excel-teaching-schedule'),
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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(responseBody);
      } else {
        throw Exception('Debug failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Debug error: $e');
    }
  }

  // Export jadwal mengajar ke Excel
  static Future<String> exportSchedules({
    String? guruId,
    String? classId,
    String? hariId,
    String? semesterId,
    String? tahunAjaran,
  }) async {
    try {
      String url = '$baseUrl/teaching-schedule/export?';
      if (guruId != null) url += 'teacher_id=$guruId&';
      if (classId != null) url += 'class_id=$classId&';
      if (hariId != null) url += 'day_id=$hariId&';
      if (semesterId != null) url += 'semester_id=$semesterId&';
      if (tahunAjaran != null) url += 'academic_year=$tahunAjaran&';

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Get directory
        final directory = await getApplicationDocumentsDirectory();
        final filePath =
            '${directory.path}/jadwal_mengajar_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(filePath);

        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      } else {
        throw Exception('Export failed with status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to export schedules: $e');
    }
  }
}
