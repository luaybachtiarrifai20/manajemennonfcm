import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class ExcelPresenceService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  // Export data absensi ke Excel melalui backend
  static Future<void> exportPresenceToExcel({
    required List<dynamic> presenceData,
    required BuildContext context,
    Map<String, dynamic> filters = const {},
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      print('Starting export with ${presenceData.length} records');

      // Validasi data
      if (presenceData.isEmpty) {
        throw Exception('No attendance data to export');
      }

      // Kirim request ke backend
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/export'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'presenceData': presenceData, 'filters': filters}),
      );

      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        // Cek jika response adalah file Excel (bukan JSON)
        final contentType = response.headers['content-type'];
        if (contentType?.contains(
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ) ==
            true) {
          // Simpan file Excel
          final Directory directory = await getApplicationDocumentsDirectory();
          final String filePath =
              '${directory.path}/Data_Absensi_${DateTime.now().millisecondsSinceEpoch}.xlsx';

          final File file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          print('File saved to: $filePath');

          // Buka file
          final result = await OpenFile.open(filePath);
          print('Open file result: $result');

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Presence data exported successfully',
                    'id': 'Data absensi berhasil diexport',
                  }),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Response bukan file Excel, mungkin error JSON
          final responseBody = response.body;
          print('Unexpected response: $responseBody');
          throw Exception('Server returned unexpected response format');
        }
      } else {
        // Handle error response
        final errorData = jsonDecode(response.body);
        print('Error response: $errorData');
        throw Exception(
          errorData['message'] ??
              'Failed to export data (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      print('Export error details: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Failed to export data: $e',
                'id': 'Gagal mengexport data: $e',
              }),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Validasi data absensi melalui backend
  static Future<List<Map<String, dynamic>>> validatePresenceDataBackend(
    List<dynamic> presenceData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/validate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'presenceData': presenceData}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return List<Map<String, dynamic>>.from(responseData['validatedData']);
      } else {
        throw Exception(responseData['message'] ?? 'Validation failed');
      }
    } catch (e) {
      throw Exception('Validation error: $e');
    }
  }

  // Helper method untuk validasi data sebelum export (local fallback)
  static List<Map<String, dynamic>> validatePresenceData(
    List<dynamic> presenceData,
  ) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < presenceData.length; i++) {
      final presence = presenceData[i];
      final Map<String, dynamic> validatedPresence = {};

      // Validasi field required
      if (presence['nis'] == null || presence['nis'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: NIS tidak boleh kosong');
      } else {
        validatedPresence['nis'] = presence['nis'];
      }

      if (presence['student_name'] == null ||
          presence['student_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama siswa tidak boleh kosong');
      } else {
        validatedPresence['student_name'] = presence['student_name'];
      }

      if (presence['class_name'] == null ||
          presence['class_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kelas tidak boleh kosong');
      } else {
        validatedPresence['class_name'] = presence['class_name'];
      }

      if (presence['subject_name'] == null ||
          presence['subject_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Mata pelajaran tidak boleh kosong');
      } else {
        validatedPresence['subject_name'] = presence['subject_name'];
      }

      if (presence['date'] == null || presence['date'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Tanggal tidak boleh kosong');
      } else {
        validatedPresence['date'] = presence['date'];
      }

      if (presence['status'] == null || presence['status'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Status tidak boleh kosong');
      } else {
        final status = presence['status'].toString().toLowerCase();
        final allowedStatus = ['hadir', 'terlambat', 'izin', 'sakit', 'alpha'];
        if (!allowedStatus.contains(status)) {
          errors.add(
            'Baris ${i + 1}: Status harus salah satu dari: hadir, terlambat, izin, sakit, alpha',
          );
        } else {
          validatedPresence['status'] = status;
        }
      }

      // Field optional
      validatedPresence['notes'] = presence['notes'] ?? '';
      validatedPresence['teacher_name'] = presence['teacher_name'] ?? '';
      validatedPresence['lesson_hour'] = presence['lesson_hour'] ?? '';

      if (errors.isEmpty) {
        validatedData.add(validatedPresence);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('Data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

  // Helper method untuk mendapatkan label status
  static String getStatusLabel(
    String status,
    LanguageProvider languageProvider,
  ) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
      case 'terlambat':
        return languageProvider.getTranslatedText({
          'en': 'Late',
          'id': 'Terlambat',
        });
      case 'izin':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'sakit':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
        });
      case 'alpha':
        return languageProvider.getTranslatedText({
          'en': 'Absent',
          'id': 'Alpha',
        });
      default:
        return status;
    }
  }

  // Helper method untuk format tanggal
  static String formatDateForExport(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Helper method untuk mendapatkan nama hari
  static String getDayName(DateTime date, LanguageProvider languageProvider) {
    final days = [
      languageProvider.getTranslatedText({'en': 'Sunday', 'id': 'Minggu'}),
      languageProvider.getTranslatedText({'en': 'Monday', 'id': 'Senin'}),
      languageProvider.getTranslatedText({'en': 'Tuesday', 'id': 'Selasa'}),
      languageProvider.getTranslatedText({'en': 'Wednesday', 'id': 'Rabu'}),
      languageProvider.getTranslatedText({'en': 'Thursday', 'id': 'Kamis'}),
      languageProvider.getTranslatedText({'en': 'Friday', 'id': 'Jumat'}),
      languageProvider.getTranslatedText({'en': 'Saturday', 'id': 'Sabtu'}),
    ];
    return days[date.weekday % 7];
  }
}
