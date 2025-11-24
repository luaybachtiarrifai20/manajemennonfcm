import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/filter_sheet.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/components/separated_search_filter.dart';
import 'package:manajemensekolah/screen/guru/class_activity.dart';
import 'package:manajemensekolah/screen/guru/materi_screen.dart';
import 'package:manajemensekolah/screen/guru/presence_teacher.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeachingScheduleScreen extends StatefulWidget {
  const TeachingScheduleScreen({super.key});

  @override
  TeachingScheduleScreenState createState() => TeachingScheduleScreenState();
}

class TeachingScheduleScreenState extends State<TeachingScheduleScreen> {
  List<dynamic> _jadwalList = [];
  List<dynamic> _semesterList = [];
  bool _isLoading = true;
  String _guruId = '';
  String _guruNama = '';
  String _selectedSemester = '1'; // Will be set by _setDefaultAcademicPeriod()
  String _selectedAcademicYear =
      '2024/2025'; // Will be set by _setDefaultAcademicPeriod()
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  List<String> _selectedHariIds = [];
  String? _selectedFilterSemester;
  String? _selectedFilterAcademicYear;
  bool _hasActiveFilter = false;

  // DITAMBAHKAN KEMBALI: Toggle antara card dan table view
  bool _isTableView = false;

  final List<String> _hariOptions = [
    'Semua Hari',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  final Map<String, String> _hariIdMap = {
    'Senin': '1',
    'Selasa': '2',
    'Rabu': '3',
    'Kamis': '4',
    'Jumat': '5',
    'Sabtu': '6',
  };

  final Map<String, Color> _hariColorMap = {
    'Senin': Color(0xFF6366F1),
    'Selasa': Color(0xFF10B981),
    'Rabu': Color(0xFFF59E0B),
    'Kamis': Color(0xFFEF4444),
    'Jumat': Color(0xFF8B5CF6),
    'Sabtu': Color(0xFF06B6D4),
  };

  @override
  void initState() {
    super.initState();
    _setDefaultAcademicPeriod();
    _loadUserData();
  }

  /// Calculate current academic year based on current date
  String _getCurrentAcademicYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Academic year runs from July to June
    // If current month is July or later, academic year is currentYear/nextYear
    // Otherwise, academic year is previousYear/currentYear
    if (currentMonth >= 7) {
      return '$currentYear/${currentYear + 1}';
    } else {
      return '${currentYear - 1}/$currentYear';
    }
  }

  /// Get current semester (1 or 2) based on current month
  String _getCurrentSemester() {
    final now = DateTime.now();
    final currentMonth = now.month;

    // Semester 1: July - December (months 7-12)
    // Semester 2: January - June (months 1-6)
    if (currentMonth >= 7) {
      return '1'; // Semester 1
    } else {
      return '2'; // Semester 2
    }
  }

