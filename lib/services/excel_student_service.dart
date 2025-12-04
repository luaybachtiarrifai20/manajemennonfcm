import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';

class ExcelService {
  // Export data siswa ke Excel
  static Future<void> exportStudentsToExcel({
    required List<dynamic> students,
    required BuildContext context,
  }) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Create a new Excel document
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Data Siswa';

      // Add header row
      sheet.getRangeByIndex(1, 1).setText('NIS');
      sheet.getRangeByIndex(1, 2).setText('Name');
      sheet.getRangeByIndex(1, 3).setText('Class');
      sheet.getRangeByIndex(1, 4).setText('Gender');
      sheet.getRangeByIndex(1, 5).setText('Date of Birth');
      sheet.getRangeByIndex(1, 6).setText('Address');
      sheet.getRangeByIndex(1, 7).setText('Parent Name');
      sheet.getRangeByIndex(1, 8).setText('Parent Email');
      sheet.getRangeByIndex(1, 9).setText('Phone Number');
      sheet.getRangeByIndex(1, 10).setText('Status');

      // Style header row
      final Range headerRange = sheet.getRangeByName('A1:J1');
      headerRange.cellStyle.backColor = '#4361EE';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;

      // Add data rows
      for (int i = 0; i < students.length; i++) {
        final student = students[i];
        final rowIndex = i + 2;

        sheet.getRangeByIndex(rowIndex, 1).setText(student['nis'] ?? '');
        sheet.getRangeByIndex(rowIndex, 2).setText(student['name'] ?? '');
        sheet.getRangeByIndex(rowIndex, 3).setText(student['class_name'] ?? '');
        sheet
            .getRangeByIndex(rowIndex, 4)
            .setText(_getGenderText(student['gender'], languageProvider));
        sheet
            .getRangeByIndex(rowIndex, 5)
            .setText(_formatDateForExport(student['date_of_birth']));
        sheet.getRangeByIndex(rowIndex, 6).setText(student['address'] ?? '');
        sheet
            .getRangeByIndex(rowIndex, 7)
            .setText(student['parent_name'] ?? '');
        sheet
            .getRangeByIndex(rowIndex, 8)
            .setText(student['parent_email'] ?? '');
        sheet
            .getRangeByIndex(rowIndex, 9)
            .setText(student['phone_number'] ?? '');
        sheet.getRangeByIndex(rowIndex, 10).setText('Active');

        // Alternate row colors for better readability
        if (i % 2 == 0) {
          final Range rowRange = sheet.getRangeByIndex(
            rowIndex,
            1,
            rowIndex,
            10,
          );
          rowRange.cellStyle.backColor = '#F8F9FA';
        }
      }

      // Auto fit columns
      for (int i = 1; i <= 10; i++) {
        sheet.autoFitColumn(i);
      }

      // Save and launch the file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();
      final String path =
          '${directory.path}/Data_Siswa_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final File file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      // Open the file
      await OpenFile.open(path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Student data exported successfully',
              'id': 'Data siswa berhasil diexport',
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

  // Download template Excel
  static Future<void> downloadTemplate(BuildContext context) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      // Create a new Excel document
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.name = 'Template Siswa';

      // Add header row
      sheet.getRangeByIndex(1, 1).setText('NIS*');
      sheet.getRangeByIndex(1, 2).setText('Name*');
      sheet.getRangeByIndex(1, 3).setText('Class*');
      sheet.getRangeByIndex(1, 4).setText('Gender*');
      sheet.getRangeByIndex(1, 5).setText('Date of Birth*');
      sheet.getRangeByIndex(1, 6).setText('Address*');
      sheet.getRangeByIndex(1, 7).setText('Parent Name*');
      sheet.getRangeByIndex(1, 8).setText('Parent Email');
      sheet.getRangeByIndex(1, 9).setText('Phone Number*');

      // Style header row
      final Range headerRange = sheet.getRangeByName('A1:I1');
      headerRange.cellStyle.backColor = '#28a745';
      headerRange.cellStyle.fontColor = '#FFFFFF';
      headerRange.cellStyle.bold = true;

      // Add example data
      sheet.getRangeByIndex(2, 1).setText('12345');
      sheet.getRangeByIndex(2, 2).setText('John Doe');
      sheet.getRangeByIndex(2, 3).setText('10 IPA 1');
      sheet.getRangeByIndex(2, 4).setText('Laki-laki');
      sheet.getRangeByIndex(2, 5).setText('2005-01-15');
      sheet.getRangeByIndex(2, 6).setText('Jl. Contoh No. 123');
      sheet.getRangeByIndex(2, 7).setText('Jane Doe');
      sheet.getRangeByIndex(2, 8).setText('jane@example.com');
      sheet.getRangeByIndex(2, 9).setText('08123456789');

      // Add notes
      sheet.getRangeByIndex(4, 1).setText('* Wajib diisi');
      sheet.getRangeByIndex(5, 1).setText('Format tanggal: YYYY-MM-DD');
      sheet
          .getRangeByIndex(6, 1)
          .setText('Jenis Kelamin: Laki-laki / Perempuan');

      // Auto fit columns
      for (int i = 1; i <= 9; i++) {
        sheet.autoFitColumn(i);
      }

      // Save and launch the file
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/Template_Import_Siswa.xlsx';
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

  // Download template CSV sebagai alternatif
  static Future<void> downloadTemplateCSV(BuildContext context) async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      final String csvContent =
          '''NIS*,Name*,Class*,Gender*,Date of Birth*,Address*,Parent Name*,Parent Email,Phone Number*
12345,John Doe,10 IPA 1,Laki-laki,2005-01-15,Jl. Contoh No. 123,Jane Doe,jane@example.com,08123456789
*Wajib diisi,Format tanggal: YYYY-MM-DD,Jenis Kelamin: Laki-laki / Perempuan''';

      // Get directory
      final Directory directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/Template_Import_Siswa.csv';
      final File file = File(path);
      await file.writeAsString(csvContent);

      // Open the file
      await OpenFile.open(path);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'CSV Template downloaded successfully',
              'id': 'Template CSV berhasil diunduh',
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
              'en': 'Failed to download CSV template: $e',
              'id': 'Gagal mengunduh template CSV: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper methods
  static String _getGenderText(
    String? gender,
    LanguageProvider languageProvider,
  ) {
    switch (gender) {
      case 'L':
        return languageProvider.getTranslatedText({
          'en': 'Male',
          'id': 'Laki-laki',
        });
      case 'P':
        return languageProvider.getTranslatedText({
          'en': 'Female',
          'id': 'Perempuan',
        });
      default:
        return '-';
    }
  }

  static String _formatDateForExport(String? date) {
    if (date == null) return '';
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return date;
    }
  }

  static String _parseGender(
    String? genderText,
    LanguageProvider languageProvider,
  ) {
    if (genderText == null) return 'L';

    final maleOptions = ['L', 'Laki-laki', 'Male', 'Laki', 'Pria'];
    final femaleOptions = ['P', 'Perempuan', 'Female', 'Wanita'];

    if (maleOptions.any(
      (option) => genderText.toLowerCase().contains(option.toLowerCase()),
    )) {
      return 'L';
    } else if (femaleOptions.any(
      (option) => genderText.toLowerCase().contains(option.toLowerCase()),
    )) {
      return 'P';
    } else {
      return 'L'; // Default to Male
    }
  }

  static String _parseDate(String? dateText) {
    if (dateText == null || dateText.isEmpty) return '';

    try {
      // Try to parse various date formats
      final date = DateTime.parse(dateText);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateText; // Return as is if parsing fails
    }
  }
}
