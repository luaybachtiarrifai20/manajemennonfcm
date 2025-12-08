import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class ScheduleFormDialog extends StatefulWidget {
  final List<dynamic> teacherList;
  final List<dynamic> subjectList;
  final List<dynamic> classList;
  final List<dynamic> hariList;
  final List<dynamic> semesterList;
  final List<dynamic> jamPelajaranList;
  final String semester;
  final String academicYear;
  final dynamic schedule;
  final dynamic apiService;
  final ApiTeacherService apiTeacherService;

  const ScheduleFormDialog({
    super.key,
    required this.teacherList,
    required this.subjectList,
    required this.classList,
    required this.hariList,
    required this.semesterList,
    required this.jamPelajaranList,
    required this.semester,
    required this.academicYear,
    this.schedule,
    required this.apiService,
    required this.apiTeacherService,
  });

  @override
  ScheduleFormDialogState createState() => ScheduleFormDialogState();
}

class ScheduleFormDialogState extends State<ScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedTeacher;
  late String _selectedSubject;
  late String _selectedClass;
  late String _selectedHari;
  late String _selectedSemester;
  late String _selectedJamPelajaran;

  List<dynamic> _filteredSubjectList = [];
  List<dynamic> _availableJamPelajaranList = [];
  bool _isLoadingSubjects = false;
  bool _isLoadingJamPelajaran = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  Color _getPrimaryColor() {
    return Color(0xFF4361EE); // Blue untuk admin
  }

  void _initializeForm() {
    _selectedTeacher = '';
    _selectedSubject = '';
    _selectedClass = '';
    _selectedHari = '';
    _selectedSemester = widget.semester;
    _selectedJamPelajaran = '';

    _filteredSubjectList = widget.subjectList;
    _availableJamPelajaranList = [];

    if (widget.schedule != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setEditFormValues();
      });
    }

    if (widget.hariList.isNotEmpty && _selectedHari.isEmpty) {
      _selectedHari = widget.hariList.first['id']?.toString() ?? '';
    }
  }

  void _setEditFormValues() {
    setState(() {
      _selectedTeacher =
          widget.schedule['guru_id']?.toString() ??
          widget.schedule['teacher_id']?.toString() ??
          '';
      _selectedSubject =
          widget.schedule['mata_pelajaran_id']?.toString() ??
          widget.schedule['subject_id']?.toString() ??
          '';
      _selectedClass =
          widget.schedule['kelas_id']?.toString() ??
          widget.schedule['class_id']?.toString() ??
          '';
      _selectedHari =
          widget.schedule['hari_id']?.toString() ??
          widget.schedule['day_id']?.toString() ??
          '';
      _selectedSemester =
          widget.schedule['semester_id']?.toString() ??
          widget.schedule['semester']?.toString() ??
          widget.semester;
      _selectedJamPelajaran =
          widget.schedule['lesson_hour_id']?.toString() ??
          widget.schedule['jam_pelajaran_id']?.toString() ??
          '';

      if (_selectedTeacher.isNotEmpty) {
        _filterSubjectsByTeacher(_selectedTeacher);
      }

      if (_selectedHari.isNotEmpty &&
          _selectedClass.isNotEmpty &&
          _selectedSemester.isNotEmpty) {
        _filterAvailableJamPelajaran();
      }
    });
  }

  Future<void> _filterSubjectsByTeacher(String teacherId) async {
    try {
      setState(() => _isLoadingSubjects = true);

      final teacherSubjects = await widget.apiTeacherService
          .getSubjectByTeacher(teacherId);

      final filtered = widget.subjectList.where((subject) {
        return teacherSubjects.any(
          (teacherSubject) => teacherSubject['id'] == subject['id'],
        );
      }).toList();

      setState(() {
        _filteredSubjectList = filtered;
        _isLoadingSubjects = false;

        if (_selectedSubject.isNotEmpty) {
          final currentSubjectExists = filtered.any(
            (subject) => subject['id'] == _selectedSubject,
          );
          if (!currentSubjectExists) {
            _selectedSubject = '';
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error filtering subjects: $e');
      }
      setState(() {
        _filteredSubjectList = widget.subjectList;
        _isLoadingSubjects = false;
      });
      _showErrorSnackBar('Failed to load teacher subjects');
    }
  }

  Future<void> _filterAvailableJamPelajaran() async {
    try {
      setState(() => _isLoadingJamPelajaran = true);

      if (_selectedHari.isEmpty ||
          _selectedClass.isEmpty ||
          _selectedSemester.isEmpty) {
        setState(() {
          _availableJamPelajaranList = widget.jamPelajaranList;
          _isLoadingJamPelajaran = false;
        });
        return;
      }

      try {
        final availableJamPelajaran =
            await ApiScheduleService.getJamPelajaranByFilter(
              hariId: _selectedHari,
              semesterId: _selectedSemester,
              classId: _selectedClass,
              academicYear: widget.academicYear,
            );

        setState(() {
          _availableJamPelajaranList = availableJamPelajaran;
          _isLoadingJamPelajaran = false;

          if (_selectedJamPelajaran.isNotEmpty) {
            final currentJamExists = availableJamPelajaran.any(
              (jam) =>
                  jam['id'] == _selectedJamPelajaran &&
                      (jam['is_terpakai'] != 1 && jam['is_terpakai'] != true) ||
                  jam['id'] == widget.schedule['lesson_hour_id'] ||
                  jam['id'] == widget.schedule['jam_pelajaran_id'],
            );
            if (!currentJamExists) {
              _selectedJamPelajaran = '';
            }
          }
        });
      } catch (e) {
        setState(() {
          _availableJamPelajaranList = widget.jamPelajaranList;
          _isLoadingJamPelajaran = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error filtering jam pelajaran: $e');
      }
      setState(() {
        _availableJamPelajaranList = widget.jamPelajaranList;
        _isLoadingJamPelajaran = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': message,
              'id': message.replaceAll(
                'Failed to load teacher subjects',
                'Gagal memuat mata pelajaran guru',
              ),
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<dynamic> _removeDuplicates(List<dynamic> items, String idField) {
    final seen = <String>{};
    return items.where((item) {
      final id = item[idField]?.toString() ?? '';
      if (seen.contains(id)) {
        return false;
      } else {
        seen.add(id);
        return true;
      }
    }).toList();
  }

  String _formatTimeForDropdown(String? timeString) {
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

  String _translateDayName(String dayName, String languageCode) {
    if (languageCode == 'en') return dayName;
    const dayMap = {
      'Monday': 'Senin',
      'Tuesday': 'Selasa',
      'Wednesday': 'Rabu',
      'Thursday': 'Kamis',
      'Friday': 'Jumat',
      'Saturday': 'Sabtu',
      'Sunday': 'Minggu',
    };
    return dayMap[dayName] ?? dayName;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final uniqueTeacherList = _removeDuplicates(widget.teacherList, 'id');
        final uniqueClassList = _removeDuplicates(widget.classList, 'id');
        final uniqueHariList = _removeDuplicates(widget.hariList, 'id');
        final uniqueSemesterList = _removeDuplicates(widget.semesterList, 'id');
        final uniqueJamPelajaranList = _removeDuplicates(
          _availableJamPelajaranList,
          'id',
        );
        final uniqueSubjectList = _removeDuplicates(_filteredSubjectList, 'id');

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header dengan gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPrimaryColor(),
                        _getPrimaryColor().withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.schedule != null ? Icons.edit : Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.schedule != null
                              ? languageProvider.getTranslatedText({
                                  'en': 'Edit Schedule',
                                  'id': 'Edit Jadwal',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'Add Schedule',
                                  'id': 'Tambah Jadwal',
                                }),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTeacherDropdown(
                          uniqueTeacherList,
                          languageProvider,
                        ),
                        SizedBox(height: 12),
                        _buildSubjectDropdown(
                          uniqueSubjectList,
                          languageProvider,
                        ),
                        SizedBox(height: 12),
                        _buildClassDropdown(uniqueClassList, languageProvider),
                        SizedBox(height: 12),
                        _buildDayDropdown(uniqueHariList, languageProvider),
                        SizedBox(height: 12),
                        _buildSemesterDropdown(
                          uniqueSemesterList,
                          languageProvider,
                        ),
                        SizedBox(height: 12),
                        _buildTeachingHourDropdown(
                          uniqueJamPelajaranList,
                          languageProvider,
                        ),
                      ],
                    ),
                  ),
                ),

                // Actions
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            AppLocalizations.cancel.tr,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saveSchedule,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getPrimaryColor(),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Save',
                              'id': 'Simpan',
                            }),
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTeacherDropdown(
    List<dynamic> teachers,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({'en': 'Teacher', 'id': 'Guru'}),
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedTeacher.isNotEmpty ? _selectedTeacher : null,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Teacher',
                    'id': 'Pilih Guru',
                  }),
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ...teachers.map<DropdownMenuItem<String>>((teacher) {
                return DropdownMenuItem<String>(
                  value: teacher['id'] as String,
                  child: Text(
                    teacher['nama'] ?? teacher['name'] ?? 'Unknown',
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedTeacher = value ?? '';
                _selectedSubject = '';
                _filteredSubjectList = [];
              });
              if (value != null && value.isNotEmpty) {
                _filterSubjectsByTeacher(value);
              } else {
                setState(() {
                  _filteredSubjectList = widget.subjectList;
                });
              }
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.person,
                color: _getPrimaryColor(),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a teacher',
                  'id': 'Harap pilih guru',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectDropdown(
    List<dynamic> subjects,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Subject',
            'id': 'Mata Pelajaran',
          }),
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedSubject.isNotEmpty ? _selectedSubject : null,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Subject',
                    'id': 'Pilih Mata Pelajaran',
                  }),
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ...subjects.map<DropdownMenuItem<String>>((subject) {
                return DropdownMenuItem<String>(
                  value: subject['id'] as String,
                  child: Text(
                    subject['name'] ?? subject['nama'] ?? 'Unknown',
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }),
            ],
            onChanged: _isLoadingSubjects
                ? null
                : (value) {
                    setState(() {
                      _selectedSubject = value ?? '';
                    });
                  },
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.book, color: _getPrimaryColor(), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              suffixIcon: _isLoadingSubjects
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a subject',
                  'id': 'Harap pilih mata pelajaran',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildClassDropdown(
    List<dynamic> classes,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedClass.isNotEmpty ? _selectedClass : null,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Class',
                    'id': 'Pilih Kelas',
                  }),
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ...classes.map((classItem) {
                return DropdownMenuItem<String>(
                  value: classItem['id']?.toString() ?? '',
                  child: Text(
                    classItem['name'] ?? classItem['nama'] ?? 'Unknown',
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedClass = value ?? '';
              });
              if (_selectedHari.isNotEmpty &&
                  _selectedSemester.isNotEmpty &&
                  _selectedClass.isNotEmpty) {
                _filterAvailableJamPelajaran();
              }
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.school,
                color: _getPrimaryColor(),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a class',
                  'id': 'Harap pilih kelas',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayDropdown(
    List<dynamic> days,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({'en': 'Day', 'id': 'Hari'}),
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedHari.isNotEmpty ? _selectedHari : null,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Day',
                    'id': 'Pilih Hari',
                  }),
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ...days.map<DropdownMenuItem<String>>((day) {
                return DropdownMenuItem<String>(
                  value: day['id']?.toString() ?? '',
                  child: Text(
                    _translateDayName(
                      day['name'] ?? day['nama'] ?? 'Unknown',
                      languageProvider.currentLanguage,
                    ),
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedHari = value ?? '';
              });
              if (_selectedClass.isNotEmpty &&
                  _selectedSemester.isNotEmpty &&
                  _selectedHari.isNotEmpty) {
                _filterAvailableJamPelajaran();
              }
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.calendar_today,
                color: _getPrimaryColor(),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a day',
                  'id': 'Harap pilih hari',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSemesterDropdown(
    List<dynamic> semesters,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Semester',
            'id': 'Semester',
          }),
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedSemester.isNotEmpty
                ? _selectedSemester
                : null,
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Semester',
                    'id': 'Pilih Semester',
                  }),
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ...semesters.map<DropdownMenuItem<String>>((semester) {
                return DropdownMenuItem<String>(
                  value: semester['id']?.toString() ?? '',
                  child: Text(
                    semester['name'] ?? semester['nama'] ?? 'Unknown',
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }),
            ],
            onChanged: (value) {
              setState(() {
                _selectedSemester = value ?? '';
              });
              if (_selectedHari.isNotEmpty &&
                  _selectedClass.isNotEmpty &&
                  _selectedSemester.isNotEmpty) {
                _filterAvailableJamPelajaran();
              }
            },
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.grade,
                color: _getPrimaryColor(),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a semester',
                  'id': 'Harap pilih semester',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeachingHourDropdown(
    List<dynamic> teachingHours,
    LanguageProvider languageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Teaching Hour',
            'id': 'Jam Pelajaran',
          }),
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonFormField<String>(
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Teaching Hour',
                    'id': 'Pilih Jam Pelajaran',
                  }),
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ...() {
                final seenIds = <String>{};
                return teachingHours
                    .where((jam) {
                      final id = jam['id']?.toString() ?? '';
                      if (id.isEmpty || seenIds.contains(id)) {
                        return false;
                      }
                      seenIds.add(id);
                      return true;
                    })
                    .map<DropdownMenuItem<String>>((jam) {
                      final isAvailable =
                          jam['is_terpakai'] != 1 && jam['is_terpakai'] != true;
                      final jamKe = jam['hour_number'] ?? jam['jam_ke'] ?? '';
                      final jamMulai = _formatTimeForDropdown(
                        jam['start_time']?.toString() ??
                            jam['jam_mulai']?.toString(),
                      );
                      final jamSelesai = _formatTimeForDropdown(
                        jam['end_time']?.toString() ??
                            jam['jam_selesai']?.toString(),
                      );

                      return DropdownMenuItem<String>(
                        value: jam['id']?.toString() ?? '',
                        child: Opacity(
                          opacity: isAvailable ? 1.0 : 0.5,
                          child: Text(
                            isAvailable
                                ? '$jamKe ($jamMulai - $jamSelesai)'
                                : '$jamKe ($jamMulai - $jamSelesai) - Taken',
                            style: TextStyle(
                              fontSize: 14,
                              color: isAvailable ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    });
              }(),
            ],
            onChanged: _isLoadingJamPelajaran
                ? null
                : (value) {
                    setState(() {
                      _selectedJamPelajaran = value ?? '';
                    });
                  },
            initialValue:
                _selectedJamPelajaran.isNotEmpty &&
                    teachingHours.any(
                      (jam) =>
                          (jam['id']?.toString() ?? '') ==
                          _selectedJamPelajaran,
                    )
                ? _selectedJamPelajaran
                : null,
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.access_time,
                color: _getPrimaryColor(),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              suffixIcon: _isLoadingJamPelajaran
                  ? Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return languageProvider.getTranslatedText({
                  'en': 'Please select a teaching hour',
                  'id': 'Harap pilih jam pelajaran',
                });
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  void _saveSchedule() {
    if (_formKey.currentState!.validate()) {
      final scheduleData = {
        'teacher_id': _selectedTeacher,
        'subject_id': _selectedSubject,
        'class_id': _selectedClass,
        'day_id': _selectedHari,
        'semester_id': _selectedSemester,
        'academic_year': widget.academicYear,
        'lesson_hour_id': _selectedJamPelajaran,
      };

      Navigator.pop(context, scheduleData);
    }
  }
}
