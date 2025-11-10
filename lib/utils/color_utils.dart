import 'package:flutter/material.dart';

class ColorUtils {
  static Color getColorForIndex(int index) {
    final colors = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  static Color get primaryColor => Color(0xFF4F46E5);

  static Color getDayColor(String day) {
    // Support both Indonesian and English day names
    final Map<String, Color> dayColorMap = {
      // Indonesian days
      'Senin': Color(0xFF6366F1),
      'Selasa': Color(0xFF10B981),
      'Rabu': Color(0xFFF59E0B),
      'Kamis': Color(0xFFEF4444),
      'Jumat': Color(0xFF8B5CF6),
      'Sabtu': Color(0xFF06B6D4),

      // English days
      'Monday': Color(0xFF6366F1),
      'Tuesday': Color(0xFF10B981),
      'Wednesday': Color(0xFFF59E0B),
      'Thursday': Color(0xFFEF4444),
      'Friday': Color(0xFF8B5CF6),
      'Saturday': Color(0xFF06B6D4),

      // Semester names
      'Ganjil': Color(0xFF6366F1),
      'Genap': Color(0xFF10B981),
      'Odd': Color(0xFF6366F1),
      'Even': Color(0xFF10B981),
    };

    return dayColorMap[day] ?? _getFallbackColor(day);
  }

  static Color _getFallbackColor(String text) {
    // Generate consistent color based on text hash
    int hash = 0;
    for (int i = 0; i < text.length; i++) {
      hash = text.codeUnitAt(i) + ((hash << 5) - hash);
    }

    final colors = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFFEC4899),
      Color(0xFF84CC16),
    ];

    return colors[hash.abs() % colors.length];
  }

  // Get color for status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'aktif':
      case 'present':
      case 'hadir':
      case 'completed':
      case 'selesai':
        return Color(0xFF10B981);

      case 'inactive':
      case 'nonaktif':
      case 'absent':
      case 'absen':
      case 'pending':
      case 'menunggu':
        return Color(0xFFEF4444);

      case 'warning':
      case 'peringatan':
      case 'late':
      case 'terlambat':
        return Color(0xFFF59E0B);

      default:
        return Color(0xFF6B7280);
    }
  }

  // Get color for grade
  static Color getGradeColor(double grade) {
    if (grade >= 85) return Color(0xFF10B981); // Excellent
    if (grade >= 75) return Color(0xFF84CC16); // Good
    if (grade >= 65) return Color(0xFFF59E0B); // Average
    if (grade >= 55) return Color(0xFFFB923C); // Below Average
    return Color(0xFFEF4444); // Poor
  }

  // Get color for role
  static Color getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Color(0xFF2563EB); // Blue
      case 'guru':
        return Color(0xFF16A34A); // Teal
      case 'staff':
        return Color(0xFFFF9F1C); // Orange
      case 'wali':
        return Color(0xFF9333EA); // Purple
      default:
        return Color.fromARGB(255, 17, 19, 29);
    }
  }

  // Get color for subject category
  static Color getSubjectColor(String subjectName) {
    final Map<String, Color> subjectColors = {
      // Languages
      'bahasa': Color(0xFFEF4444),
      'indonesia': Color(0xFFEF4444),
      'inggris': Color(0xFF3B82F6),
      'english': Color(0xFF3B82F6),
      'language': Color(0xFFEF4444),

      // Sciences
      'matematika': Color(0xFF6366F1),
      'mathematics': Color(0xFF6366F1),
      'fisika': Color(0xFF8B5CF6),
      'physics': Color(0xFF8B5CF6),
      'kimia': Color(0xFFEC4899),
      'chemistry': Color(0xFFEC4899),
      'biologi': Color(0xFF10B981),
      'biology': Color(0xFF10B981),

      // Social Sciences
      'sejarah': Color(0xFFF59E0B),
      'history': Color(0xFFF59E0B),
      'geografi': Color(0xFF84CC16),
      'geography': Color(0xFF84CC16),
      'ekonomi': Color(0xFF06B6D4),
      'economy': Color(0xFF06B6D4),

      // Others
      'seni': Color(0xFFEC4899),
      'art': Color(0xFFEC4899),
      'olahraga': Color(0xFF84CC16),
      'sport': Color(0xFF84CC16),
      'komputer': Color(0xFF6366F1),
      'computer': Color(0xFF6366F1),
    };

    final lowerSubject = subjectName.toLowerCase();

    for (var key in subjectColors.keys) {
      if (lowerSubject.contains(key)) {
        return subjectColors[key]!;
      }
    }

    return _getFallbackColor(subjectName);
  }

  // Get gradient for cards
  static List<Color> getCardGradient(String type) {
    switch (type.toLowerCase()) {
      case 'primary':
        return [Color(0xFF4F46E5), Color(0xFF7C73FA)];
      case 'success':
        return [Color(0xFF10B981), Color(0xFF34D399)];
      case 'warning':
        return [Color(0xFFF59E0B), Color(0xFFFBBF24)];
      case 'danger':
        return [Color(0xFFEF4444), Color(0xFFF87171)];
      case 'info':
        return [Color(0xFF06B6D4), Color(0xFF67E8F9)];
      default:
        return [Color(0xFF6B7280), Color(0xFF9CA3AF)];
    }
  }

  // Get text color based on background color
  static Color getTextColorForBackground(Color backgroundColor) {
    // Calculate the perceptive luminance
    final luminance =
        (0.299 * backgroundColor.red +
            0.587 * backgroundColor.green +
            0.114 * backgroundColor.blue) /
        255;

    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  // Get shimmer base colors
  static Color get shimmerBaseColor => Colors.grey[300]!;
  static Color get shimmerHighlightColor => Colors.grey[100]!;

  // Get border color
  static Color get borderColor => Colors.grey[300]!;

  // Get divider color
  static Color get dividerColor => Colors.grey[200]!;

  // Get shadow color
  static Color get shadowColor => Colors.black.withOpacity(0.1);

  // Get disabled color
  static Color get disabledColor => Colors.grey[400]!;

  // Get success color variants
  static Color get successLight => Color(0xFFD1FAE5);
  static Color get successDark => Color(0xFF065F46);

  // Get warning color variants
  static Color get warningLight => Color(0xFFFEF3C7);
  static Color get warningDark => Color(0xFF92400E);

  // Get error color variants
  static Color get errorLight => Color(0xFFFEE2E2);
  static Color get errorDark => Color(0xFF991B1B);

  // Get info color variants
  static Color get infoLight => Color(0xFFE0F2FE);
  static Color get infoDark => Color(0xFF0C4A6E);
}
