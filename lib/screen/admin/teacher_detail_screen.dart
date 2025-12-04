import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';

class TeacherDetailScreen extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const TeacherDetailScreen({super.key, required this.teacher});

  @override
  TeacherDetailScreenState createState() => TeacherDetailScreenState();
}

class TeacherDetailScreenState extends State<TeacherDetailScreen> {
  final ApiTeacherService apiTeacherService = ApiTeacherService();
  final ApiClassService apiClassService = ApiClassService();
  final ApiSubjectService apiSubjectService = ApiSubjectService();

  Map<String, dynamic>? _teacherDetail;
  List<dynamic> _classes = [];
  List<dynamic> _subjects = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTeacherDetail();
  }

  Future<void> _loadTeacherDetail() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Backend already returns everything including subjects and classes
      final teacherDetail = await apiTeacherService.getTeacherById(
        widget.teacher['id'],
      );

      // Fetch all classes and subjects for mapping
      final classes = await apiClassService.getClass();
      final subjects = await apiSubjectService.getSubject();

      setState(() {
        _teacherDetail = teacherDetail;
        _classes = classes;
        _subjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat detail guru: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInfoRow(
    String label,
    dynamic value, {
    bool isMultiline = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(0xFF4361EE).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIconForLabel(label),
              size: 18,
              color: Color(0xFF4361EE),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                if (value is List<String>)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: value.map((item) {
                      return Chip(
                        label: Text(
                          item,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4361EE),
                          ),
                        ),
                        backgroundColor: Color(0xFF4361EE).withOpacity(0.05),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Color(0xFF4361EE).withOpacity(0.2),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  Text(
                    value.toString().isNotEmpty
                        ? value.toString()
                        : 'Tidak ada',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: isMultiline ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Nama':
        return Icons.person;
      case 'NIP':
        return Icons.badge;
      case 'Email':
        return Icons.email;
      case 'Kelas':
        return Icons.school;
      case 'Mata Pelajaran':
        return Icons.menu_book;
      case 'Role':
        return Icons.work;
      case 'Status Wali Kelas':
        return Icons.groups;
      case 'ID':
        return Icons.fingerprint;
      case 'Tanggal Dibuat':
        return Icons.calendar_today;
      case 'Terakhir Diupdate':
        return Icons.update;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher = _teacherDetail ?? widget.teacher;

    // Helper to get names from IDs
    List<String> getNamesFromIds(dynamic ids, List<dynamic> sourceList) {
      if (ids == null) return [];

      List<String> idList = [];
      if (ids is List) {
        idList = ids.map((e) => e.toString()).toList();
      } else if (ids is String && ids.isNotEmpty) {
        idList = ids.split(',').map((e) => e.trim()).toList();
      }

      return idList.map((id) {
        final item = sourceList.firstWhere(
          (element) => element['id'].toString() == id,
          orElse: () => {'name': 'Unknown'},
        );
        return item['name']?.toString() ?? 'Unknown';
      }).toList();
    }

    // Use widget.teacher as fallback for IDs if _teacherDetail doesn't have them
    final effectiveTeacher = _teacherDetail ?? widget.teacher;

    // Prioritize IDs from widget.teacher if _teacherDetail has null/empty IDs
    // This is because getTeacherById might return raw row without aggregated IDs
    final classIds =
        effectiveTeacher['class_ids'] ?? widget.teacher['class_ids'];
    final subjectIds =
        effectiveTeacher['subject_ids'] ?? widget.teacher['subject_ids'];
    final homeroomClassId =
        effectiveTeacher['homeroom_class_id'] ??
        widget.teacher['homeroom_class_id'];

    final displayClassNames = getNamesFromIds(classIds, _classes);
    final displaySubjectNames = getNamesFromIds(subjectIds, _subjects);

    // Determine Homeroom Status
    String homeroomStatus = 'Tidak';
    if (homeroomClassId != null) {
      final homeroomClass = _classes.firstWhere(
        (c) => c['id'].toString() == homeroomClassId.toString(),
        orElse: () => null,
      );
      if (homeroomClass != null) {
        homeroomStatus = 'Ya, Kelas ${homeroomClass['name']}';
      }
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'Detail Guru',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF4361EE),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadTeacherDetail,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF4361EE),
                          Color(0xFF4361EE).withOpacity(0.7),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memuat detail guru...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red.withOpacity(0.1),
                          Colors.red.withOpacity(0.05),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: Colors.red.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Terjadi kesalahan:',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _loadTeacherDetail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4361EE),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Coba Lagi',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header dengan avatar
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF4361EE),
                          Color(0xFF4361EE).withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF4361EE).withOpacity(0.3),
                          blurRadius: 15,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Color(0xFF4361EE),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          teacher['name'],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4),
                        Text(
                          teacher['employee_number'] ?? 'Tidak ada NIP',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Informasi Pribadi
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Pribadi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4361EE),
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildInfoRow('Nama', teacher['name']),
                        _buildInfoRow(
                          'NIP',
                          teacher['employee_number'] ?? 'Tidak ada',
                        ),
                        _buildInfoRow('Email', teacher['email']),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  // Informasi Mengajar
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Mengajar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4361EE),
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildInfoRow(
                          'Kelas',
                          displayClassNames.isNotEmpty
                              ? displayClassNames
                              : 'Belum ditugaskan',
                          isMultiline: true,
                        ),
                        _buildInfoRow(
                          'Mata Pelajaran',
                          displaySubjectNames.isNotEmpty
                              ? displaySubjectNames
                              : 'Belum ditugaskan',
                          isMultiline: true,
                        ),
                        _buildInfoRow(
                          'Role',
                          teacher['role']?.toUpperCase() ?? 'GURU',
                        ),
                        _buildInfoRow('Status Wali Kelas', homeroomStatus),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),

                  SizedBox(height: 32),

                  // Tombol Kembali
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4361EE),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Kembali ke Daftar Guru',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
