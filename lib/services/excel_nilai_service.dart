import 'dart:io';
import 'dart:convert';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ExcelNilaiService {
  static const String baseUrl = ApiService.baseUrl; // Ganti dengan URL backend Anda

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
        Uri.parse('$baseUrl/export-nilai'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nilaiData': validatedData,
          'filters': filters
        }),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath = '${directory.path}/Data_Nilai_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        
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
  static List<Map<String, dynamic>> validateNilaiData(
    List<dynamic> nilaiData,
  ) {
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

      if (nilai['nama_siswa'] == null || nilai['nama_siswa'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Nama siswa tidak boleh kosong');
      } else {
        validatedNilai['nama_siswa'] = nilai['nama_siswa'];
      }

      if (nilai['kelas_nama'] == null || nilai['kelas_nama'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kelas tidak boleh kosong');
      } else {
        validatedNilai['kelas_nama'] = nilai['kelas_nama'];
      }

      if (nilai['mata_pelajaran_nama'] == null || nilai['mata_pelajaran_nama'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Mata pelajaran tidak boleh kosong');
      } else {
        validatedNilai['mata_pelajaran_nama'] = nilai['mata_pelajaran_nama'];
      }

      if (nilai['jenis'] == null || nilai['jenis'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Jenis nilai tidak boleh kosong');
      } else {
        validatedNilai['jenis'] = nilai['jenis'];
      }

      if (nilai['nilai'] == null) {
        errors.add('Baris ${i + 1}: Nilai tidak boleh kosong');
      } else {
        final nilaiValue = double.tryParse(nilai['nilai'].toString());
        if (nilaiValue == null || nilaiValue < 0 || nilaiValue > 100) {
          errors.add('Baris ${i + 1}: Nilai harus antara 0-100');
        } else {
          validatedNilai['nilai'] = nilaiValue;
        }
      }

      // Field optional
      validatedNilai['deskripsi'] = nilai['deskripsi'] ?? '';
      validatedNilai['tanggal'] = nilai['tanggal'] ?? '';
      validatedNilai['guru_nama'] = nilai['guru_nama'] ?? '';

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
  static String getJenisNilaiLabel(String jenis, LanguageProvider languageProvider) {
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
        return languageProvider.getTranslatedText({
          'en': 'Final',
          'id': 'UAS',
        });
      default:
        return jenis;
    }
  }
}