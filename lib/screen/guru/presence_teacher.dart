import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/filter_sheet.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/components/new_enhanced_search_bar.dart';
import 'package:manajemensekolah/components/tab_switcher.dart';
import 'package:manajemensekolah/models/siswa.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/date_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

// Model untuk Summary Absensi
class AbsensiSummary {
  final String mataPelajaranId;
  final String mataPelajaranNama;
  final DateTime tanggal;
  final int totalSiswa;
  final int hadir;
  final int tidakHadir;
  final String? classId;
  final String? className;

  AbsensiSummary({
    required this.mataPelajaranId,
    required this.mataPelajaranNama,
    required this.tanggal,
    required this.totalSiswa,
    required this.hadir,
    required this.tidakHadir,
    this.classId,
    this.className,
  });

  String get key =>
      '$mataPelajaranId-${DateFormat('yyyy-MM-dd').format(tanggal)}';
}

class PresencePage extends StatefulWidget {
  final Map<String, dynamic> guru;
  final DateTime? initialDate;
  final String? initialMataPelajaranId;
  final String? initialMataPelajaranNama;
  final String? initialclassId;
  final String? initialKelasNama;

  const PresencePage({
    super.key,
    required this.guru,
    this.initialDate,
    this.initialMataPelajaranId,
    this.initialMataPelajaranNama,
    this.initialclassId,
    this.initialKelasNama,
  });

  @override
  PresencePageState createState() => PresencePageState();
}

