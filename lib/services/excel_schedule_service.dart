import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class ExcelScheduleService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  // Export data jadwal mengajar ke Excel melalui backend
  static Future<void> exportSchedulesToExcel({
    required List<dynamic> schedules,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Validasi data terlebih dahulu
      final validatedData = validateScheduleData(schedules);

      // Kirim request ke backend
      final response = await http.post(
        Uri.parse('$baseUrl/teaching-schedule/export'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'schedules': validatedData}),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Data_Jadwal_Mengajar_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Schedule data exported successfully',
                'id': 'Data jadwal mengajar berhasil diexport',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to export data');
      }
    } catch (e) {
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

  // Download template Excel melalui backend
  static Future<void> downloadTemplate(BuildContext context) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Kirim request ke backend
      final response = await http.get(
        Uri.parse('$baseUrl/teaching-schedule/template'),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Template_Import_Jadwal_Mengajar.xlsx';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Template downloaded successfully',
                'id': 'Template berhasil diunduh',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to download template');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to download template: $e',
              'id': 'Gagal mengunduh template: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Validasi data melalui backend
  static Future<List<Map<String, dynamic>>> validateScheduleDataBackend(
    List<dynamic> schedules,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/teaching-schedule/validate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'schedules': schedules}),
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
  static List<Map<String, dynamic>> validateScheduleData(
    List<dynamic> schedules,
  ) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < schedules.length; i++) {
      final schedule = schedules[i];
      final Map<String, dynamic> validatedSchedule = {};

      // Validasi field required
      if (schedule['teacher_name'] == null ||
          schedule['teacher_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama guru tidak boleh kosong');
      } else {
        validatedSchedule['teacher_name'] = schedule['teacher_name'];
      }

      if (schedule['subject_name'] == null ||
          schedule['subject_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama mata pelajaran tidak boleh kosong');
      } else {
        validatedSchedule['subject_name'] = schedule['subject_name'];
      }

      if (schedule['class_name'] == null ||
          schedule['class_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama kelas tidak boleh kosong');
      } else {
        validatedSchedule['class_name'] = schedule['class_name'];
      }

      if (schedule['day_name'] == null ||
          schedule['day_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Hari tidak boleh kosong');
      } else {
        validatedSchedule['day_name'] = schedule['day_name'];
      }

      if (schedule['lesson_hour'] == null) {
        errors.add('Baris ${i + 1}: Jam ke tidak boleh kosong');
      } else {
        validatedSchedule['lesson_hour'] = schedule['lesson_hour'];
      }

      if (schedule['semester_name'] == null ||
          schedule['semester_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Semester tidak boleh kosong');
      } else {
        validatedSchedule['semester_name'] = schedule['semester_name'];
      }

      if (schedule['academic_year'] == null ||
          schedule['academic_year'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Tahun ajaran tidak boleh kosong');
      } else {
        validatedSchedule['academic_year'] = schedule['academic_year'];
      }

      // Field optional
      validatedSchedule['start_time'] = schedule['start_time'];
      validatedSchedule['end_time'] = schedule['end_time'];

      if (errors.isEmpty) {
        validatedData.add(validatedSchedule);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('Data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }
}
