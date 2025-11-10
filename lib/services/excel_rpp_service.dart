import 'dart:io';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ExcelRppService {
  static const String baseUrl = 'http://localhost:3000/api'; // Ganti dengan URL backend Anda

  // Export data RPP ke Excel melalui backend
  static Future<void> exportRppToExcel({
    required List<dynamic> rppList,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Validasi data terlebih dahulu
      final validatedData = validateRppData(rppList);

      // Kirim request ke backend
      final response = await http.post(
        Uri.parse('$baseUrl/export-rpp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rppList': validatedData}),
      );

      if (response.statusCode == 200) {
        // Get directory untuk menyimpan file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String filePath = '${directory.path}/Data_RPP_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        
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
        Uri.parse('$baseUrl/validate-rpp'),
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
  static List<Map<String, dynamic>> validateRppData(
    List<dynamic> rppList,
  ) {
    final List<Map<String, dynamic>> validatedData = [];
    final List<String> errors = [];

    for (int i = 0; i < rppList.length; i++) {
      final rpp = rppList[i];
      final Map<String, dynamic> validatedRpp = {};

      // Validasi field required untuk export
      if (rpp['judul'] == null || rpp['judul'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Judul RPP tidak boleh kosong');
      } else {
        validatedRpp['judul'] = rpp['judul'];
      }

      if (rpp['mata_pelajaran_nama'] == null || rpp['mata_pelajaran_nama'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Mata pelajaran tidak boleh kosong');
      } else {
        validatedRpp['mata_pelajaran_nama'] = rpp['mata_pelajaran_nama'];
      }

      if (rpp['kelas_nama'] == null || rpp['kelas_nama'].toString().isEmpty) {
        errors.add('Baris ${i + 1}: Kelas tidak boleh kosong');
      } else {
        validatedRpp['kelas_nama'] = rpp['kelas_nama'];
      }

      // Field lainnya
      validatedRpp['guru_nama'] = rpp['guru_nama'] ?? '';
      validatedRpp['semester'] = rpp['semester'] ?? '';
      validatedRpp['tahun_ajaran'] = rpp['tahun_ajaran'] ?? '';
      validatedRpp['status'] = rpp['status'] ?? '';
      validatedRpp['created_at'] = rpp['created_at'] ?? '';
      validatedRpp['catatan_admin'] = rpp['catatan_admin'] ?? '';
      validatedRpp['kompetensi_dasar'] = rpp['kompetensi_dasar'] ?? '';
      validatedRpp['tujuan_pembelajaran'] = rpp['tujuan_pembelajaran'] ?? '';
      validatedRpp['materi_pembelajaran'] = rpp['materi_pembelajaran'] ?? '';
      validatedRpp['metode_pembelajaran'] = rpp['metode_pembelajaran'] ?? '';
      validatedRpp['media_pembelajaran'] = rpp['media_pembelajaran'] ?? '';
      validatedRpp['sumber_belajar'] = rpp['sumber_belajar'] ?? '';
      validatedRpp['langkah_pembelajaran'] = rpp['langkah_pembelajaran'] ?? '';
      validatedRpp['penilaian'] = rpp['penilaian'] ?? '';

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
  static String _getStatusText(String? status, LanguageProvider languageProvider) {
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