import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';

class ScheduleCard extends StatelessWidget {
  final dynamic schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ScheduleCard({
    super.key,
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '07:00';

    try {
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        if (parts.length >= 2) {
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
        }
      }
      return timeString;
    } catch (e) {
      return '07:00';
    }
  }

  String _getValidDay(String? day) {
    if (day == null || day.isEmpty) return 'Monday';

    final dayMapping = {
      'Senin': 'Monday',
      'Selasa': 'Tuesday',
      'Rabu': 'Wednesday',
      'Kamis': 'Thursday',
      'Jumat': 'Friday',
      'Sabtu': 'Saturday',
      'Minggu': 'Monday',
    };

    return dayMapping[day] ?? day;
  }

  String _getDisplayDay(String? day) {
    if (day == null || day.isEmpty) return 'Senin';

    final dayMapping = {
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
      'Sunday': 'Minggu',
      'Senin': 'Senin',
      'Selasa': 'Selasa',
      'Rabu': 'Rabu',
      'Kamis': 'Kamis',
      'Jumat': 'Jumat',
      'Sabtu': 'Sabtu',
      'Minggu': 'Minggu',
    };

    return dayMapping[day] ?? 'Senin';
  }

  @override
  Widget build(BuildContext context) {
    final day = schedule['hari_nama'] ?? schedule['day'];
    final validDay = _getValidDay(day);
    final displayDay = _getDisplayDay(day);
    final cardColor = ColorUtils.getDayColor(validDay);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardColor.withOpacity(0.9),
                cardColor.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildTimeSection(),
                _buildVerticalDivider(),
                _buildContentSection(displayDay),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Text(
            _formatTime(schedule['jam_mulai']?.toString()),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Container(
            width: 1,
            height: 20,
            color: Colors.white10,
            margin: EdgeInsets.symmetric(vertical: 4),
          ),
          Text(
            _formatTime(schedule['jam_selesai']?.toString()),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${schedule['jam_ke'] ?? ''}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 60,
      margin: EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildContentSection(String displayDay) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schedule['mata_pelajaran_nama'] ??
                schedule['subject_name'] ??
                'No Subject',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          _buildInfoRow(
            Icons.person,
            schedule['guru_nama'] ?? schedule['teacher_name'] ?? 'No Teacher',
          ),
          SizedBox(height: 4),
          _buildInfoRow(
            Icons.class_,
            schedule['kelas_nama'] ?? schedule['class_name'] ?? 'No Class',
          ),
          SizedBox(height: 4),
          _buildInfoRow(
            Icons.calendar_month,
            displayDay,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isBold = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.white.withOpacity(0.8),
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        IconButton(
          icon: Icon(Icons.edit, color: Colors.white),
          onPressed: onEdit,
          tooltip: 'Edit Schedule',
        ),
        IconButton(
          icon: Icon(Icons.delete, color: Colors.white.withOpacity(0.8)),
          onPressed: onDelete,
          tooltip: 'Delete Schedule',
        ),
      ],
    );
  }
}