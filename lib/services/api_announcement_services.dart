import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiAnnouncementService {
  static String get baseUrl => ApiService.baseUrl;

  // Helper to safely print response bodies for debugging (truncated)
  static void _debugResponse(http.Response response, {String? label}) {
    try {
      final raw = response.body;
      final safe = raw.length > 1000
          ? '${raw.substring(0, 1000)}... [truncated]'
          : raw;
      if (kDebugMode) {
        print(
        '${label ?? 'HTTP Response'} - Status: ${response.statusCode} - Body: $safe',
      );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error printing response debug: $e');
      }
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    // If token missing, trigger global logout/redirect to login so app
    // doesn't stay on an error screen without navigating the user.
    if (token == null || token.isEmpty) {
      // Use ApiService helper to clear state and redirect to login
      try {
        await ApiService.logoutWithMessage(
          'Authentication required. Please login.',
        );
      } catch (e) {
        // ignore navigation errors here
      }

      // Return headers without Authorization to avoid sending 'Bearer null'
      return {'Content-Type': 'application/json'};
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static dynamic _handleResponse(http.Response response) {
    dynamic responseBody;
    try {
      responseBody = json.decode(response.body);
    } catch (e) {
      // If server returns non-json (or empty), log raw body for debugging
      try {
        final raw = response.body;
        final safe = raw.length > 1000
            ? '${raw.substring(0, 1000)}... [truncated]'
            : raw;
        if (kDebugMode) {
          print('❌ Invalid JSON response (status ${response.statusCode}): $safe');
        }
      } catch (_) {}

      throw Exception('Invalid server response: ${response.statusCode}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseBody;
    } else {
      final serverMessage =
          responseBody is Map && responseBody.containsKey('error')
          ? responseBody['error']
          : null;

      // If unauthorized or forbidden -> force logout + redirect
      if (response.statusCode == 401 || response.statusCode == 403) {
        try {
          ApiService.logoutWithMessage(
            'Session expired or unauthorized. Please login again.',
          );
        } catch (_) {}
      }

      throw Exception(
        serverMessage ?? 'Request failed with status: ${response.statusCode}',
      );
    }
  }

  // Get Filter Options for Announcement Filters
  static Future<Map<String, dynamic>> getAnnouncementFilterOptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pengumuman/filter-options'),
        headers: await _getHeaders(),
      );

      // Debug print response body
      _debugResponse(response, label: 'GET /pengumuman/filter-options');

      final result = _handleResponse(response);

      if (result is Map<String, dynamic>) {
        return result;
      }

      // Fallback
      return {
        'success': false,
        'data': {
          'prioritas_options': [],
          'target_options': [],
          'status_options': [],
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting announcement filter options: $e');
      }
      rethrow;
    }
  }

  // Get Announcements with Pagination & Filters (Recommended)
  static Future<Map<String, dynamic>> getAnnouncementsPaginated({
    int page = 1,
    int limit = 10,
    String? prioritas,
    String? roleTarget,
    String? status,
    String? search,
  }) async {
    // Build query parameters
    Map<String, dynamic> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (prioritas != null && prioritas.isNotEmpty) {
      queryParams['prioritas'] = prioritas;
    }
    if (roleTarget != null && roleTarget.isNotEmpty) {
      queryParams['role_target'] = roleTarget;
    }
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
        Uri.parse('$baseUrl/pengumuman?$queryString'),
        headers: await _getHeaders(),
      );

      // Debug response body (truncated)
      _debugResponse(response, label: 'GET /pengumuman?$queryString');

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
        print('Error getting paginated announcements: $e');
      }
      rethrow;
    }
  }

  // Legacy method (keep for backward compatibility)
  // Now handles paginated response from backend
  static Future<List<dynamic>> getAnnouncements() async {
    final result = await ApiService().get('/pengumuman');

    // Debug legacy result shape
    try {
      if (result is List) {
        if (kDebugMode) {
          print('Legacy getAnnouncements: List with ${result.length} items');
        }
      } else if (result is Map) {
        if (kDebugMode) {
          print('Legacy getAnnouncements: Map keys = ${result.keys.toList()}');
        }
      } else {
        if (kDebugMode) {
          print('Legacy getAnnouncements: unexpected type ${result.runtimeType}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error logging legacy getAnnouncements result: $e');
      }
    }

    // Handle new pagination format
    if (result is Map<String, dynamic>) {
      return result['data'] ?? [];
    }

    // Handle old format (List)
    return result is List ? result : [];
  }
}
