import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class ExcelNilaiService {
  // static const String baseUrl = ApiService.baseUrl;
  static String get baseUrl => ApiService.baseUrl;

  // Export data nilai ke Excel melalui backend
  static Future<void> exportNilaiToExcel({
    required List<dynamic> nilaiData,
    required BuildContext context,
    Map<String, dynamic> filters = const {},
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Validasi data terlebih dahulu
      final validatedData = validateNilaiData(nilaiData);

      // Kirim request ke backend
      final response = await http.post(
        Uri.parse('$baseUrl/grade/export'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nilaiData': validatedData, 'filters': filters}),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath =
            '${directory.path}/Data_Nilai_${DateTime.now().millisecondsSinceEpoch}.xlsx';

        // Simpan file yang didownload
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Buka file
        await OpenFile.open(filePath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Grade data exported successfully',
                'id': 'Data nilai berhasil diexport',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to export grade data');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to export grade data: $e',
              'id': 'Gagal mengexport data nilai: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper method untuk validasi data sebelum export
  static List<Map<String, dynamic>> validateNilaiData(List<dynamic> nilaiData) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < nilaiData.length; i++) {
      final nilai = nilaiData[i];
      final Map<String, dynamic> validatedNilai = {};

      // Validasi field required
      if (nilai['nis'] == null || nilai['nis'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: NIS tidak boleh kosong');
      } else {
        validatedNilai['nis'] = nilai['nis'];
      }

      if (nilai['student_name'] == null ||
          nilai['student_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama siswa tidak boleh kosong');
      } else {
        validatedNilai['student_name'] = nilai['student_name'];
      }

      if (nilai['class_name'] == null ||
          nilai['class_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kelas tidak boleh kosong');
      } else {
        validatedNilai['class_name'] = nilai['class_name'];
      }

      if (nilai['subject_name'] == null ||
          nilai['subject_name'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Mata pelajaran tidak boleh kosong');
      } else {
        validatedNilai['subject_name'] = nilai['subject_name'];
      }

      if (nilai['type'] == null || nilai['type'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Jenis nilai tidak boleh kosong');
      } else {
        validatedNilai['type'] = nilai['type'];
      }

      if (nilai['grade'] == null) {
        errors.add('Baris ${i + 1}: Nilai tidak boleh kosong');
      } else {
        final nilaiValue = double.tryParse(nilai['grade'].toString());
        if (nilaiValue == null || nilaiValue < 0 || nilaiValue > 100) {
          errors.add('Baris ${i + 1}: Nilai harus antara 0-100');
        } else {
          validatedNilai['grade'] = nilaiValue;
        }
      }

      // Field optional
      validatedNilai['description'] = nilai['description'] ?? '';
      validatedNilai['date'] = nilai['date'] ?? '';
      validatedNilai['teacher_name'] = nilai['teacher_name'] ?? '';

      if (errors.isEmpty) {
        validatedData.add(validatedNilai);
      }
    }

    if (errors.isNotEmpty) {
      throw Exception('Data validation failed:\n${errors.join('\n')}');
    }

    return validatedData;
  }

  // Helper method untuk mendapatkan label jenis nilai
  static String getJenisNilaiLabel(
    String jenis,
    LanguageProvider languageProvider,
  ) {
    switch (jenis) {
      case 'harian':
        return languageProvider.getTranslatedText({
          'en': 'Daily',
          'id': 'Harian',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'ulangan':
        return languageProvider.getTranslatedText({
          'en': 'Quiz',
          'id': 'Ulangan',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      default:
        return jenis;
    }
  }
}