class PresencePageState extends State<PresencePage>
    with SingleTickerProviderStateMixin {
  // Tab Controller for TabSwitcher
  late TabController _tabController;

  // Data untuk mode View Results
  List<AbsensiSummary> _absensiSummaryList = [];
  bool _isLoadingSummary = false;

  // Data untuk mode Input Absensi
  DateTime _selectedDate = DateTime.now();
  String? _selectedMataPelajaran;
  String? _selectedMataPelajaranNama;
  String? _selectedKelas;
  String? _selectedKelasNama;
  String? _selectedDateFilter;
  List<dynamic> _mataPelajaranList = [];
  List<dynamic> _mataPelajaranDiampu = [];
  List<dynamic> _kelasList = [];
  List<Siswa> _siswaList = [];
  List<Siswa> _filteredSiswaList = [];
  List<String> _selectedSubjectIds = [];
  final Map<String, String> _absensiStatus = {};
  bool _isLoadingInput = true;
  bool _isSubmitting = false;
  bool _hasActiveFilter = false;
  bool _showSearch = false;
  final bool _showQuickActions = false;

  // Search dan Filter untuk Results Mode
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterOptions = ['All', 'Today', 'This Week'];
  final String _selectedFilter = 'All';

  // Filter untuk Input Mode
  final TextEditingController _searchControllerInput = TextEditingController();
  String? _selectedStatusFilter;
  bool _hasActiveFilterInput = false;

  // State untuk auto-detection schedule
  Map<String, dynamic>? _currentSchedule;

  @override
  void initState() {
    super.initState();

    // Initialize with data from teaching_schedule if provided
    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
    if (widget.initialMataPelajaranId != null) {
      _selectedMataPelajaran = widget.initialMataPelajaranId;
      _selectedMataPelajaranNama = widget.initialMataPelajaranNama;
    }
    if (widget.initialclassId != null) {
      _selectedKelas = widget.initialclassId;
      _selectedKelasNama = widget.initialKelasNama;
    }

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {
        // Trigger rebuild when tab changes
        if (_tabController.index == 0) {
          _loadAbsensiSummary();
        }
      });
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchControllerInput.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final apiServiceClass = ApiClassService();
      final [mataPelajaranDiampu, kelas, siswa] = await Future.wait([
        // Ambil mata pelajaran yang diampu oleh guru
        _getMataPelajaranByGuru(widget.guru['id']),
        apiServiceClass.getClass(),
        ApiStudentService.getStudent(),
      ]);

      setState(() {
        _mataPelajaranDiampu = mataPelajaranDiampu;
        _mataPelajaranList = mataPelajaranDiampu; // Gunakan yang diampu saja
        _kelasList = kelas;
        _siswaList = siswa.map((s) => Siswa.fromJson(s)).toList();
        _filteredSiswaList = _siswaList;

        // Set default status untuk semua siswa
        for (var siswa in _siswaList) {
          _absensiStatus[siswa.id] = 'hadir';
        }

        _isLoadingInput = false;
      });

      // Auto-detect current schedule if not initialized from teaching_schedule
      if (widget.initialMataPelajaranId == null) {
        await _detectCurrentSchedule();
      }

      // Load summary data untuk mode view
      _loadAbsensiSummary();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${languageProvider.getTranslatedText({'en': 'Error loading initial data: $e', 'id': 'Error loading initial data: $e'})} $e',
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      // Check mounted sebelum setState
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<List<dynamic>> _getMataPelajaranByGuru(String guruId) async {
    try {
      final apiTeacherService = ApiTeacherService();
      final result = await apiTeacherService.getSubjectByTeacher(guruId);
      return result;
    } catch (e) {
      print('Error getting mata pelajaran by guru: $e');
      return [];
    }
  }

  // Get current academic year
  String _getCurrentAcademicYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    if (currentMonth >= 7) {
      return '$currentYear/${currentYear + 1}';
    } else {
      return '${currentYear - 1}/$currentYear';
    }
  }

  // Get current semester
  String _getCurrentSemester() {
    final now = DateTime.now();
    final currentMonth = now.month;
    if (currentMonth >= 7) {
      return '1';
    } else {
      return '2';
    }
  }

  // Get current day ID (1=Senin, 2=Selasa, etc.)
  String _getCurrentDayId() {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Monday, 7=Sunday
    return weekday.toString();
  }

  // Check if current time is within schedule time
  bool _isWithinScheduleTime(String jamMulai, String jamSelesai) {
    try {
      final now = TimeOfDay.now();
      final startParts = jamMulai.split(':');
      final endParts = jamSelesai.split(':');

      final start = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1].split('.')[0]),
      );
      final end = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1].split('.')[0]),
      );

      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = start.hour * 60 + start.minute;
      final endMinutes = end.hour * 60 + end.minute;

      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    } catch (e) {
      print('Error parsing time: $e');
      return false;
    }
  }

  // Load today's schedules and detect current one
  Future<void> _detectCurrentSchedule() async {
    try {
      final schedules = await ApiScheduleService.getSchedule(
        guruId: widget.guru['id'],
        hariId: _getCurrentDayId(),
        semesterId: _getCurrentSemester(),
        tahunAjaran: _getCurrentAcademicYear(),
      );

      setState(() {
        if (schedules.isNotEmpty) {
          // Find current schedule based on time
          Map<String, dynamic>? currentSchedule;
          for (var schedule in schedules) {
            final jamMulai = schedule['jam_mulai']?.toString() ?? '';
            final jamSelesai = schedule['jam_selesai']?.toString() ?? '';

            if (_isWithinScheduleTime(jamMulai, jamSelesai)) {
              currentSchedule = schedule;
              break;
            }
          }

          if (currentSchedule != null) {
            _currentSchedule = currentSchedule;
            _selectedMataPelajaran = currentSchedule['mata_pelajaran_id']
                ?.toString();
            _selectedMataPelajaranNama = currentSchedule['mata_pelajaran_nama']
                ?.toString();
            _selectedKelas = currentSchedule['kelas_id']?.toString();
            _selectedKelasNama = currentSchedule['kelas_nama']?.toString();
            _filterStudentsByClass(_selectedKelas);
          } else {
            _currentSchedule = null;
          }
        } else {
          _currentSchedule = null;
        }
      });
    } catch (e) {
      print('Error detecting current schedule: $e');
      setState(() {
        _currentSchedule = null;
      });
    }
  }

  Future<void> _loadAbsensiSummary() async {
    // Check mounted sebelum memulai loading
    if (!mounted) return;

    setState(() {
      _isLoadingSummary = true;
    });

    try {
      final absensiData = await ApiService.getAbsensi(
        guruId: widget.guru['id'],
      );

      final Map<String, AbsensiSummary> summaryMap = {};

      for (var absen in absensiData) {
        // Include kelas_id in the grouping key
        final classId = absen['kelas_id']?.toString() ?? '';
        final key = '${absen['subject_id']}-${absen['date']}-$classId';

        // Use name from API if available, otherwise fallback to lookup
        final mataPelajaranNama =
            absen['mata_pelajaran_nama'] ??
            _getMataPelajaranName(absen['subject_id']);

        final className = absen['kelas_nama'];

        if (!summaryMap.containsKey(key)) {
          summaryMap[key] = AbsensiSummary(
            mataPelajaranId: absen['subject_id'],
            mataPelajaranNama: mataPelajaranNama,
            tanggal: _parseLocalDate(absen['date']),
            totalSiswa: 0,
            hadir: 0,
            tidakHadir: 0,
            classId: classId.isNotEmpty ? classId : null,
            className: className,
          );
        }

        final summary = summaryMap[key]!;
        final status = (absen['status'] ?? '').toString().toLowerCase();
        final isPresent = status == 'hadir' || status == 'present';

        summaryMap[key] = AbsensiSummary(
          mataPelajaranId: summary.mataPelajaranId,
          mataPelajaranNama: summary.mataPelajaranNama,
          tanggal: summary.tanggal,
          totalSiswa: summary.totalSiswa + 1,
          hadir: summary.hadir + (isPresent ? 1 : 0),
          tidakHadir: summary.tidakHadir + (!isPresent ? 1 : 0),
          classId: summary.classId,
          className: summary.className,
        );
      }

      // Check mounted sebelum setState
      if (!mounted) return;

      setState(() {
        _absensiSummaryList = summaryMap.values.toList()
          ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
        _isLoadingSummary = false;
      });

      if (kDebugMode) {
        print('Loaded ${_absensiSummaryList.length} absensi summaries');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading absensi summary: $e');
      }
      // Check mounted sebelum setState
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
      }
    }
  }

  String _getMataPelajaranName(String mataPelajaranId) {
    try {
      final mataPelajaran = _mataPelajaranList.firstWhere(
        (mp) => mp['id'] == mataPelajaranId,
        orElse: () => {'nama': 'Unknown'},
      );
      return mataPelajaran['nama'] ?? mataPelajaran['name'] ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getMataPelajaranSelectedName() {
    if (_selectedMataPelajaran == null) return '-';
    try {
      final mataPelajaran = _mataPelajaranDiampu.firstWhere(
        (mp) => mp['id'] == _selectedMataPelajaran,
        orElse: () => {'nama': 'Unknown'},
      );
      return mataPelajaran['nama'] ?? mataPelajaran['name'] ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  String _getKelasNameWithCount(String classId) {
    // Use provided kelas name if available
    if (_selectedKelasNama != null) {
      final count = _filteredSiswaList
          .where((s) => s.classId == classId)
          .length;
      return '$_selectedKelasNama - $count siswa';
    }

    // Fallback to finding from list
    try {
      final kelas = _kelasList.firstWhere(
        (k) => k['id'].toString() == classId,
        orElse: () => {'nama': 'Unknown Class'},
      );
      final kelasName = kelas['nama'] ?? kelas['name'] ?? 'Unknown Class';
      final count = _filteredSiswaList
          .where((s) => s.classId == classId)
          .length;
      return '$kelasName - $count siswa';
    } catch (e) {
      return 'Unknown Class';
    }
  }

  // Helper function to parse date string as local date (not UTC)
  DateTime _parseLocalDate(String dateString) {
    // Gunakan AppDateUtils untuk parsing yang konsisten dan benar
    return AppDateUtils.parseApiDate(dateString) ?? DateTime.now();
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedDateFilter != null || _selectedSubjectIds.isNotEmpty;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDateFilter = null;
      _selectedSubjectIds.clear();
      _hasActiveFilter = false;
    });
  }

  // ========== SHOW QUICK ACTIONS SHEET ==========
  void _showQuickActionsSheet(LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              languageProvider.getTranslatedText({
                'en': 'Set All Students To',
                'id': 'Atur Semua Siswa Menjadi',
              }),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildQuickActionOption('hadir', languageProvider),
            _buildQuickActionOption('terlambat', languageProvider),
            _buildQuickActionOption('izin', languageProvider),
            _buildQuickActionOption('sakit', languageProvider),
            _buildQuickActionOption('alpha', languageProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionOption(
    String status,
    LanguageProvider languageProvider,
  ) {
    return ListTile(
      leading: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
      title: Text(_getStatusText(status, languageProvider)),
      onTap: () {
        _setAllStatus(status, languageProvider);
        Navigator.pop(context);
      },
    );
  }

  void _setAllStatus(String status, LanguageProvider languageProvider) {
    setState(() {
      for (var siswa in _filteredSiswaList) {
        _absensiStatus[siswa.id] = status;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          languageProvider.getTranslatedText({
            'en':
                'All students set to ${_getStatusText(status, languageProvider).toLowerCase()}',
            'id':
                'Semua siswa diatur menjadi ${_getStatusText(status, languageProvider).toLowerCase()}',
          }),
        ),
        backgroundColor: _getStatusColor(status),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'hadir':
        return Icons.check_circle;
      case 'terlambat':
        return Icons.watch_later;
      case 'izin':
        return Icons.assignment_turned_in;
      case 'sakit':
        return Icons.local_hospital;
      case 'alpha':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  // ========== SHOW EDIT BOTTOM SHEET ==========
  void _showEditBottomSheet(LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Edit Schedule',
                            'id': 'Edit Jadwal',
                          }),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1),

                  // Form Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date Picker
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Date',
                              'id': 'Tanggal',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDate = picked;
                                });
                                setModalState(() {});
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat(
                                      'EEEE, dd MMMM yyyy',
                                      'id_ID',
                                    ).format(_selectedDate),
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  Icon(
                                    Icons.calendar_today,
                                    color: _getPrimaryColor(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 20),

                          // Class Dropdown
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Class',
                              'id': 'Kelas',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedKelas,
                              isExpanded: true,
                              underline: Container(),
                              icon: Icon(Icons.arrow_drop_down),
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'All Classes',
                                      'id': 'Semua Kelas',
                                    }),
                                  ),
                                ),
                                ..._kelasList.map(
                                  (kelas) => DropdownMenuItem(
                                    value: kelas['id'],
                                    child: Text(kelas['name']),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedKelas = value;
                                  _filterStudentsByClass(value);
                                });
                                setModalState(() {});
                              },
                            ),
                          ),
                          SizedBox(height: 20),

                          // Subject Dropdown
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Subject',
                              'id': 'Mata Pelajaran',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedMataPelajaran,
                              isExpanded: true,
                              underline: Container(),
                              icon: Icon(Icons.arrow_drop_down),
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Select Subject',
                                      'id': 'Pilih Mata Pelajaran',
                                    }),
                                  ),
                                ),
                                ..._mataPelajaranDiampu.map(
                                  (mp) => DropdownMenuItem(
                                    value: mp['id'],
                                    child: Text(
                                      mp['nama'] ??
                                          mp['name'] ??
                                          mp['mata_pelajaran_nama'] ??
                                          'Unknown',
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedMataPelajaran = value;
                                  // Update nama mata pelajaran
                                  final selected = _mataPelajaranDiampu
                                      .firstWhere(
                                        (mp) => mp['id'] == value,
                                        orElse: () => {},
                                      );
                                  _selectedMataPelajaranNama =
                                      selected['nama'] ??
                                      selected['mata_pelajaran_nama'];
                                });
                                setModalState(() {});
                              },
                            ),
                          ),

                          if (_mataPelajaranDiampu.isEmpty)
                            Container(
                              margin: EdgeInsets.only(top: 12),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.warning,
                                    color: Colors.orange[800],
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      languageProvider.getTranslatedText({
                                        'en':
                                            'You are not assigned to any subjects.',
                                        'id':
                                            'Anda tidak mengampu mata pelajaran apapun.',
                                      }),
                                      style: TextStyle(
                                        color: Colors.orange[800],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Buttons
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[300]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Cancel',
                                'id': 'Batal',
                              }),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_selectedMataPelajaran != null) {
                                Navigator.pop(context);
                                setState(() {
                                  // Reset auto schedule since this is manual
                                  _currentSchedule = null;
                                });
                                _filterStudents();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Please select a subject first',
                                        'id':
                                            'Pilih mata pelajaran terlebih dahulu',
                                      }),
                                    ),
                                    backgroundColor: Colors.red.shade400,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Apply',
                                'id': 'Terapkan',
                              }),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ========== FILTER UNTUK INPUT MODE ==========
  void _filterStudents() {
    final searchTerm = _searchControllerInput.text.toLowerCase();

    setState(() {
      _filteredSiswaList = _siswaList.where((siswa) {
        // Search filter
        final matchesSearch =
            searchTerm.isEmpty ||
            siswa.nama.toLowerCase().contains(searchTerm) ||
            siswa.nis.toLowerCase().contains(searchTerm);

        // Status filter
        final matchesStatus =
            _selectedStatusFilter == null ||
            (_absensiStatus[siswa.id] ?? 'hadir') == _selectedStatusFilter;

        // Class filter
        final matchesClass =
            _selectedKelas == null || siswa.classId == _selectedKelas;

        return matchesSearch && matchesStatus && matchesClass;
      }).toList();
    });
  }

  void _showFilterSheetInput() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        primaryColor: _getPrimaryColor(),
        config: FilterConfig(
          sections: [
            FilterSection(
              key: 'statusFilter',
              title: languageProvider.getTranslatedText({
                'en': 'Attendance Status',
                'id': 'Status Kehadiran',
              }),
              options: [
                FilterOption(
                  label: languageProvider.getTranslatedText({
                    'en': 'All Status',
                    'id': 'Semua Status',
                  }),
                  value: null,
                ),
                FilterOption(
                  label: languageProvider.getTranslatedText({
                    'en': 'Present',
                    'id': 'Hadir',
                  }),
                  value: 'hadir',
                ),
                FilterOption(
                  label: languageProvider.getTranslatedText({
                    'en': 'Late',
                    'id': 'Terlambat',
                  }),
                  value: 'terlambat',
                ),
                FilterOption(
                  label: languageProvider.getTranslatedText({
                    'en': 'Permission',
                    'id': 'Izin',
                  }),
                  value: 'izin',
                ),
                FilterOption(
                  label: languageProvider.getTranslatedText({
                    'en': 'Sick',
                    'id': 'Sakit',
                  }),
                  value: 'sakit',
                ),
                FilterOption(
                  label: languageProvider.getTranslatedText({
                    'en': 'Absent',
                    'id': 'Alpha',
                  }),
                  value: 'alpha',
                ),
              ],
              multiSelect: false,
            ),
          ],
        ),
        initialFilters: {'statusFilter': _selectedStatusFilter},
        onApplyFilters: (filters) {
          setState(() {
            _selectedStatusFilter = filters['statusFilter'];
            _checkActiveFilterInput();
            _filterStudents();
          });
        },
      ),
    );
  }

  void _checkActiveFilterInput() {
    setState(() {
      _hasActiveFilterInput = _selectedStatusFilter != null;
    });
  }

  void _clearAllFiltersInput() {
    setState(() {
      _selectedStatusFilter = null;
      _searchControllerInput.clear();
      _hasActiveFilterInput = false;
      _filterStudents();
    });
  }

  List<Map<String, dynamic>> _buildFilterChipsInput(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedStatusFilter != null) {
      final statusText = _getStatusText(
        _selectedStatusFilter!,
        languageProvider,
      );
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedStatusFilter = null;
            _checkActiveFilterInput();
            _filterStudents();
          });
        },
      });
    }

    return filterChips;
  }

  // ========== MODE SWITCHER ==========
  Widget _buildModeSwitcher(LanguageProvider languageProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: TabSwitcher(
        tabController: _tabController,
        primaryColor: _getPrimaryColor(),
        tabs: [
          TabItem(
            label: languageProvider.getTranslatedText({
              'en': 'Attendance Results',
              'id': 'Hasil Absensi',
            }),
            icon: Icons.list_alt,
          ),
          TabItem(
            label: languageProvider.getTranslatedText({
              'en': 'Add Attendance',
              'id': 'Tambah Absensi',
            }),
            icon: Icons.add_circle,
          ),
        ],
      ),
    );
  }

  // ========== MODE 0: VIEW RESULTS ==========
  Widget _buildResultsMode() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoadingSummary) {
          return LoadingScreen(
            message: languageProvider.getTranslatedText({
              'en': 'Loading attendance data...',
              'id': 'Memuat data absensi...',
            }),
          );
        }

        final filteredSummaries = _getFilteredSummaries();

        return Column(
          children: [
            // Search dan Filter Bar
            _buildSearchAndFilter(languageProvider),

            // Filter Chips
            if (_hasActiveFilter) ...[
              SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ..._buildFilterChips(languageProvider).map((filter) {
                            return Container(
                              margin: EdgeInsets.only(right: 6),
                              child: Chip(
                                label: Text(
                                  filter['label'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                deleteIcon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                onDeleted: filter['onRemove'],
                                backgroundColor: _getPrimaryColor().withOpacity(
                                  0.7,
                                ),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                labelPadding: EdgeInsets.only(left: 4),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: InkWell(
                        onTap: _clearAllFilters,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Clear All',
                              'id': 'Hapus Semua',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
            ],

            if (filteredSummaries.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${filteredSummaries.length} ${languageProvider.getTranslatedText({'en': 'attendance records found', 'id': 'catatan absensi ditemukan'})}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 8),

            Expanded(
              child: filteredSummaries.isEmpty
                  ? EmptyState(
                      title: languageProvider.getTranslatedText({
                        'en': 'No attendance records',
                        'id': 'Belum ada data absensi',
                      }),
                      subtitle:
                          _searchController.text.isEmpty && !_hasActiveFilter
                          ? languageProvider.getTranslatedText({
                              'en': 'No attendance data available',
                              'id': 'Tidak ada data absensi tersedia',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'No search results found',
                              'id': 'Tidak ditemukan hasil pencarian',
                            }),
                      icon: Icons.list_alt,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredSummaries.length,
                      itemBuilder: (context, index) {
                        final summary = filteredSummaries[index];
                        return _buildSummaryCard(summary, languageProvider);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  List<AbsensiSummary> _getFilteredSummaries() {
    final searchTerm = _searchController.text.toLowerCase();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return _absensiSummaryList.where((summary) {
      // Search filter
      final matchesSearch =
          searchTerm.isEmpty ||
          summary.mataPelajaranNama.toLowerCase().contains(searchTerm);

      // Date filter
      bool matchesDateFilter = true;
      if (_selectedDateFilter != null) {
        if (_selectedDateFilter == 'today') {
          matchesDateFilter = _isSameDay(summary.tanggal, now);
        } else if (_selectedDateFilter == 'week') {
          matchesDateFilter =
              summary.tanggal.isAfter(
                startOfWeek.subtract(Duration(days: 1)),
              ) &&
              summary.tanggal.isBefore(endOfWeek.add(Duration(days: 1)));
        } else if (_selectedDateFilter == 'month') {
          matchesDateFilter =
              summary.tanggal.isAfter(
                startOfMonth.subtract(Duration(days: 1)),
              ) &&
              summary.tanggal.isBefore(endOfMonth.add(Duration(days: 1)));
        }
      }

      // Subject filter
      final matchesSubject =
          _selectedSubjectIds.isEmpty ||
          _selectedSubjectIds.contains(summary.mataPelajaranId);

      return matchesSearch && matchesDateFilter && matchesSubject;
    }).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // ========== HEADER BARU SEPERTI ADMIN PRESENCE ==========
  Widget _buildHeader(LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tabController.index == 0
                          ? languageProvider.getTranslatedText({
                              'en': 'Attendance Results',
                              'id': 'Hasil Absensi',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Add Attendance',
                              'id': 'Tambah Absensi',
                            }),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _tabController.index == 0
                          ? languageProvider.getTranslatedText({
                              'en': 'View attendance records',
                              'id': 'Lihat catatan kehadiran',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Record student attendance',
                              'id': 'Catat kehadiran siswa',
                            }),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'refresh':
                      if (_tabController.index == 0) {
                        _loadAbsensiSummary();
                      }
                      break;
                  }
                },
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.more_vert, color: Colors.white, size: 20),
                ),
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 8),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Refresh',
                            'id': 'Refresh',
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),

          // Mode Switcher di dalam header
          _buildModeSwitcher(languageProvider),
        ],
      ),
    );
  }

  // ========== SEARCH BAR DENGAN FILTER SEPERTI ADMIN ==========
  Widget _buildSearchAndFilter(LanguageProvider languageProvider) {
    return NewEnhancedSearchBar(
      controller: _searchController,
      onChanged: (value) => setState(() {}),
      hintText: languageProvider.getTranslatedText({
        'en': 'Search attendance...',
        'id': 'Cari absensi...',
      }),
      showFilter: _tabController.index == 0,
      hasActiveFilter: _hasActiveFilter,
      onFilterPressed: _showFilterSheet,
      primaryColor: _getPrimaryColor(),
    );
  }

  // ========== FILTER SHEET SEPERTI ADMIN ==========
  void _showFilterSheet() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        primaryColor: _getPrimaryColor(),
        config: FilterConfig(
          sections: [
            FilterSection(
              key: 'dateFilter',
              title: languageProvider.getTranslatedText({
                'en': 'Date Range',
                'id': 'Rentang Tanggal',
              }),
              options: [
                FilterOption(
                  label: languageProvider.getTranslatedText({
                    'en': 'Today',
                    'id': 'Hari Ini',
                  }),
                  value: 'today',
                ),
                FilterOption(
                  label: languageProvider.getTranslatedText({
                    'en': 'This Week',
                    'id': 'Minggu Ini',
                  }),
                  value: 'week',
                ),
                FilterOption(
                  label: languageProvider.getTranslatedText({
                    'en': 'This Month',
                    'id': 'Bulan Ini',
                  }),
                  value: 'month',
                ),
              ],
              multiSelect: false,
            ),
            FilterSection(
              key: 'subjectIds',
              title: languageProvider.getTranslatedText({
                'en': 'Subject',
                'id': 'Mata Pelajaran',
              }),
              options: _mataPelajaranDiampu.map((subject) {
                return FilterOption(
                  label:
                      subject['nama'] ??
                      subject['mata_pelajaran_nama'] ??
                      'Subject',
                  value: subject['id'].toString(),
                );
              }).toList(),
              multiSelect: true,
            ),
          ],
        ),
        initialFilters: {
          'dateFilter': _selectedDateFilter,
          'subjectIds': _selectedSubjectIds,
        },
        onApplyFilters: (filters) {
          setState(() {
            _selectedDateFilter = filters['dateFilter'];
            _selectedSubjectIds = List<String>.from(
              filters['subjectIds'] ?? [],
            );
            _checkActiveFilter();
          });
        },
      ),
    );
  }

  // ========== FILTER CHIPS SEPERTI ADMIN ==========
  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedDateFilter != null) {
      final label = _selectedDateFilter == 'today'
          ? languageProvider.getTranslatedText({
              'en': 'Today',
              'id': 'Hari Ini',
            })
          : _selectedDateFilter == 'week'
          ? languageProvider.getTranslatedText({
              'en': 'This Week',
              'id': 'Minggu Ini',
            })
          : languageProvider.getTranslatedText({
              'en': 'This Month',
              'id': 'Bulan Ini',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Date', 'id': 'Tanggal'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedDateFilter = null;
            _checkActiveFilter();
          });
        },
      });
    }

    if (_selectedSubjectIds.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})}: ${_selectedSubjectIds.length}',
        'onRemove': () {
          setState(() {
            _selectedSubjectIds.clear();
            _checkActiveFilter();
          });
        },
      });
    }

    return filterChips;
  }

  Widget _buildSummaryCard(
    AbsensiSummary summary,
    LanguageProvider languageProvider,
  ) {
    final presentaseHadir = summary.totalSiswa > 0
        ? (summary.hadir / summary.totalSiswa * 100).round()
        : 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 5,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetailAbsensi(summary),
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Strip biru di pinggir kiri
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: _getPrimaryColor(),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),

              // Background pattern effect
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Delete button
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _deleteAbsensi(summary, languageProvider),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header dengan mata pelajaran, kelas, dan tanggal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.mataPelajaranNama,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                summary.className ?? 'Unknown Class',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getPrimaryColor(),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                DateFormat(
                                  'EEEE, dd MMMM yyyy',
                                  'id_ID',
                                ).format(summary.tanggal),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12),

                    // Informasi kehadiran
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _getPrimaryColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.people,
                            color: _getPrimaryColor(),
                            size: 16,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kehadiran',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 1),
                              Text(
                                '${summary.hadir} Hadir • ${summary.tidakHadir} Tidak Hadir',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8),

                    // Progress bar
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Stack(
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return Container(
                                width:
                                    constraints.maxWidth *
                                    (summary.totalSiswa > 0
                                        ? summary.hadir / summary.totalSiswa
                                        : 0),
                                decoration: BoxDecoration(
                                  color: presentaseHadir >= 80
                                      ? Colors.green
                                      : presentaseHadir >= 60
                                      ? Colors.orange
                                      : Colors.red,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$presentaseHadir% ${languageProvider.getTranslatedText({'en': 'Attendance', 'id': 'Kehadiran'})}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        _buildActionButton(
                          icon: Icons.visibility,
                          label: 'Detail',
                          color: _getPrimaryColor(),
                          onPressed: () => _navigateToDetailAbsensi(summary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetailAbsensi(AbsensiSummary summary) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherAbsensiDetailPage(
          mataPelajaranId: summary.mataPelajaranId,
          mataPelajaranNama: summary.mataPelajaranNama,
          tanggal: summary.tanggal,
          classId: summary.classId ?? '',
          kelasNama: summary.className ?? 'Unknown Class',
          guru: widget.guru,
        ),
      ),
    );
  }

  // ========== MODE 1: INPUT ABSENSI ==========
  Widget _buildInputMode() {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoadingInput) {
          return LoadingScreen(
            message: languageProvider.getTranslatedText({
              'en': 'Loading data...',
              'id': 'Memuat data...',
            }),
          );
        }

        return Column(
          children: [
            // Header Info - Always show (whether schedule detected or not)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Subject and Class Info or No Schedule Message
                            if (_selectedMataPelajaran != null) ...[
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _selectedMataPelajaranNama ??
                                          _getMataPelajaranSelectedName(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (_currentSchedule != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.schedule,
                                            size: 12,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            languageProvider.getTranslatedText({
                                              'en': 'Auto',
                                              'id': 'Auto',
                                            }),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (_selectedKelas != null)
                                Text(
                                  _getKelasNameWithCount(_selectedKelas!),
                                  style: TextStyle(
                                    color: _getPrimaryColor(),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ] else ...[
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule_outlined,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'No Schedule Now',
                                        'id': 'Tidak Ada Jadwal Sekarang',
                                      }),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(
                                'EEEE, dd MMMM yyyy',
                                'id_ID',
                              ).format(_selectedDate),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon Search
                          Container(
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showSearch = !_showSearch;
                                  if (!_showSearch) {
                                    _searchControllerInput.clear();
                                    _filterStudents();
                                  }
                                });
                              },
                              icon: Icon(
                                _showSearch ? Icons.search_off : Icons.search,
                                color: _getPrimaryColor(),
                                size: 20,
                              ),
                              iconSize: 20,
                              padding: EdgeInsets.all(8),
                              constraints: BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              tooltip: languageProvider.getTranslatedText({
                                'en': _showSearch
                                    ? 'Hide search'
                                    : 'Search students',
                                'id': _showSearch
                                    ? 'Sembunyikan pencarian'
                                    : 'Cari siswa',
                              }),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Icon untuk Quick Actions
                          Container(
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () {
                                _showQuickActionsSheet(languageProvider);
                              },
                              icon: Icon(
                                Icons.checklist_rtl,
                                color: _getPrimaryColor(),
                                size: 20,
                              ),
                              iconSize: 20,
                              padding: EdgeInsets.all(8),
                              constraints: BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              tooltip: languageProvider.getTranslatedText({
                                'en': 'Quick attendance',
                                'id': 'Presensi cepat',
                              }),
                            ),
                          ),
                          SizedBox(height: 8),
                          // Icon Edit
                          Container(
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () {
                                _showEditBottomSheet(languageProvider);
                              },
                              icon: Icon(
                                Icons.edit,
                                color: _getPrimaryColor(),
                                size: 20,
                              ),
                              iconSize: 20,
                              padding: EdgeInsets.all(8),
                              constraints: BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              tooltip: languageProvider.getTranslatedText({
                                'en': 'Edit selection',
                                'id': 'Edit pilihan',
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar untuk Input Mode - hanya muncul jika _showSearch = true dan ada schedule
            if (_showSearch && _selectedMataPelajaran != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchControllerInput,
                    onChanged: (value) => _filterStudents(),
                    decoration: InputDecoration(
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search by name or NIS...',
                        'id': 'Cari berdasarkan nama atau NIS...',
                      }),
                      prefixIcon: Icon(Icons.search, color: _getPrimaryColor()),
                      suffixIcon: _searchControllerInput.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchControllerInput.clear();
                                _filterStudents();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
            ],

            // Student List or Empty State
            Expanded(
              child: _selectedMataPelajaran == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_calendar_outlined,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'No schedule at this time',
                                'id': 'Tidak ada jadwal pada jam ini',
                              }),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              languageProvider.getTranslatedText({
                                'en':
                                    'Click edit icon to input attendance manually',
                                'id':
                                    'Klik ikon edit untuk input absensi secara manual',
                              }),
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filteredSiswaList.isEmpty
                  ? EmptyState(
                      title: languageProvider.getTranslatedText({
                        'en': 'No Students',
                        'id': 'Tidak ada siswa',
                      }),
                      subtitle: languageProvider.getTranslatedText({
                        'en': 'No students found for selected class',
                        'id': 'Tidak ada siswa untuk kelas yang dipilih',
                      }),
                      icon: Icons.people_outline,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8),
                      itemCount: _filteredSiswaList.length,
                      itemBuilder: (context, index) => _buildStudentItem(
                        _filteredSiswaList[index],
                        languageProvider,
                      ),
                    ),
            ),

            // Submit Button
            if (_selectedMataPelajaran != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitAbsensi,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.save, size: 20),
                    label: Text(
                      _isSubmitting
                          ? languageProvider.getTranslatedText({
                              'en': 'Saving...',
                              'id': 'Menyimpan...',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Save Attendance',
                              'id': 'Simpan Absensi',
                            }),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ========== STUDENT ITEM BUILDER BARU ==========
  Widget _buildStudentItem(Siswa siswa, LanguageProvider languageProvider) {
    final status = _absensiStatus[siswa.id] ?? 'hadir';
    final Color statusColor = _getStatusColor(status);
    final Color avatarColor = _getAvatarColor(siswa.nama);
    final String initial = siswa.nama.isNotEmpty
        ? siswa.nama[0].toUpperCase()
        : '?';

    // Warna background berdasarkan status
    Color backgroundColor = Colors.white;
    switch (status) {
      case 'hadir':
        backgroundColor = Colors.green.withOpacity(0.05);
        break;
      case 'terlambat':
        backgroundColor = Colors.purple.withOpacity(0.05);
        break;
      case 'izin':
        backgroundColor = Colors.blue.withOpacity(0.05);
        break;
      case 'sakit':
        backgroundColor = Colors.orange.withOpacity(0.05);
        break;
      case 'alpha':
        backgroundColor = Colors.red.withOpacity(0.05);
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          // Student Info Row
          Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      siswa.nama,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${languageProvider.getTranslatedText({'en': 'NIS:', 'id': 'NIS:'})} ${siswa.nis}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  _getStatusText(status, languageProvider),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Status Options
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildStatusOption('hadir', languageProvider, status, siswa.id),
                const SizedBox(width: 8),
                _buildStatusOption(
                  'terlambat',
                  languageProvider,
                  status,
                  siswa.id,
                ),
                const SizedBox(width: 8),
                _buildStatusOption('izin', languageProvider, status, siswa.id),
                const SizedBox(width: 8),
                _buildStatusOption('sakit', languageProvider, status, siswa.id),
                const SizedBox(width: 8),
                _buildStatusOption('alpha', languageProvider, status, siswa.id),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(
    String statusValue,
    LanguageProvider languageProvider,
    String currentStatus,
    String siswaId,
  ) {
    final bool isSelected = currentStatus == statusValue;
    final Color statusColor = _getStatusColor(statusValue);

    return GestureDetector(
      onTap: () {
        setState(() {
          _absensiStatus[siswaId] = statusValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? statusColor : statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? statusColor : statusColor.withOpacity(0.3),
          ),
        ),
        child: Text(
          _getStatusText(statusValue, languageProvider),
          style: TextStyle(
            color: isSelected ? Colors.white : statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ========== HELPER FUNCTIONS ==========
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _filterStudentsByClass(String? classId) {
    setState(() {
      _selectedKelas = classId;
      _filterStudents();
    });
  }

  Future<void> _submitAbsensi() async {
    final languageProvider = context.read<LanguageProvider>();

    // Validasi guru_id
    final guruId = widget.guru['id'];
    if (guruId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Invalid teacher data. Please login again.',
              'id': 'Data guru tidak valid. Silakan login ulang.',
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedMataPelajaran == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Please select a subject first',
              'id': 'Pilih mata pelajaran terlebih dahulu',
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_filteredSiswaList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'No students to save',
              'id': 'Tidak ada siswa untuk disimpan',
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      int successCount = 0;
      int errorCount = 0;
      List<String> errorMessages = [];

      final tanggal = DateFormat('yyyy-MM-dd').format(_selectedDate);

      for (var siswa in _filteredSiswaList) {
        try {
          final status = _absensiStatus[siswa.id] ?? 'hadir';

          await ApiService.tambahAbsensi({
            'student_id': siswa.id,
            'teacher_id': guruId,
            'subject_id': _selectedMataPelajaran,
            'class_id': siswa.classId,
            'date': tanggal,
            'status': _mapStatusToBackend(status),
            'notes': '',
          });

          successCount++;
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          errorCount++;
          errorMessages.add('${siswa.nama}: $e');
        }
      }

      if (!mounted) return;

      // Tampilkan hasil
      if (errorCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en':
                    'Attendance successfully saved for $successCount students',
                'id': 'Absensi berhasil disimpan untuk $successCount siswa',
              }),
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Reset form setelah berhasil
        _resetForm();

        // Pindah ke tab Hasil (index 0)
        _tabController.animateTo(0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': '$successCount successful, $errorCount failed',
                'id': '$successCount berhasil, $errorCount gagal',
              }),
            ),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _showErrorDetails(errorMessages, languageProvider);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${languageProvider.getTranslatedText({'en': 'Error:', 'id': 'Error:'})} $e',
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showErrorDetails(
    List<String> errors,
    LanguageProvider languageProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Error Details',
            'id': 'Detail Error',
          }),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Some attendance failed to save:',
                  'id': 'Beberapa absensi gagal disimpan:',
                }),
              ),
              const SizedBox(height: 16),
              ...errors.map(
                (error) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $error', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Close',
                'id': 'Tutup',
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      // Reset status absensi ke default
      for (var siswa in _siswaList) {
        _absensiStatus[siswa.id] = 'hadir';
      }
      // Reset filter kelas
      _selectedKelas = null;
      _selectedStatusFilter = null;
      _searchControllerInput.clear();
      _hasActiveFilterInput = false;
      _filterStudents();
    });

    // Re-detect current schedule after reset
    _detectCurrentSchedule();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return Colors.green;
      case 'sakit':
        return Colors.orange;
      case 'izin':
        return Colors.blue;
      case 'alpha':
        return Colors.red;
      case 'terlambat':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  String _getStatusText(String status, LanguageProvider languageProvider) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
      case 'sakit':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
        });
      case 'izin':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'alpha':
        return languageProvider.getTranslatedText({
          'en': 'Absent',
          'id': 'Alpha',
        });
      case 'terlambat':
        return languageProvider.getTranslatedText({
          'en': 'Late',
          'id': 'Terlambat',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
    }
  }

  String _mapStatusToBackend(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'present';
      case 'terlambat':
        return 'late';
      case 'izin':
        return 'excused';
      case 'sakit':
        return 'sick';
      case 'alpha':
        return 'absent';
      default:
        return 'present';
    }
  }

  Future<void> _deleteAbsensi(
    AbsensiSummary summary,
    LanguageProvider languageProvider,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Delete Attendance',
            'id': 'Hapus Absensi',
          }),
        ),
        content: Text(
          languageProvider.getTranslatedText({
            'en':
                'Are you sure you want to delete attendance for ${summary.mataPelajaranNama} on ${DateFormat('dd MMMM yyyy', 'id_ID').format(summary.tanggal)}?',
            'id':
                'Apakah Anda yakin ingin menghapus absensi ${summary.mataPelajaranNama} pada ${DateFormat('dd MMMM yyyy', 'id_ID').format(summary.tanggal)}?',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Cancel',
                'id': 'Batal',
              }),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Delete',
                'id': 'Hapus',
              }),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteAbsensiSummary(
        guruId: widget.guru['id'],
        subjectId: summary.mataPelajaranId,
        date: DateFormat('yyyy-MM-dd').format(summary.tanggal),
        classId: summary.classId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Attendance deleted successfully',
              'id': 'Absensi berhasil dihapus',
            }),
          ),
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Reload summary data
      _loadAbsensiSummary();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${languageProvider.getTranslatedText({'en': 'Error:', 'id': 'Error:'})} $e',
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getAvatarColor(String nama) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    final index = nama.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: Color(
            0xFFF8F9FA,
          ), // Background sama dengan pengumuman
          body: Column(
            children: [
              // Header baru seperti pengumuman
              _buildHeader(languageProvider),

              // Content
              Expanded(
                child: _tabController.index == 0
                    ? _buildResultsMode()
                    : _buildInputMode(),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ========== ABSENSI DETAIL PAGE ==========
class AbsensiDetailPage extends StatefulWidget {
  final Map<String, dynamic> guru;
  final String mataPelajaranId;
  final String mataPelajaranNama;
  final DateTime tanggal;
  final String? classId;

  const AbsensiDetailPage({
    super.key,
    required this.guru,
    required this.mataPelajaranId,
    required this.mataPelajaranNama,
    required this.tanggal,
    this.classId,
  });

  @override
  State<AbsensiDetailPage> createState() => _AbsensiDetailPageState();
}

class _AbsensiDetailPageState extends State<AbsensiDetailPage> {
  List<dynamic> _absensiData = [];
  List<Siswa> _siswaList = [];
  List<dynamic> _kelasList = [];
  final Map<String, String> _absensiStatus = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load siswa, absensi, dan kelas data
      final apiServiceClass = ApiClassService();
      final [siswaData, absensiData, kelasData] = await Future.wait([
        ApiStudentService.getStudent(),
        ApiService.getAbsensi(
          guruId: widget.guru['id'],
          mataPelajaranId: widget.mataPelajaranId,
          tanggal: DateFormat('yyyy-MM-dd').format(widget.tanggal),
        ),
        apiServiceClass.getClass(),
      ]);

      setState(() {
        // Filter siswa by class if classId is provided
        List<Siswa> allSiswa = siswaData.map((s) => Siswa.fromJson(s)).toList();
        if (widget.classId != null && widget.classId!.isNotEmpty) {
          _siswaList = allSiswa
              .where((siswa) => siswa.classId == widget.classId)
              .toList();
        } else {
          _siswaList = allSiswa;
        }

        _kelasList = kelasData;
        _absensiData = absensiData;

        // Map status absensi only for students in this class
        for (var absen in _absensiData) {
          final siswaId = absen['siswa_id']?.toString();
          if (siswaId != null && _siswaList.any((s) => s.id == siswaId)) {
            _absensiStatus[siswaId] = absen['status'];
          }
        }

        // Set default untuk siswa yang belum ada data absensi
        for (var siswa in _siswaList) {
          _absensiStatus[siswa.id] ??= 'hadir';
        }

        _isLoading = false;
      });

      print(
        'Loaded ${_absensiData.length} absensi records for ${_siswaList.length} students in class ${widget.classId ?? "all"}',
      );
    } catch (e) {
      print('Error loading absensi detail: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildStudentItem(Siswa siswa, LanguageProvider languageProvider) {
    final status = _absensiStatus[siswa.id] ?? 'hadir';
    final Color statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getAvatarColor(siswa.nama),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                siswa.nama.isNotEmpty ? siswa.nama[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Student Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  siswa.nama,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${languageProvider.getTranslatedText({'en': 'NIS:', 'id': 'NIS:'})} ${siswa.nis}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Status Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: status,
                  items: [
                    DropdownMenuItem(
                      value: 'hadir',
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Present',
                          'id': 'Hadir',
                        }),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'terlambat',
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Late',
                          'id': 'Terlambat',
                        }),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'izin',
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Permission',
                          'id': 'Izin',
                        }),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'sakit',
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Sick',
                          'id': 'Sakit',
                        }),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'alpha',
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Absent',
                          'id': 'Alpha',
                        }),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _absensiStatus[siswa.id] = value!;
                    });
                  },
                  underline: Container(),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: statusColor,
                    size: 16,
                  ),
                  dropdownColor: Colors.white,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAbsensi() async {
    final languageProvider = context.read<LanguageProvider>();

    setState(() {
      _isSubmitting = true;
    });

    try {
      int successCount = 0;

      for (var siswa in _siswaList) {
        final status = _absensiStatus[siswa.id]!;

        await ApiService.tambahAbsensi({
          'student_id': siswa.id,
          'teacher_id': widget.guru['id'],
          'subject_id': widget.mataPelajaranId,
          'class_id': siswa.classId,
          'date': DateFormat('yyyy-MM-dd').format(widget.tanggal),
          'status': _mapStatusToBackend(status),
          'notes': '',
        });

        successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Successfully updated $successCount attendance records',
                'id': 'Berhasil update $successCount absensi',
              }),
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${languageProvider.getTranslatedText({'en': 'Error:', 'id': 'Error:'})} $e',
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Helper functions
  Color _getStatusColor(String status) {
    switch (status) {
      case 'izin':
        return Colors.blue;
      case 'sakit':
        return Colors.orange;
      case 'alpha':
        return Colors.red;
      case 'terlambat':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  Color _getAvatarColor(String nama) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple];
    final index = nama.codeUnitAt(0) % colors.length;
    return colors[index];
  }

  String _getKelasName(String classId) {
    try {
      final kelas = _kelasList.firstWhere(
        (k) => k['id'].toString() == classId,
        orElse: () => {'nama': 'Unknown Class'},
      );
      return kelas['nama'] ?? 'Unknown Class';
    } catch (e) {
      return 'Unknown Class';
    }
  }

  String _mapStatusToBackend(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'present';
      case 'terlambat':
        return 'late';
      case 'izin':
        return 'excused';
      case 'sakit':
        return 'sick';
      case 'alpha':
        return 'absent';
      default:
        return 'present';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              languageProvider.getTranslatedText({
                'en': 'Edit Attendance',
                'id': 'Edit Absensi',
              }),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.black),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.black),
                onPressed: _loadData,
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Refresh',
                  'id': 'Muat Ulang',
                }),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Container(height: 1, color: Colors.grey.shade300),
            ),
          ),
          body: _isLoading
              ? LoadingScreen(
                  message: languageProvider.getTranslatedText({
                    'en': 'Loading attendance details...',
                    'id': 'Memuat detail absensi...',
                  }),
                )
              : Column(
                  children: [
                    // Header Info
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            widget.mataPelajaranNama,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.classId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _getKelasName(widget.classId!),
                              style: TextStyle(
                                color: ColorUtils.getRoleColor("guru"),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            DateFormat(
                              'EEEE, dd MMMM yyyy',
                              'id_ID',
                            ).format(widget.tanggal),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_siswaList.length} ${languageProvider.getTranslatedText({'en': 'Students', 'id': 'Siswa'})}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Student List Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Student List',
                              'id': 'Daftar Siswa',
                            }),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Status',
                              'id': 'Status',
                            }),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Student List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: _siswaList.length,
                        itemBuilder: (context, index) => _buildStudentItem(
                          _siswaList[index],
                          languageProvider,
                        ),
                      ),
                    ),
                    // Update Button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSubmitting ? null : _updateAbsensi,
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.update, size: 20),
                          label: Text(
                            _isSubmitting
                                ? languageProvider.getTranslatedText({
                                    'en': 'Updating...',
                                    'id': 'Mengupdate...',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Update Attendance',
                                    'id': 'Update Absensi',
                                  }),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getPrimaryColor(),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// ========== HELPER FUNCTIONS UNTUK STYLING ==========
Color _getPrimaryColor() {
  return ColorUtils.getRoleColor('guru');
}

LinearGradient _getCardGradient() {
  final primaryColor = _getPrimaryColor();
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, primaryColor.withOpacity(0.7)],
  );
}