  /// Set default academic year and semester based on current date
  void _setDefaultAcademicPeriod() {
    setState(() {
      _selectedAcademicYear = _getCurrentAcademicYear();
      _selectedSemester = _getCurrentSemester();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = json.decode(prefs.getString('user') ?? '{}');

      setState(() {
        _guruId = userData['id']?.toString() ?? '';
        _guruNama = userData['nama']?.toString() ?? 'Guru';
      });

      if (_guruId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      await _loadSemesterData();
      _loadJadwal();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSemesterData() async {
    try {
      final semesterData = await ApiScheduleService.getSemester();

      setState(() {
        _semesterList = semesterData;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading semester data: $e');
      }
    }
  }

  Future<void> _loadJadwal() async {
    if (_guruId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Use filter semester/year if set, otherwise use selected
      final semesterToUse = _selectedFilterSemester ?? _selectedSemester;
      final academicYearToUse =
          _selectedFilterAcademicYear ?? _selectedAcademicYear;

      final jadwal = await ApiScheduleService.getFilteredSchedule(
        guruId: _guruId,
        semester: semesterToUse,
        tahunAjaran: academicYearToUse,
      );

      setState(() {
        _jadwalList = jadwal;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error load jadwal: $e');
      }
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      _showErrorSnackBar('Failed to load schedule data: $e');
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
                'Failed to load schedule data:',
                'Gagal memuat data jadwal:',
              ),
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedHariIds.isNotEmpty ||
          (_selectedFilterSemester != null &&
              _selectedFilterSemester != _selectedSemester) ||
          (_selectedFilterAcademicYear != null &&
              _selectedFilterAcademicYear != _selectedAcademicYear);
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedHariIds.clear();
      _selectedFilterSemester = null;
      _selectedFilterAcademicYear = null;
      // Reset to current period
      _selectedSemester = _getCurrentSemester();
      _selectedAcademicYear = _getCurrentAcademicYear();
      _checkActiveFilter();
    });
    _loadJadwal();
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    // Hari chips
    for (var hariId in _selectedHariIds) {
      final hari = _hariOptions.firstWhere(
        (h) => _hariIdMap[h] == hariId,
        orElse: () => 'Hari',
      );
      filterChips.add({
        'label': hari,
        'onRemove': () {
          setState(() {
            _selectedHariIds.remove(hariId);
            _checkActiveFilter();
          });
        },
      });
    }

    // Semester chip
    if (_selectedFilterSemester != null &&
        _selectedFilterSemester != _selectedSemester) {
      final semester = _semesterList.firstWhere(
        (s) => s['id'].toString() == _selectedFilterSemester,
        orElse: () => {'nama': 'Semester ${_selectedFilterSemester}'},
      );
      filterChips.add({
        'label': semester['nama'] ?? 'Semester',
        'onRemove': () {
          setState(() {
            _selectedFilterSemester = null;
            _checkActiveFilter();
          });
          _loadJadwal();
        },
      });
    }

    // Tahun Ajaran chip
    if (_selectedFilterAcademicYear != null &&
        _selectedFilterAcademicYear != _selectedAcademicYear) {
      filterChips.add({
        'label': _selectedFilterAcademicYear!,
        'onRemove': () {
          setState(() {
            _selectedFilterAcademicYear = null;
            _checkActiveFilter();
          });
          _loadJadwal();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    // Temporary values for filter
    String? tempSelectedSemester = _selectedFilterSemester;
    String? tempSelectedAcademicYear = _selectedFilterAcademicYear;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        primaryColor: _getPrimaryColor(),
        config: FilterConfig(
          sections: [
            FilterSection(
              key: 'hariIds',
              title: languageProvider.getTranslatedText({
                'en': 'Day',
                'id': 'Hari',
              }),
              options: _hariOptions.where((hari) => hari != 'Semua Hari').map((
                hari,
              ) {
                return FilterOption(label: hari, value: _hariIdMap[hari] ?? '');
              }).toList(),
              multiSelect: true,
            ),
            FilterSection(
              key: 'semester',
              title: languageProvider.getTranslatedText({
                'en': 'Semester',
                'id': 'Semester',
              }),
              options: _semesterList.map((semester) {
                return FilterOption(
                  label: semester['nama'] ?? 'Semester',
                  value: semester['id'].toString(),
                );
              }).toList(),
              multiSelect: false,
            ),
            FilterSection(
              key: 'tahunAjaran',
              title: languageProvider.getTranslatedText({
                'en': 'Academic Year',
                'id': 'Tahun Ajaran',
              }),
              options: [
                FilterOption(label: '2023/2024', value: '2023/2024'),
                FilterOption(label: '2024/2025', value: '2024/2025'),
                FilterOption(label: '2025/2026', value: '2025/2026'),
                FilterOption(label: '2026/2027', value: '2026/2027'),
              ],
              multiSelect: false,
            ),
          ],
        ),
        initialFilters: {
          'hariIds': _selectedHariIds,
          'semester': tempSelectedSemester ?? _selectedSemester,
          'tahunAjaran': tempSelectedAcademicYear ?? _selectedAcademicYear,
        },
        onApplyFilters: (filters) {
          // Check if semester or academic year changed - need to reload data
          bool needsReload = false;

          final newSemester = filters['semester'];
          final newAcademicYear = filters['tahunAjaran'];

          if (newSemester != null && newSemester != _selectedSemester) {
            needsReload = true;
          }
          if (newAcademicYear != null &&
              newAcademicYear != _selectedAcademicYear) {
            needsReload = true;
          }

          setState(() {
            _selectedHariIds = List<String>.from(filters['hariIds'] ?? []);
            _selectedFilterSemester = newSemester;
            _selectedFilterAcademicYear = newAcademicYear;

            // Update main semester/year if filtered
            if (newSemester != null) {
              _selectedSemester = newSemester;
            }
            if (newAcademicYear != null) {
              _selectedAcademicYear = newAcademicYear;
            }

            _checkActiveFilter();
          });

          // Reload data if semester or academic year changed
          if (needsReload) {
            _loadJadwal();
          }
        },
      ),
    );
  }

  // DITAMBAHKAN KEMBALI: Method untuk toggle view
  void _toggleView() {
    setState(() {
      _isTableView = !_isTableView;
    });
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withOpacity(0.8)],
    );
  }

  Color _getHariColor(String hari) {
    return _hariColorMap[hari] ?? Color(0xFF6B7280);
  }

  List<dynamic> _getFilteredSchedules() {
    final searchTerm = _searchController.text.toLowerCase();
    return _jadwalList.where((schedule) {
      final subjectName =
          schedule['mata_pelajaran_nama']?.toString().toLowerCase() ?? '';
      final className = schedule['kelas_nama']?.toString().toLowerCase() ?? '';
      final dayName = schedule['hari_nama']?.toString() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          className.contains(searchTerm) ||
          dayName.toLowerCase().contains(searchTerm);

      // Filter by hari - match by hari_nama
      final matchesHari =
          _selectedHariIds.isEmpty ||
          _selectedHariIds.any((selectedId) {
            // Get the hari name from the selected ID
            final selectedHariName = _hariIdMap.entries
                .firstWhere(
                  (entry) => entry.value == selectedId,
                  orElse: () => MapEntry('', ''),
                )
                .key;
            return dayName == selectedHariName;
          });

      return matchesSearch && matchesHari;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final filteredSchedules = _getFilteredSchedules();

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header dengan gradient
              Container(
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
                            child: Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Teaching Schedule',
                                  'id': 'Jadwal Mengajar',
                                }),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'View your teaching schedule',
                                  'id': 'Lihat jadwal mengajar Anda',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // DITAMBAHKAN KEMBALI: Tombol toggle view
                        GestureDetector(
                          onTap: _toggleView,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isTableView ? Icons.grid_view : Icons.list,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.schedule,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Info Guru
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _guruNama,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  languageProvider.getTranslatedText({
                                    'en': 'Teacher',
                                    'id': 'Guru',
                                  }),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Search Bar with Filter using SeparatedSearchFilter
                    SeparatedSearchFilter(
                      controller: _searchController,
                      onChanged: (value) => setState(() {}),
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search schedules...',
                        'id': 'Cari jadwal...',
                      }),
                      showFilter: true,
                      hasActiveFilter: _hasActiveFilter,
                      onFilterPressed: _showFilterSheet,
                      // Custom search styling
                      searchBackgroundColor: Colors.white.withOpacity(0.95),
                      searchIconColor: Colors.grey.shade600,
                      searchTextColor: Colors.black87,
                      searchHintColor: Colors.grey.shade500,
                      searchBorderRadius: 14,
                      // Custom filter styling
                      filterActiveColor: _getPrimaryColor(),
                      filterInactiveColor: Colors.white.withOpacity(0.9),
                      filterIconColor: _hasActiveFilter
                          ? Colors.white
                          : _getPrimaryColor(),
                      filterBorderRadius: 14,
                      filterWidth: 56,
                      filterHeight: 48,
                      spacing: 12,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 0,
                      ),
                    ),

                    // Filter Chips
                    if (_hasActiveFilter) ...[
                      SizedBox(height: 12),
                      SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            Expanded(
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ..._buildFilterChips(languageProvider).map((
                                    filter,
                                  ) {
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
                                        backgroundColor: Colors.white
                                            .withOpacity(0.2),
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                            InkWell(
                              onTap: _clearAllFilters,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                    width: 1,
                                  ),
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
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? LoadingScreen(
                        message: languageProvider.getTranslatedText({
                          'en': 'Loading schedule data...',
                          'id': 'Memuat data jadwal...',
                        }),
                      )
                    : Column(
                        children: [
                          // View Toggle Info
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text(
                                  '${filteredSchedules.length} ${languageProvider.getTranslatedText({'en': 'schedules found', 'id': 'jadwal ditemukan'})}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                Spacer(),
                                Text(
                                  _isTableView
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Table View',
                                          'id': 'Tampilan Tabel',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Card View',
                                          'id': 'Tampilan Kartu',
                                        }),
                                  style: TextStyle(
                                    color: _getPrimaryColor(),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 4),

                          Expanded(
                            child: filteredSchedules.isEmpty
                                ? EmptyState(
                                    icon: Icons.schedule_outlined,
                                    title: languageProvider.getTranslatedText({
                                      'en': 'No Teaching Schedules',
                                      'id': 'Tidak Ada Jadwal Mengajar',
                                    }),
                                    subtitle: languageProvider.getTranslatedText({
                                      'en':
                                          _searchController.text.isNotEmpty ||
                                              _hasActiveFilter
                                          ? 'No schedules found for your search and filters'
                                          : 'There are no teaching schedules available',
                                      'id':
                                          _searchController.text.isNotEmpty ||
                                              _hasActiveFilter
                                          ? 'Tidak ada jadwal yang sesuai dengan pencarian dan filter'
                                          : 'Tidak ada jadwal mengajar yang tersedia',
                                    }),
                                    buttonText: languageProvider
                                        .getTranslatedText({
                                          'en': 'Refresh',
                                          'id': 'Muat Ulang',
                                        }),
                                    onPressed: _loadJadwal,
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadJadwal,
                                    color: _getPrimaryColor(),
                                    backgroundColor: Colors.white,
                                    child: _isTableView
                                        ? _buildTableView(
                                            languageProvider,
                                            filteredSchedules,
                                          )
                                        : _buildCardView(
                                            languageProvider,
                                            filteredSchedules,
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
  }

  // DITAMBAHKAN KEMBALI: Method untuk table view dengan format seperti Excel
  Widget _buildTableView(
    LanguageProvider languageProvider,
    List<dynamic> schedules,
  ) {
    // Group schedules by day and class
    final Map<String, Map<String, List<dynamic>>> scheduleMap = {};

    for (var schedule in schedules) {
      final hari = schedule['hari_nama']?.toString() ?? 'Unknown';
      final kelas = schedule['kelas_nama']?.toString() ?? 'Unknown';

      if (!scheduleMap.containsKey(hari)) {
        scheduleMap[hari] = {};
      }
      if (!scheduleMap[hari]!.containsKey(kelas)) {
        scheduleMap[hari]![kelas] = [];
      }

      scheduleMap[hari]![kelas]!.add(schedule);
    }

    // Get unique classes and days
    final classes =
        scheduleMap.values.expand((dayMap) => dayMap.keys).toSet().toList()
          ..sort();

    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final availableDays = days
        .where((day) => scheduleMap.containsKey(day))
        .toList();

    // Get all unique session numbers
    final allSessions =
        schedules
            .map((s) => int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0)
            .toSet()
            .toList()
          ..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'JADWAL PELAJARAN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getPrimaryColor(),
                ),
              ),
              SizedBox(height: 16),

              // Table
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Header Row 1 - Hari
                    Container(
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withOpacity(0.1),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Empty cells for time and session
                          Container(
                            width: 80,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                            child: Text(
                              'Jam Ke-',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                            child: Text(
                              'Waktu',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),

                          // Hari headers
                          ...availableDays.expand((day) {
                            return [
                              Container(
                                width: 200 * classes.length.toDouble(),
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: availableDays.last == day
                                          ? Colors.transparent
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getHariColor(day),
                                  ),
                                ),
                              ),
                            ];
                          }),
                        ],
                      ),
                    ),

                    // Header Row 2 - Kelas
                    Container(
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withOpacity(0.05),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Empty cells for time and session
                          Container(
                            width: 80,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                          ),

                          // Kelas headers for each day
                          ...availableDays.expand((day) {
                            return classes.asMap().entries.map((classEntry) {
                              final isLastInDay =
                                  classEntry.key == classes.length - 1;
                              final isLastDay = availableDays.last == day;

                              return Container(
                                width: 200,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: (isLastInDay && !isLastDay)
                                          ? Colors.grey.shade400
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  classEntry.value,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              );
                            }).toList();
                          }),
                        ],
                      ),
                    ),

                    // Data Rows
                    ...allSessions.map((session) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: session == allSessions.last
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Session Number
                            Container(
                              width: 80,
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              child: Text(
                                session.toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            // Time
                            Container(
                              width: 100,
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              child: _buildTimeForSession(session, schedules),
                            ),

                            // Schedule Data for each day and class
                            ...availableDays.expand((day) {
                              return classes.map((kelas) {
                                final scheduleForCell =
                                    _getScheduleForSessionAndDayAndClass(
                                      session,
                                      day,
                                      kelas,
                                      schedules,
                                    );

                                return Container(
                                  width: 200,
                                  height: 60,
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color:
                                            classes.last == kelas &&
                                                availableDays.last != day
                                            ? Colors.grey.shade400
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  child: scheduleForCell != null
                                      ? Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _getHariColor(
                                              day,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: _getHariColor(
                                                day,
                                              ).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                scheduleForCell['mata_pelajaran_nama'] ??
                                                    '',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getHariColor(day),
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (scheduleForCell['guru_nama'] !=
                                                  null)
                                                Text(
                                                  scheduleForCell['guru_nama']!,
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        )
                                      : Container(),
                                );
                              }).toList();
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Legend
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keterangan:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      children: availableDays.map((day) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getHariColor(day),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(day, style: TextStyle(fontSize: 12)),
                          ],
                        );
                      }).toList(),
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

  // Helper method to get time for session
  Widget _buildTimeForSession(int session, List<dynamic> schedules) {
    final scheduleForSession = schedules.firstWhere(
      (s) => (int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0) == session,
      orElse: () => <String, dynamic>{},
    );

    if (scheduleForSession.isNotEmpty) {
      final startTime = _formatTime(scheduleForSession['jam_mulai']);
      final endTime = _formatTime(scheduleForSession['jam_selesai']);
      return Text(
        '$startTime\n$endTime',
        style: TextStyle(fontSize: 10),
        textAlign: TextAlign.center,
      );
    }

    return Text(
      '--:--\n--:--',
      style: TextStyle(fontSize: 10, color: Colors.grey),
      textAlign: TextAlign.center,
    );
  }

  // Helper method to find schedule for specific session, day, and class
  Map<String, dynamic>? _getScheduleForSessionAndDayAndClass(
    int session,
    String day,
    String kelas,
    List<dynamic> schedules,
  ) {
    try {
      return schedules.firstWhere(
        (s) =>
            (int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0) == session &&
            s['hari_nama']?.toString() == day &&
            s['kelas_nama']?.toString() == kelas,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      return null;
    }
  }

  // DIPINDAH: Method untuk card view (sebelumnya _buildJadwalCard)
  Widget _buildCardView(
    LanguageProvider languageProvider,
    List<dynamic> schedules,
  ) {
    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: 16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        return _buildJadwalCard(schedules[index], languageProvider, index);
      },
    );
  }

  Widget _buildJadwalCard(
    Map<String, dynamic> jadwal,
    LanguageProvider languageProvider,
    int index,
  ) {
    final hari = jadwal['hari_nama']?.toString() ?? 'Unknown';
    final hariColor = _getHariColor(hari);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to Presence Page with schedule data
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PresencePage(
                  guru: {'id': _guruId, 'nama': _guruNama},
                  initialDate: DateTime.now(),
                  initialMataPelajaranId: jadwal['mata_pelajaran_id']
                      ?.toString(),
                  initialMataPelajaranNama: jadwal['mata_pelajaran_nama']
                      ?.toString(),
                  initialclassId: jadwal['kelas_id']?.toString(),
                  initialKelasNama: jadwal['kelas_nama']?.toString(),
                ),
              ),
            );
          },
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
                // Strip berwarna di pinggir kiri sesuai hari
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: hariColor,
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

                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header dengan mata pelajaran dan tahun ajaran - DIUBAH
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  jadwal['mata_pelajaran_nama'] ??
                                      languageProvider.getTranslatedText({
                                        'en': 'Subject',
                                        'id': 'Mata Pelajaran',
                                      }),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                // DIUBAH: Tahun ajaran di bawah mata pelajaran dengan ukuran kecil
                                Text(
                                  jadwal['tahun_ajaran_nama'] ??
                                      _selectedAcademicYear,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // DIUBAH: Hari diperbesar
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: hariColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: hariColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              hari,
                              style: TextStyle(
                                color: hariColor,
                                fontSize: 14, // DIUBAH: diperbesar dari 12
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      // Informasi waktu
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
                              Icons.access_time,
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
                                  languageProvider.getTranslatedText({
                                    'en': 'Time',
                                    'id': 'Waktu',
                                  }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  '${_formatTime(jadwal['jam_mulai'])} - ${_formatTime(jadwal['jam_selesai'])}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.format_list_numbered,
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
                                  languageProvider.getTranslatedText({
                                    'en': 'Session',
                                    'id': 'Sesi',
                                  }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  '${languageProvider.getTranslatedText({'en': 'Hour', 'id': 'Jam'})} ${jadwal['jam_ke'] ?? ''}',
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

                      SizedBox(height: 12),

                      // Informasi kelas dan semester - DIUBAH: menghapus tahun ajaran dari sini
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
                              Icons.school,
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
                                  languageProvider.getTranslatedText({
                                    'en': 'Class & Semester',
                                    'id': 'Kelas & Semester',
                                  }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  '${jadwal['kelas_nama'] ?? '-'} • ${jadwal['semester_nama'] ?? 'Semester'}',
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

                      SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MateriPage(
                                      guru: {'id': _guruId, 'nama': _guruNama},
                                      initialSubjectId:
                                          jadwal['mata_pelajaran_id']
                                              ?.toString(),
                                      initialSubjectName:
                                          jadwal['mata_pelajaran_nama']
                                              ?.toString(),
                                      initialClassId: jadwal['kelas_id']
                                          ?.toString(),
                                      initialClassName: jadwal['kelas_nama']
                                          ?.toString(),
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.library_books, size: 16),
                              label: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Material',
                                  'id': 'Materi',
                                }),
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _getPrimaryColor(),
                                side: BorderSide(color: _getPrimaryColor()),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                // Calculate next occurrence date for this schedule
                                final now = DateTime.now();
                                final scheduleDay = _hariIdMap.entries
                                    .firstWhere(
                                      (entry) =>
                                          entry.value ==
                                          jadwal['hari_id']?.toString(),
                                      orElse: () => MapEntry('Senin', '1'),
                                    )
                                    .key;
                                final scheduleDayIndex = _hariOptions.indexOf(
                                  scheduleDay,
                                );
                                final todayIndex = now.weekday;
                                int daysUntilSchedule =
                                    scheduleDayIndex - todayIndex;
                                if (daysUntilSchedule < 0) {
                                  daysUntilSchedule += 7;
                                }
                                final scheduleDate = now.add(
                                  Duration(days: daysUntilSchedule),
                                );

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClassActifityScreen(
                                      initialDate: scheduleDate,
                                      initialSubjectId:
                                          jadwal['mata_pelajaran_id']
                                              ?.toString(),
                                      initialSubjectName:
                                          jadwal['mata_pelajaran_nama']
                                              ?.toString(),
                                      initialClassId: jadwal['kelas_id']
                                          ?.toString(),
                                      initialClassName: jadwal['kelas_nama']
                                          ?.toString(),
                                      autoShowActivityDialog: true,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.assignment, size: 16),
                              label: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Activity',
                                  'id': 'Aktivitas',
                                }),
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getPrimaryColor(),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
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
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';

    // Handle various time formats
    final cleanedTime = time.replaceAll('.', ':');
    final timeParts = cleanedTime.split(':');

    if (timeParts.length >= 2) {
      final hour = timeParts[0].padLeft(2, '0');
      final minute = timeParts[1].padLeft(2, '0');
      return '$hour:$minute';
    }

    return time.length >= 5 ? time.substring(0, 5) : time;
  }
}
