import 'dart:convert';
import 'dart:io';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ExcelScheduleService {
  static const String baseUrl = ApiService.baseUrl; // Ganti dengan URL backend Anda

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
        Uri.parse('$baseUrl/export-schedules'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'schedules': validatedData}),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath = '${directory.path}/Data_Jadwal_Mengajar_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        
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
        Uri.parse('$baseUrl/download-template-schedule'),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath = '${directory.path}/Template_Import_Jadwal_Mengajar.xlsx';
        
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
        Uri.parse('$baseUrl/validate-schedules'),
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
      if (schedule['guru_nama'] == null ||
          schedule['guru_nama'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama guru tidak boleh kosong');
      } else {
        validatedSchedule['guru_nama'] = schedule['guru_nama'];
      }

      if (schedule['mata_pelajaran_nama'] == null ||
          schedule['mata_pelajaran_nama'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama mata pelajaran tidak boleh kosong');
      } else {
        validatedSchedule['mata_pelajaran_nama'] =
            schedule['mata_pelajaran_nama'];
      }

      if (schedule['kelas_nama'] == null ||
          schedule['kelas_nama'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama kelas tidak boleh kosong');
      } else {
        validatedSchedule['kelas_nama'] = schedule['kelas_nama'];
      }

      if (schedule['hari_nama'] == null ||
          schedule['hari_nama'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Hari tidak boleh kosong');
      } else {
        validatedSchedule['hari_nama'] = schedule['hari_nama'];
      }

      if (schedule['jam_ke'] == null) {
        errors.add('Baris ${i + 1}: Jam ke tidak boleh kosong');
      } else {
        validatedSchedule['jam_ke'] = schedule['jam_ke'];
      }

      if (schedule['semester_nama'] == null ||
          schedule['semester_nama'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Semester tidak boleh kosong');
      } else {
        validatedSchedule['semester_nama'] = schedule['semester_nama'];
      }

      if (schedule['tahun_ajaran'] == null ||
          schedule['tahun_ajaran'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Tahun ajaran tidak boleh kosong');
      } else {
        validatedSchedule['tahun_ajaran'] = schedule['tahun_ajaran'];
      }

      // Field optional
      validatedSchedule['jam_mulai'] = schedule['jam_mulai'];
      validatedSchedule['jam_selesai'] = schedule['jam_selesai'];

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