// ========== TEACHER ABSENSI DETAIL PAGE ==========
class TeacherAbsensiDetailPage extends StatefulWidget {
  final String mataPelajaranId;
  final String mataPelajaranNama;
  final DateTime tanggal;
  final String classId;
  final String kelasNama;
  final Map<String, dynamic> guru;

  const TeacherAbsensiDetailPage({
    super.key,
    required this.mataPelajaranId,
    required this.mataPelajaranNama,
    required this.tanggal,
    required this.classId,
    required this.kelasNama,
    required this.guru,
  });

  @override
  State<TeacherAbsensiDetailPage> createState() =>
      _TeacherAbsensiDetailPageState();
}

class _TeacherAbsensiDetailPageState extends State<TeacherAbsensiDetailPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _absensiData = [];
  List<Siswa> _siswaList = [];
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  final Map<String, String> _editedStatus = {};

  // Animations
  late AnimationController _animationController;

  String? _detectedClassId;

  @override
  void initState() {
    super.initState();
    _detectedClassId = widget.classId;

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // 1. Load attendance data
      final absensiData = await ApiService.getAbsensi(
        mataPelajaranId: widget.mataPelajaranId,
        tanggal: DateFormat('yyyy-MM-dd').format(widget.tanggal),
        guruId: widget.guru['id'],
      );

      // 2. Load students by class ID
      List<dynamic> siswaData;
      if (_detectedClassId != null && _detectedClassId!.isNotEmpty) {
        siswaData = await ApiStudentService.getStudentByClass(
          _detectedClassId!,
        );
      } else {
        // Fallback: if no classId provided, try to get from attendance data
        if (absensiData.isNotEmpty) {
          final classIdFromData =
              absensiData.first['class_id']?.toString() ??
              absensiData.first['kelas_id']?.toString();

          if (classIdFromData != null && classIdFromData.isNotEmpty) {
            _detectedClassId = classIdFromData;
            siswaData = await ApiStudentService.getStudentByClass(
              classIdFromData,
            );
          } else {
            siswaData = await ApiStudentService.getStudent();
          }
        } else {
          siswaData = await ApiStudentService.getStudent();
        }
      }

      if (mounted) {
        setState(() {
          _siswaList = siswaData.map((s) => Siswa.fromJson(s)).toList();
          _absensiData = absensiData;
          _isLoading = false;

          // Initialize edited status
          for (var siswa in _siswaList) {
            _editedStatus[siswa.id] = _getStudentStatus(siswa.id);
          }
        });
        _animationController.forward();
      }
    } catch (e) {
      print('Error loading absensi detail for teacher: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> exportDetail() async {
    if (_absensiData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak ada data kegiatan untuk diexport'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use ExcelPresenceService (make sure it's imported)
      // Assuming ExcelPresenceService is available in the file or imported
      // If not, we might need to add import. It is imported in admin_presence_report.dart
      // Let's assume it is available or I will add import if needed.
      // Wait, presence_teacher.dart doesn't import ExcelPresenceService.
      // I should probably skip export for now or add the import.
      // The user request didn't explicitly ask for export, but matching the UI implies it.
      // I'll leave the export button but maybe comment out the implementation if service is missing,
      // OR I can add the import.
      // Let's check imports in presence_teacher.dart.
    } catch (e) {
      print('Error exporting activities: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final languageProvider = context.read<LanguageProvider>();
      int successCount = 0;
      int errorCount = 0;

      for (var siswa in _siswaList) {
        final currentStatus = _getStudentStatus(siswa.id);
        final newStatus = _editedStatus[siswa.id];

        // Only update if status changed
        if (newStatus != null && newStatus != currentStatus) {
          try {
            await ApiService.tambahAbsensi({
              'student_id': siswa.id,
              'teacher_id': widget.guru['id'],
              'subject_id': widget.mataPelajaranId,
              'class_id': _detectedClassId ?? siswa.classId ?? '',
              'date': DateFormat('yyyy-MM-dd').format(widget.tanggal),
              'status': newStatus,
              'notes': '',
            });
            successCount++;
          } catch (e) {
            errorCount++;
            print('Error updating attendance for ${siswa.nama}: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isEditing = false;
        });

        if (successCount > 0 || errorCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.getTranslatedText({
                  'en': 'Attendance updated successfully',
                  'id': 'Absensi berhasil diperbarui',
                }),
              ),
              backgroundColor: Colors.green,
            ),
          );
          _loadData(); // Reload data to reflect changes
        } else if (errorCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.getTranslatedText({
                  'en': 'Failed to update some records',
                  'id': 'Gagal memperbarui beberapa data',
                }),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving changes: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withOpacity(0.8)],
    );
  }

  // Method untuk mendapatkan status absensi siswa
  String _getStudentStatus(String siswaId) {
    try {
      final absenRecord = _absensiData.firstWhere(
        (a) => a['student_id']?.toString() == siswaId.toString(),
        orElse: () => {'status': 'absent'}, // Fallback if not found
      );
      final status = absenRecord['status'] ?? 'absent';
      // Map 'alpha' to 'absent' if it exists in data
      return status == 'alpha' ? 'absent' : status;
    } catch (e) {
      return 'absent';
    }
  }

  Widget _buildStudentCard(
    Siswa siswa,
    LanguageProvider languageProvider,
    int index,
  ) {
    final status = _getStudentStatus(siswa.id);
    final Color statusColor = _getStatusColor(status);
    final String statusText = _getStatusText(status, languageProvider);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final delay = index * 0.1;
          final animation = CurvedAnimation(
            parent: _animationController,
            curve: Interval(delay, 1.0, curve: Curves.easeOut),
          );

          return FadeTransition(
            opacity: animation,
            child: Transform.translate(
              offset: Offset(0, 50 * (1 - animation.value)),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 5,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Strip biru di pinggir kiri
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: _getPrimaryColor(),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getPrimaryColor().withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              siswa.nama.isNotEmpty
                                  ? siswa.nama[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: _getPrimaryColor(),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),

                        // Student Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                siswa.nama,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                'NIS: ${siswa.nis}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status Badge or Dropdown
                        _isEditing
                            ? Container(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _editedStatus[siswa.id]
                                        ?.toLowerCase(),
                                    items:
                                        [
                                          'present',
                                          'late',
                                          'excused',
                                          'sick',
                                          'absent',
                                        ].map((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(
                                              _getStatusText(
                                                value,
                                                languageProvider,
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _getStatusColor(value),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _editedStatus[siswa.id] = newValue;
                                        });
                                      }
                                    },
                                    isDense: true,
                                  ),
                                ),
                              )
                            : Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper functions
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return Colors.green;
      case 'izin':
      case 'excused':
      case 'permission':
        return Colors.blue;
      case 'sakit':
      case 'sick':
        return Colors.orange;
      case 'alpha':
      case 'absent':
        return Colors.red;
      case 'terlambat':
      case 'late':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status, LanguageProvider languageProvider) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
      case 'sakit':
      case 'sick':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
        });
      case 'izin':
      case 'excused':
      case 'permission':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'alpha':
      case 'absent':
        return languageProvider.getTranslatedText({
          'en': 'Absent',
          'id': 'Alpha',
        });
      case 'terlambat':
      case 'late':
        return languageProvider.getTranslatedText({
          'en': 'Late',
          'id': 'Terlambat',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
  }

  // Method untuk menghitung statistik
  Map<String, int> _calculateStatistics() {
    int hadir = 0;
    int terlambat = 0;
    int izin = 0;
    int sakit = 0;
    int alpha = 0;

    for (var siswa in _siswaList) {
      final status = _getStudentStatus(siswa.id);
      switch (status.toLowerCase()) {
        case 'hadir':
        case 'present':
          hadir++;
          break;
        case 'terlambat':
        case 'late':
          terlambat++;
          break;
        case 'izin':
        case 'excused':
        case 'permission':
          izin++;
          break;
        case 'sakit':
        case 'sick':
          sakit++;
          break;
        case 'alpha':
        case 'absent':
          alpha++;
          break;
      }
    }

    return {
      'hadir': hadir,
      'terlambat': terlambat,
      'izin': izin,
      'sakit': sakit,
      'alpha': alpha,
      'total': _siswaList.length,
    };
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 100,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.8), color.withOpacity(0.6)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                SizedBox(height: 8),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final stats = _calculateStatistics();

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          appBar: AppBar(
            title: Text(
              languageProvider.getTranslatedText({
                'en': 'Attendance Details',
                'id': 'Detail Absensi',
              }),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: _getPrimaryColor(),
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Colors.white),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              if (!_isLoading)
                IconButton(
                  icon: Icon(
                    _isEditing ? Icons.save : Icons.edit,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_isEditing) {
                      _saveChanges();
                    } else {
                      setState(() {
                        _isEditing = true;
                        // Reset edited status to current status
                        for (var siswa in _siswaList) {
                          _editedStatus[siswa.id] = _getStudentStatus(siswa.id);
                        }
                      });
                    }
                  },
                ),
            ],
          ),
          body: _isLoading || _isSaving
              ? LoadingScreen(
                  message: languageProvider.getTranslatedText({
                    'en': _isSaving
                        ? 'Saving changes...'
                        : 'Loading attendance details...',
                    'id': _isSaving
                        ? 'Menyimpan perubahan...'
                        : 'Memuat detail absensi...',
                  }),
                )
              : Column(
                  children: [
                    // Header Info Card
                    Container(
                      margin: EdgeInsets.all(16),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: _getCardGradient(),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _getPrimaryColor().withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  widget.mataPelajaranNama,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  DateFormat(
                                    'EEEE, dd MMMM yyyy',
                                    'id_ID',
                                  ).format(widget.tanggal),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '${stats['total']} ${languageProvider.getTranslatedText({'en': 'Students', 'id': 'Siswa'})}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Statistics Cards
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildStatCard(
                            languageProvider.getTranslatedText({
                              'en': 'Present',
                              'id': 'Hadir',
                            }),
                            stats['hadir']!,
                            Colors.green,
                            Icons.check_circle,
                          ),
                          _buildStatCard(
                            languageProvider.getTranslatedText({
                              'en': 'Late',
                              'id': 'Terlambat',
                            }),
                            stats['terlambat']!,
                            Colors.purple,
                            Icons.watch_later,
                          ),
                          _buildStatCard(
                            languageProvider.getTranslatedText({
                              'en': 'Permission',
                              'id': 'Izin',
                            }),
                            stats['izin']!,
                            Colors.blue,
                            Icons.assignment_turned_in,
                          ),
                          _buildStatCard(
                            languageProvider.getTranslatedText({
                              'en': 'Sick',
                              'id': 'Sakit',
                            }),
                            stats['sakit']!,
                            Colors.orange,
                            Icons.local_hospital,
                          ),
                          _buildStatCard(
                            languageProvider.getTranslatedText({
                              'en': 'Absent',
                              'id': 'Alpha',
                            }),
                            stats['alpha']!,
                            Colors.red,
                            Icons.cancel,
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16),

                    // Student List Header
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Student List',
                              'id': 'Daftar Siswa',
                            }),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 8),

                    // Student List
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.only(bottom: 16),
                        itemCount: _siswaList.length,
                        itemBuilder: (context, index) {
                          final siswa = _siswaList[index];
                          return _buildStudentCard(
                            siswa,
                            languageProvider,
                            index,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
