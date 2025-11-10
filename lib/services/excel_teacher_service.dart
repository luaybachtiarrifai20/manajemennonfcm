import 'dart:io';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class ExcelTeacherService {
  // Export data guru ke Excel
  static Future<void> exportTeachersToExcel({
    required List<dynamic> teachers,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();
    
    try {
      // Create a new Excel document
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Data Guru';

      // Add header row
      sheet.getRangeByIndex(1, 1).setText('NIP*');
      sheet.getRangeByIndex(1, 2).setText('Nama*');
      sheet.getRangeByIndex(1, 3).setText('Email*');
      sheet.getRangeByIndex(1, 4).setText('Mata Pelajaran');
      sheet.getRangeByIndex(1, 5).setText('Kelas');
      sheet.getRangeByIndex(1, 6).setText('No. Telepon');
      sheet.getRangeByIndex(1, 7).setText('Wali Kelas');
      sheet.getRangeByIndex(1, 8).setText('Status');

      // Style header row
      final Range headerRange = sheet.getRangeByName('A1:H1');
      headerRange.cellStyle.backColor = '#4361EE';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;

      // Add data rows
      for (int i = 0; i < teachers.length; i++) {
        final teacher = teachers[i];
        final rowIndex = i + 2;

        sheet.getRangeByIndex(rowIndex, 1).setText(teacher['nip'] ?? '');
        sheet.getRangeByIndex(rowIndex, 2).setText(teacher['nama'] ?? '');
        sheet.getRangeByIndex(rowIndex, 3).setText(teacher['email'] ?? '');
        sheet.getRangeByIndex(rowIndex, 4).setText(teacher['mata_pelajaran_names'] ?? '');
        sheet.getRangeByIndex(rowIndex, 5).setText(teacher['kelas_nama'] ?? '');
        sheet.getRangeByIndex(rowIndex, 6).setText(teacher['no_telepon'] ?? '');
        sheet.getRangeByIndex(rowIndex, 7).setText(_getWaliKelasText(teacher['is_wali_kelas'], languageProvider));
        sheet.getRangeByIndex(rowIndex, 8).setText('Active');

        // Alternate row colors for better readability
        if (i % 2 == 0) {
          final Range rowRange = sheet.getRangeByIndex(rowIndex, 1, rowIndex, 8);
          rowRange.cellStyle.backColor = '#F8F9FA';
        }
      }

      // Auto fit columns
      for (int i = 1; i <= 8; i++) {
        sheet.autoFitColumn(i);
      }

      // Save and launch the file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/Data_Guru_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final File file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      // Open the file
      await OpenFile.open(path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Teacher data exported successfully',
              'id': 'Data guru berhasil diexport',
            }),
          ),
          backgroundColor: Colors.green,
        ),
      );
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

  // Download template Excel untuk guru
  static Future<void> downloadTemplate(BuildContext context) async {
    final languageProvider = context.read<LanguageProvider>();
    
    try {
      // Create a new Excel document
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Template Guru';

      // Add header row
      sheet.getRangeByIndex(1, 1).setText('NIP*');
      sheet.getRangeByIndex(1, 2).setText('Nama*');
      sheet.getRangeByIndex(1, 3).setText('Email*');
      sheet.getRangeByIndex(1, 4).setText('Mata Pelajaran');
      sheet.getRangeByIndex(1, 5).setText('Kelas');
      sheet.getRangeByIndex(1, 6).setText('No. Telepon');
      sheet.getRangeByIndex(1, 7).setText('Wali Kelas');

      // Style header row
      final Range headerRange = sheet.getRangeByName('A1:G1');
      headerRange.cellStyle.backColor = '#28a745';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;

      // Add example data
      sheet.getRangeByIndex(2, 1).setText('198001012000121001');
      sheet.getRangeByIndex(2, 2).setText('Budi Santoso');
      sheet.getRangeByIndex(2, 3).setText('budi.santoso@sekolah.sch.id');
      sheet.getRangeByIndex(2, 4).setText('Matematika,Fisika');
      sheet.getRangeByIndex(2, 5).setText('X IPA 1');
      sheet.getRangeByIndex(2, 6).setText('081234567890');
      sheet.getRangeByIndex(2, 7).setText('Ya');

      // Add notes
      sheet.getRangeByIndex(4, 1).setText('* Wajib diisi');
      sheet.getRangeByIndex(5, 1).setText('Format Wali Kelas: Ya / Tidak');
      sheet.getRangeByIndex(6, 1).setText('Multiple mata pelajaran dipisah dengan koma');

      // Auto fit columns
      for (int i = 1; i <= 7; i++) {
        sheet.autoFitColumn(i);
      }

      // Save and launch the file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/Template_Import_Guru.xlsx';
      final File file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      // Open the file
      await OpenFile.open(path);

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
  
  // Helper methods
  static String _getWaliKelasText(dynamic isWaliKelas, LanguageProvider languageProvider) {
    if (isWaliKelas == true || isWaliKelas == 1 || isWaliKelas == '1') {
      return languageProvider.getTranslatedText({
        'en': 'Yes',
        'id': 'Ya',
      });
    } else {
      return languageProvider.getTranslatedText({
        'en': 'No',
        'id': 'Tidak',
      });
    }
  }

  static String _parseWaliKelas(String? waliKelasText, LanguageProvider languageProvider) {
    if (waliKelasText == null) return 'false';
    
    final yesOptions = [
      'Ya', 'Yes', 'Y', 'True', '1'
    ];

    if (yesOptions.any((option) => waliKelasText.toLowerCase().contains(option.toLowerCase()))) {
      return 'true';
    } else {
      return 'false';
    }
  }
}