import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class ExcelRppService {
  static String get baseUrl => ApiService.baseUrl;

  // Export data RPP ke Excel melalui backend
  static Future<void> exportRppToExcel({
    required List<dynamic> rppList,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Validasi data terlebih dahulu
      final validatedData = validateRppData(rppList);

      // Kirim request ke backend menggunakan ApiService untuk handle auth headers
      // Note: ApiService.post returns decoded JSON, so we need to handle it differently
      // or we can just add headers manually here if we want to keep using http.post for blob response

      final token =
          await ApiService.getToken(); // Need to expose this or get from prefs

      final response = await http.post(
        Uri.parse('$baseUrl/rpp/export'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'rppList': validatedData}),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Data_RPP_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'RPP data exported successfully',
                'id': 'Data RPP berhasil diexport',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to export RPP data');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to export RPP data: $e',
              'id': 'Gagal mengexport data RPP: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Validasi data melalui backend
  static Future<List<Map<String, dynamic>>> validateRppDataBackend(
    List<dynamic> rppData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rpp/validate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rppData': rppData}),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        return List<Map<String, dynamic>>.from(responseData['validatedData']);
      } else {
        throw Exception(responseData['message'] ?? 'RPP validation failed');
      }
    } catch (e) {
      throw Exception('RPP validation error: $e');
    }
  }

  // Helper method untuk validasi data sebelum export (local fallback)
  static List<Map<String, dynamic>> validateRppData(List<dynamic> rppList) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < rppList.length; i++) {
      final rpp = rppList[i];
      final Map<String, dynamic> validatedRpp = {};

      // Validasi field required untuk export
      if (rpp['title'] == null || rpp['title'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Judul RPP tidak boleh kosong');
      } else {
        validatedRpp['title'] = rpp['title'];
      }

      if (rpp['subject_name'] == null ||
          rpp['subject_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Mata pelajaran tidak boleh kosong');
      } else {
        validatedRpp['subject_name'] = rpp['subject_name'];
      }

      if (rpp['class_name'] == null || rpp['class_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kelas tidak boleh kosong');
      } else {
        validatedRpp['class_name'] = rpp['class_name'];
      }

      // Field lainnya
      validatedRpp['teacher_name'] = rpp['teacher_name'] ?? '';
      validatedRpp['semester'] = rpp['semester'] ?? '';
      validatedRpp['academic_year'] = rpp['academic_year'] ?? '';
      validatedRpp['status'] = rpp['status'] ?? '';
      validatedRpp['created_at'] = rpp['created_at'] ?? '';

      // Map keys to match backend expectation
      validatedRpp['note_admin'] =
          rpp['catatan_admin'] ?? rpp['note_admin'] ?? '';
      validatedRpp['basic_competence'] =
          rpp['basic_competence'] ?? rpp['basic_competency'] ?? '';
      validatedRpp['learning_objective'] =
          rpp['learning_objective'] ?? rpp['learning_objectives'] ?? '';
      validatedRpp['main_material'] =
          rpp['main_material'] ?? rpp['learning_materials'] ?? '';
      validatedRpp['learning_method'] =
          rpp['learning_method'] ?? rpp['learning_methods'] ?? '';
      validatedRpp['media_tools'] =
          rpp['media_tools'] ?? rpp['learning_media'] ?? '';
      validatedRpp['learning_source'] =
          rpp['learning_source'] ?? rpp['learning_sources'] ?? '';
      validatedRpp['learning_activities'] =
          rpp['learning_activities'] ?? rpp['learning_steps'] ?? '';
      validatedRpp['assessment'] = rpp['assessment'] ?? '';

      if (errors.isEmpty) {
        validatedData.add(validatedRpp);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('RPP data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

  // Helper methods
  static String _getStatusText(
    String? status,
    LanguageProvider languageProvider,
  ) {
    switch (status) {
      case 'Disetujui':
        return languageProvider.getTranslatedText({
          'en': 'Approved',
          'id': 'Disetujui',
        });
      case 'Menunggu':
        return languageProvider.getTranslatedText({
          'en': 'Pending',
          'id': 'Menunggu',
        });
      case 'Ditolak':
        return languageProvider.getTranslatedText({
          'en': 'Rejected',
          'id': 'Ditolak',
        });
      default:
        return status ?? '-';
    }
  }
}
