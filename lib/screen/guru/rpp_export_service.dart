import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class RPPExportService {
  static Future<void> exportToWord(String content, String fileName) async {
    try {
      // Format content untuk Word-like structure
      await Future.delayed(Duration(milliseconds: 100));
      final formattedContent = _formatForWord(content);
      
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.docx');
      
      // Untuk simulasi file Word, kita buat file text dengan formatting
      await file.writeAsString(formattedContent);
      
      await OpenFile.open(file.path);
    } catch (e) {
      throw Exception('Gagal export ke Word: $e');
    }
  }

  static Future<void> exportToPDF(String content, String fileName) async {
    try {
      // Implementasi PDF export yang lebih baik
      await Future.delayed(Duration(milliseconds: 100));
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName.pdf');
      
      // Untuk saat ini, kita buat file text sebagai simulasi
      // Di production, gunakan library PDF generation seperti pdf atau printing
      await file.writeAsString('PDF Export: $content');
      
      await OpenFile.open(file.path);
    } catch (e) {
      throw Exception('Gagal export ke PDF: $e');
    }
  }

  static String _formatForWord(String content) {
    final buffer = StringBuffer();
    final lines = content.split('\n');
    
    for (String line in lines) {
      if (line.startsWith('RENCANA PELAKSANAAN PEMBELAJARAN')) {
        buffer.writeln('<h1 style="text-align: center; color: #4F46E5;">$line</h1>');
      } else if (line.startsWith('A.') || line.startsWith('B.') || line.startsWith('C.')) {
        buffer.writeln('<h2 style="color: #4F46E5;">$line</h2>');
      } else if (line.startsWith('|')) {
        buffer.writeln('<table border="1"><tr>${_formatTableRow(line)}</tr></table>');
      } else if (line.startsWith('•')) {
        buffer.writeln('<li>$line</li>');
      } else {
        buffer.writeln('<p>$line</p>');
      }
    }
    
    return '''
<html>
<head>
<meta charset="UTF-8">
<title>RPP Document</title>
</head>
<body>
${buffer.toString()}
</body>
</html>
''';
  }

  static String _formatTableRow(String line) {
    final cells = line.split('|').where((cell) => cell.trim().isNotEmpty).toList();
    return cells.map((cell) => '<td style="padding: 8px; border: 1px solid #ccc;">${cell.trim()}</td>').join();
  }
}