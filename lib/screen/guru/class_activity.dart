// class_activity.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/components/new_enhanced_search_bar.dart';
import 'package:manajemensekolah/components/tab_switcher.dart';
import 'package:manajemensekolah/components/filter_sheet.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_class_activity_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:provider/provider.dart';

class ClassActifityScreen extends StatefulWidget {
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;
  final String? initialBabId;
  final String? initialSubBabId;
  final bool autoShowActivityDialog;
  
  const ClassActifityScreen({
    super.key,
    this.initialDate,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
    this.initialBabId,
    this.initialSubBabId,
    this.autoShowActivityDialog = false,
  });

  @override
  ClassActifityScreenState createState() => ClassActifityScreenState();
}

class ClassActifityScreenState extends State<ClassActifityScreen>
    with TickerProviderStateMixin {
  List<dynamic> _scheduleList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _chapterList = [];
  List<dynamic> _subChapterList = [];
  List<dynamic> _activityList = [];
  List<dynamic> _studentList = [];

  bool _isLoading = true;
  String _teacherId = '';
  String _teacherName = '';

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDateFilter;
  List<String> _selectedSubjectIds = [];
  bool _hasActiveFilter = false;

  late TabController _tabController;
  String _currentTarget = 'umum';

  final Map<String, Color> _dayColorMap = {
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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    setState(() {
      _currentTarget = _tabController.index == 0 ? 'umum' : 'khusus';
    });
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = json.decode(prefs.getString('user') ?? '{}');

      setState(() {
        _teacherId = userData['id']?.toString() ?? '';
        _teacherName = userData['nama']?.toString() ?? 'Guru';
      });

      if (_teacherId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      await _loadSchedule();
      await _loadActivities();
    } catch (e) {
      setState(() => _isLoading = false);
      if (kDebugMode) {
        print('Error load user data: $e');
      }
    }
  }

  Future<void> _loadSchedule() async {
    try {
      // Get current academic year dynamically
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;
      
      // Academic year runs from July to June
      final tahunAjaran = currentMonth >= 7 
          ? '$currentYear/${currentYear + 1}'
          : '${currentYear - 1}/$currentYear';
      
      if (kDebugMode) {
        print('===== LOADING SCHEDULE =====');
        print('Teacher ID: $_teacherId');
        print('Academic Year: $tahunAjaran');
      }

      final schedule = await ApiScheduleService.getScheduleByGuru(
        guruId: _teacherId,
        tahunAjaran: tahunAjaran,
      );

      if (kDebugMode) {
        print('Total schedules loaded: ${schedule.length}');
      }

      // If no schedule found for current year, try loading all schedules
      List<dynamic> finalSchedule = schedule;
      if (schedule.isEmpty) {
        if (kDebugMode) {
          print('No schedule found for $tahunAjaran, trying to load all schedules...');
        }
        try {
          finalSchedule = await ApiScheduleService.getScheduleByGuru(
            guruId: _teacherId,
          );
          if (kDebugMode) {
            print('Total schedules loaded (all years): ${finalSchedule.length}');
          }
        } catch (e) {
          if (kDebugMode) {
            print('Failed to load all schedules: $e');
          }
        }
      }

      final uniqueSubjects = <String, dynamic>{};
      final uniqueClasses = <String, dynamic>{};

      for (var scheduleItem in finalSchedule) {
        final subjectId = scheduleItem['mata_pelajaran_id']?.toString();
        final subjectName = scheduleItem['mata_pelajaran_nama']?.toString();
        final classId = scheduleItem['kelas_id']?.toString();
        final className = scheduleItem['kelas_nama']?.toString();
        
        if (kDebugMode) {
          print('Schedule item: $subjectName (ID: $subjectId), Class: $className (ID: $classId), Day: ${scheduleItem['hari_nama']}, Time: ${scheduleItem['jam_mulai']} - ${scheduleItem['jam_selesai']}');
        }

        if (subjectId != null && !uniqueSubjects.containsKey(subjectId)) {
          uniqueSubjects[subjectId] = {'id': subjectId, 'nama': subjectName};
        }

        if (classId != null && !uniqueClasses.containsKey(classId)) {
          uniqueClasses[classId] = {'id': classId, 'nama': className};
        }
      }

      if (kDebugMode) {
        print('Unique subjects: ${uniqueSubjects.length}');
        print('Subject list: ${uniqueSubjects.values.map((s) => s['nama']).toList()}');
        print('===========================');
      }

      setState(() {
        _scheduleList = finalSchedule;
        _subjectList = uniqueSubjects.values.toList();
      });
    } catch (e) {
      if (kDebugMode) {
        print('ERROR loading schedule: $e');
        print('Stack trace: ${StackTrace.current}');
      }
    }
  }

  void _showActivityTypeDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            
            // Title
            Text(
              languageProvider.getTranslatedText({
                'en': 'Select Activity Type',
                'id': 'Pilih Jenis Kegiatan',
              }),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Choose what you want to create',
                'id': 'Pilih apa yang ingin Anda buat',
              }),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            
            // Tugas Option
            _buildActivityTypeOption(
              icon: Icons.assignment,
              title: languageProvider.getTranslatedText({
                'en': 'Assignment',
                'id': 'Tugas',
              }),
              description: languageProvider.getTranslatedText({
                'en': 'Create an assignment for students',
                'id': 'Buat tugas untuk siswa',
              }),
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showAddActivityDialog('tugas');
              },
            ),
            SizedBox(height: 12),
            
            // Materi Option
            _buildActivityTypeOption(
              icon: Icons.book,
              title: languageProvider.getTranslatedText({
                'en': 'Material',
                'id': 'Materi',
              }),
              description: languageProvider.getTranslatedText({
                'en': 'Share learning materials',
                'id': 'Bagikan materi pembelajaran',
              }),
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showAddActivityDialog('materi');
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTypeOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddActivityDialog(String activityType) {
    showDialog(
      context: context,
      builder: (context) => AddActivityDialog(
        teacherId: _teacherId,
        teacherName: _teacherName,
        scheduleList: _scheduleList,
        subjectList: _subjectList,
        chapterList: _chapterList,
        subChapterList: _subChapterList,
        onSubjectSelected: _loadMaterials,
        onChapterSelected: _loadSubChapterMaterials,
        onActivityAdded: _loadActivities,
        initialTarget: _currentTarget,
        activityType: activityType,
        initialDate: widget.initialDate,
        initialSubjectId: widget.initialSubjectId,
        initialClassId: widget.initialClassId,
        initialBabId: widget.initialBabId,
        initialSubBabId: widget.initialSubBabId,
      ),
    );
  }

  void _showEditActivityDialog(dynamic activity) {
    showDialog(
      context: context,
      builder: (context) => AddActivityDialog(
        teacherId: _teacherId,
        teacherName: _teacherName,
        scheduleList: _scheduleList,
        subjectList: _subjectList,
        chapterList: _chapterList,
        subChapterList: _subChapterList,
        onSubjectSelected: _loadMaterials,
        onChapterSelected: _loadSubChapterMaterials,
        onActivityAdded: _loadActivities,
        initialTarget: activity['target'] ?? 'umum',
        activityType: activity['jenis'] ?? 'tugas',
        isEditMode: true,
        activityData: activity,
        initialDate: activity['tanggal'] != null 
            ? DateTime.tryParse(activity['tanggal'].toString()) 
            : null,
        initialSubjectId: activity['mata_pelajaran_id']?.toString(),
        initialClassId: activity['kelas_id']?.toString(),
        initialBabId: activity['bab_id']?.toString(),
        initialSubBabId: activity['sub_bab_id']?.toString(),
      ),
    );
  }

  Future<void> _deleteActivity(dynamic activity, LanguageProvider languageProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Delete Activity',
            'id': 'Hapus Kegiatan',
          }),
        ),
        content: Text(
          languageProvider.getTranslatedText({
            'en': 'Are you sure you want to delete "${activity['judul']}"? This action cannot be undone.',
            'id': 'Apakah Anda yakin ingin menghapus "${activity['judul']}"? Tindakan ini tidak dapat dibatalkan.',
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
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
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

    if (confirmed == true) {
      try {
        await ApiClassActivityService.deleteKegiatan(activity['id'].toString());
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Activity deleted successfully',
                'id': 'Kegiatan berhasil dihapus',
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh list
        _loadActivities();
      } catch (e) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Failed to delete activity: $e',
                'id': 'Gagal menghapus kegiatan: $e',
              }),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  List<dynamic> _getFilteredActivities() {
    final searchTerm = _searchController.text.toLowerCase();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return _activityList.where((activity) {
      // Filter berdasarkan tab
      final matchesTarget = activity['target'] == _currentTarget;

      // Filter search
      final matchesSearch =
          searchTerm.isEmpty ||
          (activity['judul']?.toString().toLowerCase().contains(searchTerm) ??
              false) ||
          (activity['mata_pelajaran_nama']?.toString().toLowerCase().contains(
                searchTerm,
              ) ??
              false);

      // Filter tanggal
      final activityDate = activity['tanggal'] != null
          ? DateTime.tryParse(activity['tanggal'])
          : null;

      bool matchesDateFilter = true;
      if (_selectedDateFilter != null && activityDate != null) {
        if (_selectedDateFilter == 'today') {
          matchesDateFilter = _isSameDay(activityDate, now);
        } else if (_selectedDateFilter == 'week') {
          matchesDateFilter =
              activityDate.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
                  activityDate.isBefore(endOfWeek.add(Duration(days: 1)));
        } else if (_selectedDateFilter == 'month') {
          matchesDateFilter =
              activityDate.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
                  activityDate.isBefore(endOfMonth.add(Duration(days: 1)));
        }
      }

      // Filter mata pelajaran
      final matchesSubject =
          _selectedSubjectIds.isEmpty ||
          _selectedSubjectIds.contains(activity['mata_pelajaran_id']?.toString());

      return matchesTarget && matchesSearch && matchesDateFilter && matchesSubject;
    }).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
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

  // ========== HEADER SEPERTI PRESENCE TEACHER ==========
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
                      languageProvider.getTranslatedText({
                        'en': 'Class Activities',
                        'id': 'Kegiatan Kelas',
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
                        'en': 'Manage class materials and assignments',
                        'id': 'Kelola materi dan tugas kelas',
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
                      _loadActivities();
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

          // Tab Switcher menggunakan komponen
          _buildTabSwitcher(languageProvider),
        ],
      ),
    );
  }

  // ========== TAB SWITCHER MENGGUNAKAN KOMPONEN ==========
  Widget _buildTabSwitcher(LanguageProvider languageProvider) {
    final tabs = [
      TabItem(
        label: languageProvider.getTranslatedText({
          'en': 'All Students',
          'id': 'Semua Siswa',
        }),
        icon: Icons.group,
      ),
      TabItem(
        label: languageProvider.getTranslatedText({
          'en': 'Specific Student',
          'id': 'Khusus Siswa',
        }),
        icon: Icons.person,
      ),
    ];

    return TabSwitcher(
      tabController: _tabController,
      tabs: tabs,
      primaryColor: _getPrimaryColor(),
    );
  }

  // ========== SEARCH AND FILTER MENGGUNAKAN KOMPONEN ==========
  Widget _buildSearchAndFilter(LanguageProvider languageProvider) {
    return NewEnhancedSearchBar(
      controller: _searchController,
      onChanged: (value) => setState(() {}),
      hintText: languageProvider.getTranslatedText({
        'en': 'Search activities...',
        'id': 'Cari kegiatan...',
      }),
      showFilter: true,
      hasActiveFilter: _hasActiveFilter,
      onFilterPressed: _showFilterSheet,
      primaryColor: _getPrimaryColor(),
    );
  }

  // ========== FILTER SHEET MENGGUNAKAN KOMPONEN ==========
  void _showFilterSheet() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    // Siapkan konfigurasi filter
    final filterConfig = FilterConfig(
      sections: [
        FilterSection(
          key: 'date',
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
        ),
        FilterSection(
          key: 'subjects',
          title: languageProvider.getTranslatedText({
            'en': 'Subject',
            'id': 'Mata Pelajaran',
          }),
          options: _subjectList.map((subject) {
            return FilterOption(
              label: subject['nama'] ?? 'Subject',
              value: subject['id'].toString(),
            );
          }).toList(),
          multiSelect: true,
        ),
      ],
    );

    // Siapkan filter awal
    final initialFilters = <String, dynamic>{
      'date': _selectedDateFilter,
      'subjects': _selectedSubjectIds,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        config: filterConfig,
        initialFilters: initialFilters,
        onApplyFilters: (Map<String, dynamic> filters) {
          setState(() {
            _selectedDateFilter = filters['date'];
            _selectedSubjectIds = List<String>.from(filters['subjects'] ?? []);
            _checkActiveFilter();
          });
        },
      ),
    );
  }

  // ========== FILTER CHIPS SEPERTI PRESENCE TEACHER ==========
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

  Widget _buildActivityList() {
    final filteredActivities = _getFilteredActivities();

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return LoadingScreen(
            message: languageProvider.getTranslatedText({
              'en': 'Loading activities...',
              'id': 'Memuat kegiatan...',
            }),
          );
        }

        return Column(
          children: [
            // Search dan Filter Bar menggunakan komponen
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
                                backgroundColor: _getPrimaryColor().withValues(alpha: 0.7),
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
                            color: Colors.red.withValues(alpha: 0.8),
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

            if (filteredActivities.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${filteredActivities.length} ${languageProvider.getTranslatedText({'en': 'activities found', 'id': 'kegiatan ditemukan'})}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 8),

            Expanded(
              child: filteredActivities.isEmpty
                  ? EmptyState(
                      title: languageProvider.getTranslatedText({
                        'en': 'No Activities',
                        'id': 'Belum ada kegiatan',
                      }),
                      subtitle:
                          _searchController.text.isEmpty && !_hasActiveFilter
                          ? languageProvider.getTranslatedText({
                              'en': _currentTarget == 'umum'
                                  ? 'No activities for all students available'
                                  : 'No specific student activities available',
                              'id': _currentTarget == 'umum'
                                  ? 'Tidak ada kegiatan untuk semua siswa tersedia'
                                  : 'Tidak ada kegiatan khusus siswa tersedia',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'No search results found',
                              'id': 'Tidak ditemukan hasil pencarian',
                            }),
                      icon: Icons.event_note,
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: filteredActivities.length,
                      itemBuilder: (context, index) {
                        final activity = filteredActivities[index];
                        return _buildActivityCard(activity, context);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ========== CARD SEPERTI PENGUMUMAN ==========
  Widget _buildActivityCard(dynamic activity, BuildContext context) {
    final day = activity['hari']?.toString() ?? 'Unknown';
    final cardColor = _getDayColor(day);
    final isAssignment = activity['jenis'] == 'tugas';
    final isSpecificTarget = activity['target'] == 'khusus';
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    return GestureDetector(
      onTap: () {
        // TODO: Add detail navigation if needed
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 5,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Strip berwarna di pinggir kiri
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),

                  // Activity type badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAssignment ? Colors.orange : Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAssignment
                            ? languageProvider.getTranslatedText({
                                'en': 'ASSIGNMENT',
                                'id': 'TUGAS',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'MATERIAL',
                                'id': 'MATERI',
                              }),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header dengan judul kegiatan
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(right: 80), // Add padding to avoid badge overlap
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activity['judul'] ?? 'Judul Kegiatan',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                      maxLines: 3,  // Increase to 3 lines for long titles
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '${activity['mata_pelajaran_nama']} • ${activity['kelas_nama']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Tanggal dan Hari
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: cardColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.calendar_today,
                                color: cardColor,
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
                                      'en': 'Schedule',
                                      'id': 'Jadwal',
                                    }),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    '${activity['hari']} • ${_formatDate(activity['tanggal'])}',
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

                        // Deskripsi
                        if (activity['deskripsi'] != null &&
                            activity['deskripsi'].isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: cardColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.description,
                                      color: cardColor,
                                      size: 16,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Description',
                                            'id': 'Deskripsi',
                                          }),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 1),
                                        Text(
                                          activity['deskripsi'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                            ],
                          ),

                        // Materi/Bab
                        if (activity['bab_judul'] != null)
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: cardColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.menu_book,
                                  color: cardColor,
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
                                        'en': 'Learning Material',
                                        'id': 'Materi Pembelajaran',
                                      }),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      '${activity['bab_judul']}${activity['sub_bab_judul'] != null ? ' • ${activity['sub_bab_judul']}' : ''}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                        SizedBox(height: 12),

                        // Target dan Deadline
                        Row(
                          children: [
                            // Target
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSpecificTarget
                                    ? Colors.purple.shade50
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSpecificTarget
                                      ? Colors.purple
                                      : Colors.green,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSpecificTarget
                                        ? Icons.person
                                        : Icons.group,
                                    size: 12,
                                    color: isSpecificTarget
                                        ? Colors.purple
                                        : Colors.green,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    isSpecificTarget
                                        ? languageProvider.getTranslatedText({
                                            'en': 'Specific Student',
                                            'id': 'Khusus Siswa',
                                          })
                                        : languageProvider.getTranslatedText({
                                            'en': 'All Students',
                                            'id': 'Semua Siswa',
                                          }),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSpecificTarget
                                          ? Colors.purple
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Spacer(),

                            // Deadline untuk tugas
                            if (isAssignment && activity['batas_waktu'] != null)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.red,
                                    width: 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      _formatDate(activity['batas_waktu']),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        
                        SizedBox(height: 12),
                        
                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _buildActionButton(
                              icon: Icons.edit,
                              label: languageProvider.getTranslatedText({
                                'en': 'Edit',
                                'id': 'Edit',
                              }),
                              color: cardColor,
                              onPressed: () => _showEditActivityDialog(activity),
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.delete,
                              label: languageProvider.getTranslatedText({
                                'en': 'Delete',
                                'id': 'Hapus',
                              }),
                              color: Colors.red,
                              onPressed: () => _deleteActivity(activity, languageProvider),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              // Header dengan Tab
              _buildHeader(languageProvider),

              // Content Area
              Expanded(
                child: _buildActivityList(),
              ),
            ],
          ),

          // Floating Action Button untuk menambah kegiatan
          floatingActionButton: FloatingActionButton(
            onPressed: _showActivityTypeDialog,
            backgroundColor: _getPrimaryColor(),
            child: Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }

  // ========== HELPER METHODS ==========
  Color _getDayColor(String day) {
    return _dayColorMap[day] ?? Colors.grey;
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _getPrimaryColor(),
        _getPrimaryColor().withValues(alpha: 0.8),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // ========== API METHODS ==========
  Future<void> _loadMaterials(String subjectId) async {
    try {
      final materials = await ApiSubjectService.getMateri(
      );
      setState(() {
        _chapterList = materials;
        _subChapterList = [];
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error load materials: $e');
      }
    }
  }

  Future<void> _loadSubChapterMaterials(String chapterId) async {
    try {
      final subMaterials = await ApiSubjectService.getBabMateri(
        mataPelajaranId: chapterId,
      );
      setState(() {
        _subChapterList = subMaterials;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error load sub chapter materials: $e');
      }
    }
  }

  Future<void> _loadActivities() async {
    try {
      final activities = await ApiClassActivityService.getActivityByGuru(
        _teacherId,
      );
      setState(() {
        _activityList = activities;
        _isLoading = false;
      });
      
      // Auto show activity dialog if specified
      if (widget.autoShowActivityDialog) {
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            _showActivityTypeDialog();
          }
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (kDebugMode) {
        print('Error load activities: $e');
      }
    }
  }
}

// Form Dialog untuk Tambah Kegiatan (Tugas/Materi)
class AddActivityDialog extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final List<dynamic> scheduleList;
  final List<dynamic> subjectList;
  final List<dynamic> chapterList;
  final List<dynamic> subChapterList;
  final Function(String) onSubjectSelected;
  final Function(String) onChapterSelected;
  final VoidCallback onActivityAdded;
  final String initialTarget;
  final String activityType;
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialClassId;
  final String? initialBabId;
  final String? initialSubBabId;
  final bool isEditMode;
  final dynamic activityData;

  const AddActivityDialog({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.scheduleList,
    required this.subjectList,
    required this.chapterList,
    required this.subChapterList,
    required this.onSubjectSelected,
    required this.onChapterSelected,
    required this.onActivityAdded,
    required this.initialTarget,
    required this.activityType,
    this.initialDate,
    this.initialSubjectId,
    this.initialClassId,
    this.initialBabId,
    this.initialSubBabId,
    this.isEditMode = false,
    this.activityData,
  });

  @override
  State<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<AddActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final List<String> _selectedStudents = [];
  
  String? _selectedSubjectId;
  String? _selectedClassId;
  String? _selectedChapterId;
  String? _selectedSubChapterId;
  DateTime? _selectedDate;
  DateTime? _deadline;
  String? _selectedDay;
  bool _isSubmitting = false;
  List<dynamic> _studentList = [];
  
  // Bab & Sub Bab Materi
  List<dynamic> _babMateriList = [];
  List<dynamic> _subBabMateriList = [];
  String? _selectedBabId;
  String? _selectedSubBabId;
  bool _useMateriTitle = false; // Toggle: use bab/sub bab or manual input

  final List<String> _days = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];

  @override
  void initState() {
    super.initState();
    
    // Set initial values from widget parameters or use defaults
    _selectedDate = widget.initialDate ?? DateTime.now();
    _selectedDay = _days[_selectedDate!.weekday - 1];
    _selectedSubjectId = widget.initialSubjectId;
    _selectedClassId = widget.initialClassId;
    _selectedBabId = widget.initialBabId;
    _selectedSubBabId = widget.initialSubBabId;
    
    // If in edit mode, populate form with existing data
    if (widget.isEditMode && widget.activityData != null) {
      _judulController.text = widget.activityData['judul']?.toString() ?? '';
      _deskripsiController.text = widget.activityData['deskripsi']?.toString() ?? '';
      
      // Parse deadline if exists
      if (widget.activityData['batas_waktu'] != null) {
        _deadline = DateTime.tryParse(widget.activityData['batas_waktu'].toString());
      }
      
      // Load selected students if target is khusus
      if (widget.initialTarget == 'khusus' && widget.activityData['siswa_target'] != null) {
        final siswaTarget = widget.activityData['siswa_target'];
        if (siswaTarget is List) {
          _selectedStudents.addAll(siswaTarget.map((s) => s.toString()));
        }
      }
    }
    
    // If initial bab is provided, enable material title mode
    if (_selectedBabId != null || _selectedSubBabId != null) {
      _useMateriTitle = true;
    }
    
    // Debug logging
    if (kDebugMode) {
      print('===== AddActivityDialog INIT =====');
      print('Subject list count: ${widget.subjectList.length}');
      print('Schedule list count: ${widget.scheduleList.length}');
      print('Activity type: ${widget.activityType}');
      print('Initial target: ${widget.initialTarget}');
      print('Initial subject ID: $_selectedSubjectId');
      print('Initial class ID: $_selectedClassId');
      print('Initial bab ID: $_selectedBabId');
      print('Initial sub bab ID: $_selectedSubBabId');
      print('Use materi title: $_useMateriTitle');
      print('Initial date: $_selectedDate');
    }
    
    // If initial subject is provided, load its data
    if (_selectedSubjectId != null) {
      Future.delayed(Duration.zero, () {
        if (kDebugMode) {
          print('Loading initial data for subject: $_selectedSubjectId');
        }
        
        widget.onSubjectSelected(_selectedSubjectId!);
        // Load bab materi for the initial subject
        _loadBabMateri(_selectedSubjectId!).then((_) {
          // After bab list loaded, load sub bab if initial bab is provided
          if (_selectedBabId != null) {
            if (kDebugMode) {
              print('Loading sub bab for bab: $_selectedBabId');
            }
            _loadSubBabMateri(_selectedBabId!).then((_) {
              // After sub bab loaded, update title
              _updateTitleFromMateri();
            });
          } else {
            // Only bab selected, update title
            _updateTitleFromMateri();
          }
        });
        
        // If initial class is provided and target is 'khusus', load students
        if (_selectedClassId != null && widget.initialTarget == 'khusus') {
          if (kDebugMode) {
            print('Loading students for class: $_selectedClassId');
          }
          _loadStudents();
        }
      });
    } else {
      if (kDebugMode) {
        print('No initial subject ID - waiting for user selection');
      }
    }
    
    if (kDebugMode) {
      print('=====================================');
    }
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    if (_selectedClassId == null) return;
    
    try {
      final students = await ApiClassActivityService.getSiswaByKelas(_selectedClassId!);
      setState(() {
        _studentList = students;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading students: $e');
      }
    }
  }

  Future<void> _loadBabMateri(String mataPelajaranId) async {
    try {
      if (kDebugMode) {
        print('===== LOADING BAB MATERI =====');
        print('Mata Pelajaran ID: $mataPelajaranId');
      }
      
      final babList = await ApiSubjectService.getBabMateri(
        mataPelajaranId: mataPelajaranId,
      );
      
      if (kDebugMode) {
        print('API Response - Bab count: ${babList.length}');
        if (babList.isNotEmpty) {
          print('First item structure: ${babList[0]}');
          print('Available fields: ${babList[0].keys}');
          print('Judul Bab: ${babList[0]['judul_bab']}');
        }
      }
      
      setState(() {
        _babMateriList = babList;
        // Only reset if no initial values were provided
        if (widget.initialBabId == null) {
          _selectedBabId = null;
        }
        if (widget.initialSubBabId == null) {
          _selectedSubBabId = null;
        }
        // Only clear sub bab list if no initial sub bab
        if (widget.initialSubBabId == null) {
          _subBabMateriList = [];
        }
      });
      
      if (kDebugMode) {
        print('State updated - _babMateriList.length: ${_babMateriList.length}');
        print('Current _selectedBabId: $_selectedBabId');
        print('Current _selectedSubBabId: $_selectedSubBabId');
        print('=============================');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR loading bab materi: $e');
        print('Stack trace: ${StackTrace.current}');
      }
    }
  }

  Future<void> _loadSubBabMateri(String babId) async {
    try {
      if (kDebugMode) {
        print('===== LOADING SUB BAB MATERI =====');
        print('Bab ID: $babId');
      }
      
      final subBabList = await ApiSubjectService.getSubBabMateri(babId: babId);
      
      if (kDebugMode) {
        print('API Response - Sub Bab count: ${subBabList.length}');
        if (subBabList.isNotEmpty) {
          print('First item structure: ${subBabList[0]}');
          print('Available fields: ${subBabList[0].keys}');
          print('Judul Sub Bab: ${subBabList[0]['judul_sub_bab']}');
        }
      }
      
      setState(() {
        _subBabMateriList = subBabList;
        // Only reset if no initial value was provided
        if (widget.initialSubBabId == null) {
          _selectedSubBabId = null;
        }
      });
      
      if (kDebugMode) {
        print('State updated - _subBabMateriList.length: ${_subBabMateriList.length}');
        print('Current _selectedSubBabId: $_selectedSubBabId');
        print('==================================');
      }
    } catch (e) {
      if (kDebugMode) {
        print('ERROR loading sub bab materi: $e');
        print('Stack trace: ${StackTrace.current}');
      }
    }
  }

  String _getBabName(dynamic bab) {
    // Try multiple possible field names (backend returns 'judul_bab')
    return bab['judul_bab']?.toString() ?? 
           bab['nama']?.toString() ?? 
           bab['judul']?.toString() ?? 
           bab['title']?.toString() ??
           bab['name']?.toString() ??
           'Unknown';
  }

  String _getSubBabName(dynamic subBab) {
    // Try multiple possible field names (backend returns 'judul_sub_bab')
    return subBab['judul_sub_bab']?.toString() ?? 
           subBab['nama']?.toString() ?? 
           subBab['judul']?.toString() ?? 
           subBab['title']?.toString() ??
           subBab['name']?.toString() ??
           'Unknown';
  }

  void _updateTitleFromMateri() {
    String babName = '';
    String subBabName = '';
    
    // Get bab name if selected
    if (_selectedBabId != null && _babMateriList.isNotEmpty) {
      final bab = _babMateriList.firstWhere(
        (item) => item['id'].toString() == _selectedBabId,
        orElse: () => null,
      );
      if (bab != null) {
        babName = _getBabName(bab);
      }
    }
    
    // Get sub bab name if selected
    if (_selectedSubBabId != null && _subBabMateriList.isNotEmpty) {
      final subBab = _subBabMateriList.firstWhere(
        (item) => item['id'].toString() == _selectedSubBabId,
        orElse: () => null,
      );
      if (subBab != null) {
        subBabName = _getSubBabName(subBab);
      }
    }
    
    // Build title based on what's selected
    String title = '';
    if (babName.isNotEmpty && subBabName.isNotEmpty) {
      // Both selected: "Bab - Sub Bab"
      title = '$babName - $subBabName';
    } else if (babName.isNotEmpty) {
      // Only bab selected
      title = babName;
    } else if (subBabName.isNotEmpty) {
      // Only sub bab selected (edge case)
      title = subBabName;
    }
    
    if (title.isNotEmpty && title != 'Unknown') {
      _judulController.text = title;
    }
  }

  List<DropdownMenuItem<String>> _getUniqueClassItems() {
    final Map<String, Map<String, dynamic>> uniqueClasses = {};
    final now = DateTime.now();
    final currentDay = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][now.weekday - 1];
    
    if (kDebugMode) {
      print('Getting unique classes for subject: $_selectedSubjectId');
      print('Current day: $currentDay, Current time: ${now.hour}:${now.minute}');
      print('Target: ${widget.initialTarget}');
      print('Initial class ID from widget: ${widget.initialClassId}');
    }
    
    // Filter schedules by selected subject and deduplicate by class_id
    for (var schedule in widget.scheduleList) {
      if (schedule['mata_pelajaran_id'].toString() == _selectedSubjectId) {
        final kelasId = schedule['kelas_id'].toString();
        
        // Untuk target KHUSUS: tidak ada filter waktu, semua jadwal bisa dipilih
        if (widget.initialTarget == 'khusus') {
          if (!uniqueClasses.containsKey(kelasId)) {
            uniqueClasses[kelasId] = {
              'id': kelasId,
              'nama': schedule['kelas_nama'] ?? 'Unknown',
            };
          }
        } 
        // Untuk target UMUM
        else {
          // Jika ada initialClassId (dari teaching schedule), selalu include kelas tersebut
          if (widget.initialClassId != null && kelasId == widget.initialClassId) {
            if (!uniqueClasses.containsKey(kelasId)) {
              uniqueClasses[kelasId] = {
                'id': kelasId,
                'nama': schedule['kelas_nama'] ?? 'Unknown',
              };
              if (kDebugMode) {
                print('Added class from initialClassId: ${schedule['kelas_nama']}');
              }
            }
          }
          // Filter berdasarkan waktu untuk kelas lainnya
          else {
            final scheduleDay = schedule['hari_nama']?.toString() ?? '';
            final jamMulai = schedule['jam_mulai']?.toString() ?? '';
            
            if (kDebugMode) {
              print('Schedule: ${schedule['kelas_nama']}, Day: $scheduleDay, Start: $jamMulai');
            }
            
            // Check if schedule is today
            if (scheduleDay == currentDay && jamMulai.isNotEmpty) {
              try {
                // Parse jam mulai (format: HH:mm:ss atau HH:mm)
                final startTimeParts = jamMulai.split(':');
                final startHour = int.parse(startTimeParts[0]);
                final startMinute = int.parse(startTimeParts[1]);
                
                // Buat DateTime untuk jam mulai hari ini
                final scheduleStartTime = DateTime(
                  now.year, now.month, now.day, 
                  startHour, startMinute
                );
                
                // Batas waktu: jam mulai + 23 jam
                final scheduleEndLimit = scheduleStartTime.add(Duration(hours: 23));
                
                // Cek apakah waktu sekarang ada di antara jam mulai dan jam mulai + 23 jam
                if (!now.isBefore(scheduleStartTime) && now.isBefore(scheduleEndLimit)) {
                  if (!uniqueClasses.containsKey(kelasId)) {
                    uniqueClasses[kelasId] = {
                      'id': kelasId,
                      'nama': schedule['kelas_nama'] ?? 'Unknown',
                    };
                  }
                }
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing time: $e');
                }
              }
            }
          }
        }
      }
    }
    
    if (kDebugMode) {
      print('Unique classes found: ${uniqueClasses.length}');
    }
    
    // Convert to dropdown items
    return uniqueClasses.values.map((kelas) {
      return DropdownMenuItem<String>(
        value: kelas['id'].toString(),
        child: Text(kelas['nama'] ?? 'Unknown'),
      );
    }).toList();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjectId == null || _selectedClassId == null) {
      _showError('Pilih mata pelajaran dan kelas terlebih dahulu');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      
      final data = {
        'guru_id': widget.teacherId,
        'mata_pelajaran_id': _selectedSubjectId,
        'kelas_id': _selectedClassId,
        'judul': _judulController.text,
        'deskripsi': _deskripsiController.text,
        'jenis': widget.activityType,
        'target': widget.initialTarget,
        'tanggal': _selectedDate!.toIso8601String().split('T')[0],
        'hari': _selectedDay,
      };

      // Save bab_id and sub_bab_id if selected from materi
      if (_useMateriTitle && _selectedBabId != null) {
        data['bab_id'] = _selectedBabId;
      } else if (_selectedChapterId != null) {
        // Fallback to old chapter props if exists
        data['bab_id'] = _selectedChapterId;
      }

      if (_useMateriTitle && _selectedSubBabId != null) {
        data['sub_bab_id'] = _selectedSubBabId;
      } else if (_selectedSubChapterId != null) {
        // Fallback to old sub chapter props if exists
        data['sub_bab_id'] = _selectedSubChapterId;
      }

      if (_deadline != null && widget.activityType == 'tugas') {
        data['batas_waktu'] = _deadline!.toIso8601String();
      }

      // Tambahkan siswa target untuk kegiatan khusus
      final Map<String, dynamic> requestData = Map<String, dynamic>.from(data);
      if (widget.initialTarget == 'khusus' && _selectedStudents.isNotEmpty) {
        requestData['siswa_target'] = _selectedStudents;
      }

      // Call appropriate API based on mode
      if (widget.isEditMode && widget.activityData != null) {
        // Update existing activity
        await ApiClassActivityService.updateKegiatan(
          widget.activityData['id'].toString(),
          requestData,
        );
      } else {
        // Create new activity
        await ApiClassActivityService.tambahKegiatan(requestData);
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onActivityAdded();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditMode
                ? languageProvider.getTranslatedText({
                    'en': 'Activity updated successfully',
                    'id': 'Kegiatan berhasil diperbarui',
                  })
                : languageProvider.getTranslatedText({
                    'en': 'Activity added successfully',
                    'id': 'Kegiatan berhasil ditambahkan',
                  }),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isAssignment = widget.activityType == 'tugas';
    final primaryColor = isAssignment ? Colors.orange : Colors.blue;
    
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAssignment ? Icons.assignment : Icons.book,
              color: primaryColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isEditMode
                  ? (isAssignment
                      ? languageProvider.getTranslatedText({
                          'en': 'Edit Assignment',
                          'id': 'Edit Tugas',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Edit Material',
                          'id': 'Edit Materi',
                        }))
                  : (isAssignment
                      ? languageProvider.getTranslatedText({
                          'en': 'Add Assignment',
                          'id': 'Tambah Tugas',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Add Material',
                          'id': 'Tambah Materi',
                        })),
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Box
              Container(
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.initialTarget == 'khusus' 
                          ? Icons.people 
                          : Icons.schedule,
                      color: primaryColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.initialTarget == 'khusus'
                            ? languageProvider.getTranslatedText({
                                'en': 'SPECIFIC: You can select any class anytime.',
                                'id': 'KHUSUS: Anda dapat memilih kelas kapan saja.',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'GENERAL: Only classes from start time to +23 hours are available.',
                                'id': 'UMUM: Hanya kelas dari jam mulai sampai +23 jam yang tersedia.',
                              }),
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Mata Pelajaran
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})} *',
                  prefixIcon: Icon(Icons.book),
                  border: OutlineInputBorder(),
                ),
                value: _selectedSubjectId,
                isExpanded: true,
                items: widget.subjectList.isEmpty
                    ? null
                    : widget.subjectList.map((subject) {
                        return DropdownMenuItem<String>(
                          value: subject['id'].toString(),
                          child: Text(subject['nama'] ?? 'Unknown'),
                        );
                      }).toList(),
                onChanged: widget.subjectList.isEmpty
                    ? null
                    : (value) {
                        setState(() {
                          _selectedSubjectId = value;
                          _selectedClassId = null;
                        });
                        if (value != null) {
                          widget.onSubjectSelected(value);
                          _loadBabMateri(value); // Load bab materi for selected subject
                        }
                      },
                validator: (value) => value == null
                    ? languageProvider.getTranslatedText({'en': 'Required', 'id': 'Wajib diisi'})
                    : null,
                hint: Text(widget.subjectList.isEmpty
                    ? languageProvider.getTranslatedText({
                        'en': 'No subjects available',
                        'id': 'Tidak ada mata pelajaran',
                      })
                    : languageProvider.getTranslatedText({
                        'en': 'Select Subject',
                        'id': 'Pilih Mata Pelajaran',
                      })),
              ),
              if (widget.subjectList.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    languageProvider.getTranslatedText({
                      'en': 'No teaching subjects found. Please check your schedule.',
                      'id': 'Tidak ada mata pelajaran mengajar. Silakan periksa jadwal Anda.',
                    }),
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              SizedBox(height: 12),

              // Kelas
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})} *',
                  prefixIcon: Icon(Icons.class_),
                  border: OutlineInputBorder(),
                ),
                value: _selectedClassId,
                isExpanded: true,
                items: _selectedSubjectId == null
                    ? null
                    : _getUniqueClassItems(),
                onChanged: _selectedSubjectId == null
                    ? null
                    : (value) {
                        setState(() {
                          _selectedClassId = value;
                        });
                        if (widget.initialTarget == 'khusus') {
                          _loadStudents();
                        }
                      },
                validator: (value) => value == null
                    ? languageProvider.getTranslatedText({'en': 'Required', 'id': 'Wajib diisi'})
                    : null,
                hint: Text(_selectedSubjectId == null
                    ? languageProvider.getTranslatedText({
                        'en': 'Select subject first',
                        'id': 'Pilih mata pelajaran dulu',
                      })
                    : languageProvider.getTranslatedText({
                        'en': 'Select Class',
                        'id': 'Pilih Kelas',
                      })),
              ),
              if (_selectedSubjectId != null && _getUniqueClassItems().isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4, left: 12),
                  child: Text(
                    widget.initialTarget == 'khusus'
                        ? languageProvider.getTranslatedText({
                            'en': 'No classes found for this subject.',
                            'id': 'Tidak ada kelas untuk mata pelajaran ini.',
                          })
                        : languageProvider.getTranslatedText({
                            'en': 'No active classes now. You can fill from class start time until +23 hours.',
                            'id': 'Tidak ada kelas aktif saat ini. Anda dapat mengisi dari jam pelajaran mulai sampai +23 jam.',
                          }),
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              SizedBox(height: 12),

              // Toggle: Pilih dari Materi atau Tulis Manual
              Row(
                children: [
                  Icon(Icons.title, size: 20, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Choose from material',
                      'id': 'Pilih dari materi',
                    }),
                    style: TextStyle(fontSize: 14),
                  ),
                  Spacer(),
                  Switch(
                    value: _useMateriTitle,
                    onChanged: _selectedSubjectId == null ? null : (value) {
                      setState(() {
                        _useMateriTitle = value;
                        if (!value) {
                          // Reset when switching to manual
                          _selectedBabId = null;
                          _selectedSubBabId = null;
                        }
                      });
                    },
                    activeThumbColor: primaryColor,
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Dropdown Bab Materi (if useMateriTitle = true)
              if (_useMateriTitle) ...[
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: languageProvider.getTranslatedText({
                      'en': 'Chapter',
                      'id': 'Bab Materi',
                    }),
                    prefixIcon: Icon(Icons.menu_book),
                    border: OutlineInputBorder(),
                  ),
                  value: _babMateriList.isEmpty 
                      ? null 
                      : (_babMateriList.any((bab) => bab['id'].toString() == _selectedBabId) 
                          ? _selectedBabId 
                          : null),
                  isExpanded: true,
                  items: _babMateriList.isEmpty
                      ? null
                      : _babMateriList.map((bab) {
                          return DropdownMenuItem<String>(
                            value: bab['id'].toString(),
                            child: Text(_getBabName(bab)),
                          );
                        }).toList(),
                  onChanged: _babMateriList.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            _selectedBabId = value;
                            _selectedSubBabId = null;
                          });
                          if (value != null) {
                            _loadSubBabMateri(value);
                            _updateTitleFromMateri();
                          }
                        },
                  hint: Text(languageProvider.getTranslatedText({
                    'en': _babMateriList.isEmpty ? 'Loading chapters...' : 'Select Chapter',
                    'id': _babMateriList.isEmpty ? 'Memuat bab...' : 'Pilih Bab',
                  })),
                ),
                SizedBox(height: 12),
              ],

              // Dropdown Sub Bab Materi (if bab is selected)
              if (_useMateriTitle && _selectedBabId != null) ...[
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: languageProvider.getTranslatedText({
                      'en': 'Sub Chapter',
                      'id': 'Sub Bab Materi',
                    }),
                    prefixIcon: Icon(Icons.article),
                    border: OutlineInputBorder(),
                  ),
                  value: _subBabMateriList.isEmpty
                      ? null
                      : (_subBabMateriList.any((subBab) => subBab['id'].toString() == _selectedSubBabId) 
                          ? _selectedSubBabId 
                          : null),
                  isExpanded: true,
                  items: _subBabMateriList.isEmpty
                      ? null
                      : _subBabMateriList.map((subBab) {
                          return DropdownMenuItem<String>(
                            value: subBab['id'].toString(),
                            child: Text(_getSubBabName(subBab)),
                          );
                        }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubBabId = value;
                    });
                    _updateTitleFromMateri();
                  },
                  hint: Text(languageProvider.getTranslatedText({
                    'en': _subBabMateriList.isEmpty ? 'Loading sub chapters...' : 'Select Sub Chapter (optional)',
                    'id': _subBabMateriList.isEmpty ? 'Memuat sub bab...' : 'Pilih Sub Bab (opsional)',
                  })),
                ),
                SizedBox(height: 12),
              ],

              // Judul Field
              TextFormField(
                controller: _judulController,
                decoration: InputDecoration(
                  labelText: '${languageProvider.getTranslatedText({'en': 'Title', 'id': 'Judul'})} *',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                  helperText: _useMateriTitle 
                      ? languageProvider.getTranslatedText({
                          'en': 'Auto-filled from chapter/sub-chapter',
                          'id': 'Otomatis dari bab/sub bab',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Enter title manually',
                          'id': 'Tulis judul manual',
                        }),
                ),
                readOnly: _useMateriTitle && (_selectedBabId != null || _selectedSubBabId != null),
                validator: (value) => value == null || value.isEmpty
                    ? languageProvider.getTranslatedText({'en': 'Required', 'id': 'Wajib diisi'})
                    : null,
              ),
              SizedBox(height: 12),

              // Deskripsi
              TextFormField(
                controller: _deskripsiController,
                decoration: InputDecoration(
                  labelText: languageProvider.getTranslatedText({'en': 'Description', 'id': 'Deskripsi'}),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 12),

              // Tanggal
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.calendar_today),
                title: Text(languageProvider.getTranslatedText({'en': 'Date', 'id': 'Tanggal'})),
                subtitle: Text(_selectedDate != null
                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                    : 'Pilih tanggal'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _selectedDate = date;
                      _selectedDay = _days[date.weekday - 1];
                    });
                  }
                },
              ),

              // Batas Waktu (hanya untuk Tugas)
              if (isAssignment) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.alarm),
                  title: Text(languageProvider.getTranslatedText({'en': 'Deadline', 'id': 'Batas Waktu'})),
                  subtitle: Text(_deadline != null
                      ? '${_deadline!.day}/${_deadline!.month}/${_deadline!.year} ${_deadline!.hour}:${_deadline!.minute.toString().padLeft(2, '0')}'
                      : 'Pilih batas waktu (opsional)'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _deadline ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _deadline = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],

              // Pilih Siswa (hanya untuk target khusus)
              if (widget.initialTarget == 'khusus' && _selectedClassId != null) ...[
                SizedBox(height: 12),
                Text(
                  languageProvider.getTranslatedText({'en': 'Select Students', 'id': 'Pilih Siswa'}),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _studentList.isEmpty
                      ? Center(child: Text('Tidak ada siswa'))
                      : ListView.builder(
                          itemCount: _studentList.length,
                          itemBuilder: (context, index) {
                            final student = _studentList[index];
                            final studentId = student['id'].toString();
                            return CheckboxListTile(
                              title: Text(student['nama'] ?? 'Unknown'),
                              subtitle: Text(student['nis'] ?? ''),
                              value: _selectedStudents.contains(studentId),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedStudents.add(studentId);
                                  } else {
                                    _selectedStudents.remove(studentId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(languageProvider.getTranslatedText({
            'en': 'Cancel',
            'id': 'Batal',
          })),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  widget.isEditMode
                      ? languageProvider.getTranslatedText({
                          'en': 'Update',
                          'id': 'Simpan Perubahan',
                        })
                      : languageProvider.getTranslatedText({
                          'en': 'Add',
                          'id': 'Tambah',
                        }),
                  style: TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}