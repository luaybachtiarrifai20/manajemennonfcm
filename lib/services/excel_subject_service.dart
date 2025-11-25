import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class ExcelSubjectService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  // Export data mata pelajaran ke Excel melalui backend
  static Future<void> exportSubjectsToExcel({
    required List<dynamic> subjects,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Validasi data terlebih dahulu
      final validatedData = validateSubjectData(subjects);

      // Kirim request ke backend
      final response = await http.post(
        Uri.parse('$baseUrl/export-subjects'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'subjects': validatedData}),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Data_Mata_Pelajaran_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Subject data exported successfully',
                'id': 'Data mata pelajaran berhasil diexport',
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
        Uri.parse('$baseUrl/download-subject-template'),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Template_Import_Mata_Pelajaran.xlsx';

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
  static Future<List<Map<String, dynamic>>> validateSubjectDataBackend(
    List<dynamic> subjects,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/validate-subjects'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'subjects': subjects}),
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
  static List<Map<String, dynamic>> validateSubjectData(
    List<dynamic> subjects,
  ) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final Map<String, dynamic> validatedSubject = {};

      // Include ID for backend lookup
      if (subject['id'] != null) {
        validatedSubject['id'] = subject['id'];
      }

      // Validasi field required
      if (subject['kode'] == null || subject['kode'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kode mata pelajaran tidak boleh kosong');
      } else {
        validatedSubject['kode'] = subject['kode'];
      }

      if (subject['nama'] == null || subject['nama'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama mata pelajaran tidak boleh kosong');
      } else {
        validatedSubject['nama'] = subject['nama'];
      }

      // Field optional
      validatedSubject['deskripsi'] = subject['deskripsi'] ?? '';
      validatedSubject['kelas_names'] = _getClassNames(subject);

      if (errors.isEmpty) {
        validatedData.add(validatedSubject);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('Data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

  // Helper methods
  static String _getClassNames(Map<String, dynamic> subject) {
    if (subject['kelas_names'] != null) {
      return subject['kelas_names'];
    }

    final kelasList = subject['kelas_list'] ?? [];
    if (kelasList is List) {
      return kelasList.map((kelas) => kelas['nama'] ?? '').join(', ');
    }

    return '';
  }
}
