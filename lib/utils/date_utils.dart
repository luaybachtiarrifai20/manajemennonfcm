// date_utils.dart - Helper untuk parsing tanggal dengan timezone yang benar
import 'package:intl/intl.dart';

class AppDateUtils {
  /// Parse string tanggal (YYYY-MM-DD) sebagai local date, bukan UTC
  /// Ini mencegah masalah timezone yang membuat tanggal mundur 1 hari
  static DateTime parseLocalDate(String dateString) {
    try {
      // Parse dengan format YYYY-MM-DD
      final parts = dateString.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        
        // Buat DateTime sebagai local time, bukan UTC
        return DateTime(year, month, day);
      }
      
      // Fallback: parse normal tapi convert ke local
      return DateTime.parse(dateString).toLocal();
    } catch (e) {
      // Jika gagal, kembalikan hari ini
      return DateTime.now();
    }
  }
  
  /// Format DateTime ke string YYYY-MM-DD untuk dikirim ke backend
  static String formatDateForApi(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
  
  /// Format DateTime ke format yang lebih readable: dd/MM/yyyy
  static String formatDateReadable(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
  
  /// Format DateTime ke format Indonesia: dd MMMM yyyy
  static String formatDateIndonesian(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }
  
  /// Format DateTime ke format lengkap: EEEE, dd MMMM yyyy
  static String formatDateFull(DateTime date) {
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }
  
  /// Parse string date dari response API dengan aman
  /// Menangani berbagai format tanggal dan timezone
  static DateTime? parseApiDate(dynamic dateValue) {
    if (dateValue == null) return null;
    
    try {
      if (dateValue is DateTime) {
        return dateValue;
      }
      
      final String dateString = dateValue.toString();
      
      // Jika format YYYY-MM-DD (tanpa waktu), parse sebagai local date
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateString)) {
        return parseLocalDate(dateString);
      }
      
      // Jika ada timestamp ISO (dengan T dan timezone), parse normal
      if (dateString.contains('T')) {
        return DateTime.parse(dateString).toLocal();
      }
      
      // Default fallback
      return parseLocalDate(dateString);
    } catch (e) {
      return null;
    }
  }
  
  /// Format tanggal dari string ke format yang diinginkan
  /// Dengan handling timezone yang benar
  static String formatDateString(String? dateString, {String format = 'dd/MM/yyyy'}) {
    if (dateString == null || dateString.isEmpty) return '-';
    
    try {
      final date = parseApiDate(dateString);
      if (date == null) return dateString;
      
      return DateFormat(format, 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }
}
