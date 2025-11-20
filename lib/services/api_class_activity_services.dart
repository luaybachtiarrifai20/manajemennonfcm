// api_class_activity_services.dart - Perbaikan lengkap
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClassActivityService {
  // Get Class Activities with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getClassActivityPaginated({
    int page = 1,
    int limit = 10,
    String? guruId,
    String? kelasId,
    String? mataPelajaranId,
    String? target,
    String? tanggal,
    String? search,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (guruId != null && guruId.isNotEmpty) {
      queryParams['guru_id'] = guruId;
    }
    if (kelasId != null && kelasId.isNotEmpty) {
      queryParams['kelas_id'] = kelasId;
    }
    if (mataPelajaranId != null && mataPelajaranId.isNotEmpty) {
      queryParams['mata_pelajaran_id'] = mataPelajaranId;
    }
    if (target != null && target.isNotEmpty) {
      queryParams['target'] = target;
    }
    if (tanggal != null && tanggal.isNotEmpty) {
      queryParams['tanggal'] = tanggal;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    // Build URI with query parameters
    String queryString = Uri(queryParameters: queryParams).query;

    final response = await http.get(
      Uri.parse('$baseUrl/kegiatan?$queryString'),
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
      },
    };
  }

  static String get baseUrl => ApiService.baseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak tersedia. Silakan login kembali.');
      }

      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting headers: $e');
      }
      rethrow;
    }
  }

  static dynamic _handleResponse(http.Response response) {
    try {
      final responseBody = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return responseBody;
      } else {
        throw Exception(
          responseBody['error'] ??
              'Request failed with status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing response: $e');
      }
      throw Exception('Failed to parse server response');
    }
  }

  // Tambahkan di ApiService class
  static Future<http.Response> exportClassActivities(
    List<Map<String, dynamic>> activities,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/export/class-activities'),
      headers: await _getHeaders(),
      body: json.encode({'activities': activities}),
    );
    return response;
  }

  // Get kegiatan by guru - DIPERBAIKI
  static Future<List<dynamic>> getActivityByGuru(String guruId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/kegiatan/guru/$guruId'),
        headers: headers,
      );

      final result = _handleResponse(response);

      // Handle jika response adalah array langsung
      if (result is List) {
        return result;
      }
      // Handle jika response adalah object dengan data property
      else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      }
      // Handle format lainnya
      else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error get kegiatan by guru: $e');
      }
      rethrow;
    }
  }

  // Get kegiatan by kelas (untuk siswa) - DIPERBAIKI
  static Future<List<dynamic>> getKegiatanByKelas(
    String kelasId, {
    String? siswaId,
  }) async {
    try {
      final headers = await _getHeaders();

      final params = {if (siswaId != null) 'siswa_id': siswaId};

      final uri = Uri.parse(
        '$baseUrl/kegiatan/kelas/$kelasId',
      ).replace(queryParameters: params.isNotEmpty ? params : null);

      final response = await http.get(uri, headers: headers);
      final result = _handleResponse(response);

      if (result is List) {
        return result;
      } else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error get kegiatan by kelas: $e');
      }
      rethrow;
    }
  }

  // Tambah kegiatan - DIPERBAIKI
  static Future<dynamic> tambahKegiatan(Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/kegiatan'),
        headers: headers,
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error tambah kegiatan: $e');
      }
      rethrow;
    }
  }

  // Update kegiatan - DIPERBAIKI
  static Future<dynamic> updateKegiatan(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      final headers = await _getHeaders();

      final response = await http.put(
        Uri.parse('$baseUrl/kegiatan/$id'),
        headers: headers,
        body: json.encode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error update kegiatan: $e');
      }
      rethrow;
    }
  }

  // Delete kegiatan - DIPERBAIKI
  static Future<dynamic> deleteKegiatan(String id) async {
    try {
      final headers = await _getHeaders();

      final response = await http.delete(
        Uri.parse('$baseUrl/kegiatan/$id'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error delete kegiatan: $e');
      }
      rethrow;
    }
  }

  // Get jadwal untuk form - DIPERBAIKI
  static Future<List<dynamic>> getJadwalForForm({
    required String guruId,
    String? hari,
    String? tahunAjaran,
  }) async {
    try {
      final headers = await _getHeaders();

      final params = {
        if (hari != null && hari != 'Semua Hari') 'hari': hari,
        if (tahunAjaran != null) 'tahun_ajaran': tahunAjaran,
      };

      final uri = Uri.parse(
        '$baseUrl/jadwal/guru/$guruId',
      ).replace(queryParameters: params.isNotEmpty ? params : null);

      final response = await http.get(uri, headers: headers);
      final result = _handleResponse(response);

      if (result is List) {
        return result;
      } else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error get jadwal for form: $e');
      }
      rethrow;
    }
  }

  // Get siswa by kelas - DIPERBAIKI
  static Future<List<dynamic>> getSiswaByKelas(String kelasId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/siswa/kelas/$kelasId'),
        headers: headers,
      );

      final result = _handleResponse(response);

      if (result is List) {
        return result;
      } else if (result is Map && result.containsKey('data')) {
        return result['data'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error get siswa by kelas: $e');
      }
      rethrow;
    }
  }

  // Debug method untuk test connection
  static Future<dynamic> testConnection() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: headers,
      );

      return _handleResponse(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error test connection: $e');
      }
      rethrow;
    }
  }

  // Get filter options for kegiatan (guru, kelas, tanggal, bulan, tahun)
  static Future<Map<String, dynamic>> getKegiatanFilterOptions({
    String? guruId,
    String? kelasId,
    String? tanggal,
    String? bulan,
    String? tahun,
    String? mataPelajaranId,
  }) async {
    try {
      final params = <String, String>{};
      if (guruId != null && guruId.isNotEmpty) params['guru_id'] = guruId;
      if (kelasId != null && kelasId.isNotEmpty) params['kelas_id'] = kelasId;
      if (tanggal != null && tanggal.isNotEmpty) params['tanggal'] = tanggal;
      if (bulan != null && bulan.isNotEmpty) params['bulan'] = bulan;
      if (tahun != null && tahun.isNotEmpty) params['tahun'] = tahun;
      if (mataPelajaranId != null && mataPelajaranId.isNotEmpty)
        params['mata_pelajaran_id'] = mataPelajaranId;

      final uri = Uri.parse(
        '$baseUrl/kegiatan/filter-options',
      ).replace(queryParameters: params.isNotEmpty ? params : null);

      final response = await http.get(uri, headers: await _getHeaders());
      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) return result;

      return {'success': false};
    } catch (e) {
      if (kDebugMode) print('Error getKegiatanFilterOptions: $e');
      rethrow;
    }
  }
}
