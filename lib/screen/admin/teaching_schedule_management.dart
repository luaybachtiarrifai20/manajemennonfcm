import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/confirmation_dialog.dart';
import 'package:manajemensekolah/components/conflict_resolution_dialog.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/components/schedule_form_dialog.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/excel_schedule_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class TeachingScheduleManagementScreen extends StatefulWidget {
  const TeachingScheduleManagementScreen({super.key});

  @override
  TeachingScheduleManagementScreenState createState() =>
      TeachingScheduleManagementScreenState();
}

class TeachingScheduleManagementScreenState
    extends State<TeachingScheduleManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ApiClassService apiServiceClass = ApiClassService();
  final ApiSubjectService _apiSubjectService = ApiSubjectService();
  final ApiTeacherService apiTeacherService = ApiTeacherService();

  List<dynamic> _scheduleList = [];
  List<dynamic> _teacherList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _hariList = [];
  List<dynamic> _semesterList = [];
  List<dynamic> _jamPelajaranList = [];

  bool _isLoading = true;
  String _selectedSemester = '1'; // Will be set by _setDefaultAcademicPeriod()
  String _selectedAcademicYear =
      '2024/2025'; // Will be set by _setDefaultAcademicPeriod()
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _paginationMeta;

  // Filter state (Backend filtering)
  String? _selectedGuruId; // Filter by teacher
  String? _selectedClassId; // Filter by class
  String? _selectedHariId; // Filter by day
  String? _selectedFilterConflict;
  String? _selectedFilterSemester;
  String? _selectedFilterAcademicYear;
  bool _hasActiveFilter = false;

  // Filter Options (from backend)
  List<dynamic> _availableTeachers = [];
  List<dynamic> _availableClasses = [];
  List<dynamic> _availableDays = [];
  List<dynamic> _availableSemesters = [];

  // Search debounce
  Timer? _searchDebounce;

  // Tambahan untuk tampilan tabel
  bool _showTableView = false;
  List<ScheduleGridData> _gridData = [];
  ScheduleDataSource? _scheduleDataSource;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    // Listen to search changes with debounce
    _searchController.addListener(_onSearchChanged);

    // Set default academic year and semester based on current date
    _setDefaultAcademicPeriod();

    _loadFilterOptions();
    _loadData();
  }

  /// Calculate current academic year based on current date
  /// Academic year runs from July to June
  /// Example: Oct 2025 -> 2025/2026
  String _getCurrentAcademicYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // If month is July (7) or later, academic year is currentYear/nextYear
    // If month is before July, academic year is previousYear/currentYear
    if (currentMonth >= 7) {
      return '$currentYear/${currentYear + 1}';
    } else {
      return '${currentYear - 1}/$currentYear';
    }
  }

  /// Determine if current period is odd semester (Ganjil) or even semester (Genap)
  /// Semester 1 (Ganjil): July - December
  /// Semester 2 (Genap): January - June
  bool _isCurrentSemesterOdd() {
    final now = DateTime.now();
    final currentMonth = now.month;

    // Semester 1 (Ganjil) = July to December (months 7-12)
    // Semester 2 (Genap) = January to June (months 1-6)
    return currentMonth >= 7 && currentMonth <= 12;
  }

  /// Find semester ID from semester list based on current period
  String? _findCurrentSemesterId() {
    if (_semesterList.isEmpty) return null;

    final isOdd = _isCurrentSemesterOdd();

    // Try to find semester by name containing 'Ganjil' or 'Genap'
    for (var semester in _semesterList) {
      final semesterName = semester['nama']?.toString().toLowerCase() ?? '';

      if (isOdd &&
          (semesterName.contains('ganjil') || semesterName.contains('1'))) {
        return semester['id'].toString();
      } else if (!isOdd &&
          (semesterName.contains('genap') || semesterName.contains('2'))) {
        return semester['id'].toString();
      }
    }

    // If not found by name, return first semester as fallback
    return _semesterList.isNotEmpty ? _semesterList[0]['id'].toString() : '1';
  }

  /// Set default academic period based on current date
  void _setDefaultAcademicPeriod() {
    _selectedAcademicYear = _getCurrentAcademicYear();
    // Semester will be set after loading semester list
  }

  /// Update semester selection after semester list is loaded
  void _updateCurrentSemester() {
    final semesterId = _findCurrentSemesterId();
    if (semesterId != null && semesterId != _selectedSemester) {
      // Semester changed, need to reload data
      setState(() {
        _selectedSemester = semesterId;
      });
      // Reload data with correct semester
      _loadData();
    }
  }

  /// Generate list of academic years (current year ± 2 years)
  /// Example: If current is 2025/2026, returns [2023/2024, 2024/2025, 2025/2026, 2026/2027, 2027/2028]
  List<String> _getAcademicYearOptions() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Determine the starting year of current academic year
    final academicStartYear = currentMonth >= 7 ? currentYear : currentYear - 1;

    // Generate list: 2 years before to 2 years after current academic year
    final years = <String>[];
    for (int i = -2; i <= 2; i++) {
      final startYear = academicStartYear + i;
      final endYear = startYear + 1;
      years.add('$startYear/$endYear');
    }

    return years;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Detect when user scrolls near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreData();
      }
    }
  }

  void _onSearchChanged() {
    // Cancel previous timer
    _searchDebounce?.cancel();

    // Set new timer (500ms debounce)
    _searchDebounce = Timer(Duration(milliseconds: 500), () {
      setState(() {
        _currentPage = 1;
      });
      _loadData();
    });
  }

  Future<void> _loadFilterOptions() async {
    try {
      final response = await ApiScheduleService.getScheduleFilterOptions();

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _availableTeachers = response['data']['teachers'] ?? [];
          _availableClasses = response['data']['classes'] ?? [];
          _availableDays = response['data']['days'] ?? [];
          _availableSemesters = response['data']['semesters'] ?? [];
        });
        print('✅ Schedule filter options loaded');
      }
    } catch (e) {
      print('Error loading filter options: $e');
      // Continue with empty options - not critical error
    }
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadData({bool resetPage = true}) async {
    try {
      if (resetPage) {
        setState(() {
          _isLoading = true;
          _currentPage = 1;
          _hasMoreData = true;
          _scheduleList = []; // Reset list
        });
      }

      // Gunakan nilai semester dan tahun ajaran yang sudah diset
      final semesterToUse = _selectedFilterSemester ?? _selectedSemester;
      final academicYearToUse =
          _selectedFilterAcademicYear ?? _selectedAcademicYear;

      // Load with pagination and backend filtering
      final results = await Future.wait([
        ApiScheduleService.getSchedulesPaginated(
          page: _currentPage,
          limit: _perPage,
          guruId: _selectedGuruId,
          classId: _selectedClassId,
          hariId: _selectedHariId,
          semesterId: semesterToUse,
          tahunAjaran: academicYearToUse,
          search: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
        ),
        apiTeacherService.getTeacher(),
        _apiSubjectService.getSubject(),
        apiServiceClass.getClass(),
        ApiScheduleService.getHari(),
        ApiScheduleService.getSemester(),
        ApiScheduleService.getJamPelajaran(),
      ]);

      if (!mounted) return;

      final scheduleResponse = results[0] as Map<String, dynamic>;
      final teacher = results[1] as List<dynamic>;
      final subject = results[2] as List<dynamic>;
      final classData = results[3] as List<dynamic>;
      final hari = results[4] as List<dynamic>;
      final semester = results[5] as List<dynamic>;
      final jamPelajaran = results[6] as List<dynamic>;

      setState(() {
        _scheduleList = scheduleResponse['data'] ?? [];
        _teacherList = teacher;
        _subjectList = subject;
        _classList = classData;
        _hariList = hari;
        _semesterList = semester;
        _jamPelajaranList = jamPelajaran;
        _paginationMeta = scheduleResponse['pagination'];
        _hasMoreData =
            scheduleResponse['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
      });

      // Update grid data
      _updateGridData();

      _animationController.forward();

      // Update semester selection based on loaded semester list
      // This may trigger reload if semester is different
      if (_semesterList.isNotEmpty) {
        _updateCurrentSemester();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading data: $e');
      }

      if (!mounted) return;

      _showErrorSnackBar('Failed to load data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      // Gunakan nilai semester dan tahun ajaran yang sudah diset
      final semesterToUse = _selectedFilterSemester ?? _selectedSemester;
      final academicYearToUse =
          _selectedFilterAcademicYear ?? _selectedAcademicYear;

      // Load next page
      final response = await ApiScheduleService.getSchedulesPaginated(
        page: _currentPage,
        limit: _perPage,
        guruId: _selectedGuruId,
        classId: _selectedClassId,
        hariId: _selectedHariId,
        semesterId: semesterToUse,
        tahunAjaran: academicYearToUse,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        // Append new data to existing list
        _scheduleList.addAll(response['data'] ?? []);
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      // Update grid data
      _updateGridData();

      print(
        '✅ Loaded more schedules: Page $_currentPage, Total items: ${_scheduleList.length}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });

      if (kDebugMode) {
        print('Error loading more data: $e');
      }
    }
  }

  Future<void> _importFromExcel() async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);

        await ApiScheduleService.importSchedulesFromExcel(
          File(result.files.single.path!),
        );

        // Reload data
        _loadData();

        if (!mounted) return;
        _showInfoSnackBar(
          languageProvider.getTranslatedText({
            'en': 'Import successful',
            'id': 'Import berhasil',
          }),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(
        languageProvider.getTranslatedText({
          'en': 'Failed to import file: $e',
          'id': 'Gagal mengimpor file: $e',
        }),
      );
    }
  }

  // Export jadwal ke Excel
  Future<void> _exportToExcel() async {
    try {
      await ExcelScheduleService.exportSchedulesToExcel(
        schedules: _scheduleList,
        context: context,
      );
    } catch (e) {
      _showErrorSnackBar('Export failed: $e');
    }
  }

  // Download template
  Future<void> _downloadTemplate() async {
    try {
      await ExcelScheduleService.downloadTemplate(context);
    } catch (e) {
      _showErrorSnackBar('Download template failed: $e');
    }
  }

  void _updateGridData() {
    _gridData = _generateTimetableData();
    _scheduleDataSource = ScheduleDataSource(_gridData);
  }

  // Method baru untuk menghasilkan data timetable dalam format yang diinginkan
  List<ScheduleGridData> _generateTimetableData() {
    final List<ScheduleGridData> timetableData = [];

    // Group schedules by day and class
    final Map<String, Map<String, Map<String, dynamic>>> dayClassScheduleMap =
        {};

    // Initialize the structure
    for (var day in _hariList) {
      final dayName = day['nama'] ?? '';
      dayClassScheduleMap[dayName] = {};

      for (var classItem in _classList) {
        final className = classItem['nama'] ?? '';
        dayClassScheduleMap[dayName]![className] = {};

        // Initialize all time slots as empty
        for (var jam in _jamPelajaranList) {
          final timeSlot =
              '${jam['jam_mulai'] ?? ''}-${jam['jam_selesai'] ?? ''}';
          dayClassScheduleMap[dayName]![className]![timeSlot] = null;
        }
      }
    }

    // Fill the structure with actual schedules
    for (var schedule in _getFilteredSchedules()) {
      final dayName = schedule['hari_nama'] ?? '';
      final className = schedule['kelas_nama'] ?? '';
      final timeSlot =
          '${schedule['jam_mulai'] ?? ''}-${schedule['jam_selesai'] ?? ''}';
      final subjectName = schedule['mata_pelajaran_nama'] ?? '';
      final teacherName = schedule['guru_nama'] ?? '';

      if (dayClassScheduleMap.containsKey(dayName) &&
          dayClassScheduleMap[dayName]!.containsKey(className)) {
        dayClassScheduleMap[dayName]![className]![timeSlot] = {
          'subject': subjectName,
          'teacher': teacherName,
        };
      }
    }

    // Convert to grid data format
    for (var jam in _jamPelajaranList) {
      final timeSlot = '${jam['jam_mulai'] ?? ''}-${jam['jam_selesai'] ?? ''}';

      // Create a row for each time slot
      for (var day in _hariList) {
        final dayName = day['nama'] ?? '';

        for (var classItem in _classList) {
          final className = classItem['nama'] ?? '';

          final scheduleInfo =
              dayClassScheduleMap[dayName]?[className]?[timeSlot];

          timetableData.add(
            ScheduleGridData(
              id: '${timeSlot}_${dayName}_$className',
              waktu: timeSlot,
              hari: dayName,
              kelas: className,
              mataPelajaran: scheduleInfo?['subject'] ?? '-',
              guru: scheduleInfo?['teacher'] ?? '',
            ),
          );
        }
      }
    }

    return timetableData;
  }

  String _getGradeLevel(String classId) {
    try {
      final kelas = _classList.firstWhere(
        (k) => k['id'] == classId,
        orElse: () => {},
      );
      return kelas['grade_level']?.toString() ?? '-';
    } catch (e) {
      return '-';
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
                'Failed to load data:',
                'Gagal memuat data:',
              ),
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': message,
              'id': message.replaceAll('successfully', 'berhasil'),
            }),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _addSchedule() async {
    final result = await showDialog(
      context: context,
      builder: (context) => ScheduleFormDialog(
        teacherList: _teacherList,
        subjectList: _subjectList,
        classList: _classList,
        hariList: _hariList,
        semesterList: _semesterList,
        jamPelajaranList: _jamPelajaranList,
        semester: _selectedSemester,
        academicYear: _selectedAcademicYear,
        apiService: _apiService,
        apiTeacherService: apiTeacherService,
      ),
    );

    if (result != null) {
      await _checkAndResolveConflicts(result);
    }
  }

  Future<void> _editSchedule(dynamic schedule) async {
    final result = await showDialog(
      context: context,
      builder: (context) => ScheduleFormDialog(
        teacherList: _teacherList,
        subjectList: _subjectList,
        classList: _classList,
        hariList: _hariList,
        semesterList: _semesterList,
        jamPelajaranList: _jamPelajaranList,
        semester: _selectedSemester,
        academicYear: _selectedAcademicYear,
        schedule: schedule,
        apiService: _apiService,
        apiTeacherService: apiTeacherService,
      ),
    );

    if (result != null) {
      await _checkAndResolveConflicts(
        result,
        editingScheduleId: schedule['id'],
      );
    }
  }

  Future<void> _deleteSchedule(String id) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return ConfirmationDialog(
            title: languageProvider.getTranslatedText({
              'en': 'Delete Schedule',
              'id': 'Hapus Jadwal',
            }),
            content: languageProvider.getTranslatedText({
              'en': 'Are you sure you want to delete this schedule?',
              'id': 'Apakah Anda yakin ingin menghapus jadwal ini?',
            }),
            confirmText: languageProvider.getTranslatedText({
              'en': 'Delete',
              'id': 'Hapus',
            }),
            confirmColor: Colors.red,
          );
        },
      ),
    );

    if (confirmed == true) {
      try {
        await ApiScheduleService.deleteSchedule(id);
        _showSuccessSnackBar('Schedule successfully deleted');
        _loadData();
      } catch (e) {
        _showErrorSnackBar('Failed to delete schedule: $e');
      }
    }
  }

  Future<void> _checkAndResolveConflicts(
    Map<String, dynamic> newScheduleData, {
    String? editingScheduleId,
  }) async {
    try {
      final conflicts = await ApiScheduleService.getConflictingSchedules(
        hariId: newScheduleData['hari_id'],
        classId: newScheduleData['kelas_id'],
        semesterId: newScheduleData['semester_id'],
        tahunAjaran: newScheduleData['tahun_ajaran'],
        jamPelajaranId: newScheduleData['jam_pelajaran_id'],
        excludeScheduleId: editingScheduleId,
      );

      if (conflicts.isNotEmpty) {
        if (!mounted) return;
        final result = await showDialog<String>(
          context: context,
          builder: (context) => ConflictResolutionDialog(
            conflictingSchedules: conflicts,
            onDeleteConfirmed: (scheduleId) =>
                Navigator.pop(context, scheduleId),
            onCancel: () => Navigator.pop(context),
          ),
        );

        if (result != null) {
          await _deleteSchedule(result);

          if (editingScheduleId != null) {
            await ApiScheduleService.updateSchedule(
              editingScheduleId,
              newScheduleData,
            );
          } else {
            await ApiScheduleService.addSchedule(newScheduleData);
          }

          _showSuccessSnackBar('Schedule successfully saved');
          _loadData();
        }
      } else {
        if (editingScheduleId != null) {
          await ApiScheduleService.updateSchedule(
            editingScheduleId,
            newScheduleData,
          );
        } else {
          await ApiScheduleService.addSchedule(newScheduleData);
        }

        _showSuccessSnackBar('Schedule successfully saved');
        _loadData();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to save schedule: $e');
    }
  }

  void _onSemesterChanged(String semesterId) {
    setState(() {
      _selectedSemester = semesterId;
      _isLoading = true;
    });
    _loadData();
  }

  void _onAcademicYearChanged(String academicYear) {
    setState(() {
      _selectedAcademicYear = academicYear;
      _isLoading = true;
    });
    _loadData();
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor()],
    );
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedFilterConflict != null ||
          (_selectedFilterSemester != null &&
              _selectedFilterSemester != _selectedSemester) ||
          (_selectedFilterAcademicYear != null &&
              _selectedFilterAcademicYear != _selectedAcademicYear);
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedFilterConflict = null;
      _selectedFilterSemester =
          _selectedSemester; // Kembali ke semester default
      _selectedFilterAcademicYear =
          _selectedAcademicYear; // Kembali ke tahun ajaran default
    });
    _checkActiveFilter();
    _loadData(); // Reload data untuk menampilkan data default
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedFilterConflict != null) {
      final label = _selectedFilterConflict == 'With Conflicts'
          ? languageProvider.getTranslatedText({
              'en': 'With Conflicts',
              'id': 'Dengan Konflik',
            })
          : languageProvider.getTranslatedText({
              'en': 'Without Conflicts',
              'id': 'Tanpa Konflik',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Conflict', 'id': 'Konflik'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedFilterConflict = null;
            _checkActiveFilter();
          });
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

    String? tempSelectedConflict = _selectedFilterConflict;
    // Gunakan nilai default jika filter belum diset
    String? tempSelectedSemester = _selectedFilterSemester ?? _selectedSemester;
    String? tempSelectedAcademicYear =
        _selectedFilterAcademicYear ?? _selectedAcademicYear;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Filter',
                        'id': 'Filter',
                      }),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempSelectedConflict = null;
                          // Reset ke nilai default saat ini
                          tempSelectedSemester = _selectedSemester;
                          tempSelectedAcademicYear = _selectedAcademicYear;
                        });
                      },
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Reset',
                          'id': 'Reset',
                        }),
                        style: TextStyle(color: _getPrimaryColor()),
                      ),
                    ),
                  ],
                ),
              ),
              // Filter Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Conflict Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Conflict Status',
                          'id': 'Status Konflik',
                        }),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['With Conflicts', 'Without Conflicts'].map((
                          status,
                        ) {
                          final isSelected = tempSelectedConflict == status;
                          final label = status == 'With Conflicts'
                              ? languageProvider.getTranslatedText({
                                  'en': 'With Conflicts',
                                  'id': 'Dengan Konflik',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'Without Conflicts',
                                  'id': 'Tanpa Konflik',
                                });
                          return FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedConflict = selected ? status : null;
                              });
                            },
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: _getPrimaryColor().withOpacity(0.2),
                            checkmarkColor: _getPrimaryColor(),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? _getPrimaryColor()
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 24),

                      // Semester Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Semester',
                          'id': 'Semester',
                        }),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _semesterList.map<Widget>((semester) {
                          final semesterId = semester['id'].toString();
                          final semesterName =
                              semester['nama'] ?? 'Semester $semesterId';
                          final isSelected = tempSelectedSemester == semesterId;
                          return FilterChip(
                            label: Text(semesterName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedSemester = selected
                                    ? semesterId
                                    : null;
                              });
                            },
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: _getPrimaryColor().withOpacity(0.2),
                            checkmarkColor: _getPrimaryColor(),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? _getPrimaryColor()
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 24),

                      // Academic Year Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Academic Year',
                          'id': 'Tahun Ajaran',
                        }),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _getAcademicYearOptions().map((year) {
                          final isSelected = tempSelectedAcademicYear == year;
                          return FilterChip(
                            label: Text(year),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedAcademicYear = selected
                                    ? year
                                    : null;
                              });
                            },
                            backgroundColor: Colors.grey.shade100,
                            selectedColor: _getPrimaryColor().withOpacity(0.2),
                            checkmarkColor: _getPrimaryColor(),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? _getPrimaryColor()
                                  : Colors.grey.shade700,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              // Apply Button
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: _getPrimaryColor()),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Cancel',
                            'id': 'Batal',
                          }),
                          style: TextStyle(color: _getPrimaryColor()),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);

                          // Check if semester or academic year changed - need to reload data
                          bool needsReload = false;
                          if (tempSelectedSemester != null &&
                              tempSelectedSemester != _selectedSemester) {
                            needsReload = true;
                          }
                          if (tempSelectedAcademicYear != null &&
                              tempSelectedAcademicYear !=
                                  _selectedAcademicYear) {
                            needsReload = true;
                          }

                          setState(() {
                            _selectedFilterConflict = tempSelectedConflict;
                            _selectedFilterSemester = tempSelectedSemester;
                            _selectedFilterAcademicYear =
                                tempSelectedAcademicYear;
                            _hasActiveFilter =
                                _selectedFilterConflict != null ||
                                (_selectedFilterSemester != null &&
                                    _selectedFilterSemester !=
                                        _selectedSemester) ||
                                (_selectedFilterAcademicYear != null &&
                                    _selectedFilterAcademicYear !=
                                        _selectedAcademicYear);

                            // Update main semester/year if filtered
                            if (tempSelectedSemester != null) {
                              _selectedSemester = tempSelectedSemester!;
                            }
                            if (tempSelectedAcademicYear != null) {
                              _selectedAcademicYear = tempSelectedAcademicYear!;
                            }

                            if (_showTableView) {
                              _updateGridData();
                            }
                          });

                          // Reload data if semester or academic year changed
                          if (needsReload) {
                            _loadData();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Apply',
                            'id': 'Terapkan',
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
      ),
    );
  }

  List<dynamic> _getFilteredSchedules() {
    final searchTerm = _searchController.text.toLowerCase();
    return _scheduleList.where((schedule) {
      final subjectName =
          schedule['mata_pelajaran_nama']?.toString().toLowerCase() ?? '';
      final teacherName = schedule['guru_nama']?.toString().toLowerCase() ?? '';
      final className = schedule['kelas_nama']?.toString().toLowerCase() ?? '';
      final dayName = schedule['hari_nama']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          teacherName.contains(searchTerm) ||
          className.contains(searchTerm) ||
          dayName.contains(searchTerm);

      // Apply conflict filter (client-side only)
      // Note: hasConflict should be calculated based on actual conflict data
      final hasConflict = false; // TODO: Implement conflict detection
      bool matchesConflictFilter = true;
      if (_selectedFilterConflict != null) {
        if (_selectedFilterConflict == 'With Conflicts') {
          matchesConflictFilter = hasConflict;
        } else if (_selectedFilterConflict == 'Without Conflicts') {
          matchesConflictFilter = !hasConflict;
        }
      }

      // Note: Semester and academic year filters are handled by reloading data from server
      return matchesSearch && matchesConflictFilter;
    }).toList();
  }

  Widget _buildTableView() {
    final languageProvider = context.read<LanguageProvider>();
    final days = _hariList.map((day) => day['nama'] ?? '').toList();
    final classes = _classList.map((cls) => cls['nama'] ?? '').toList();
    final timeSlots = _jamPelajaranList
        .map((jam) => '${jam['jam_mulai'] ?? ''}-${jam['jam_selesai'] ?? ''}')
        .toList();

    return Column(
      children: [
        // Header dengan tombol export
        Container(
          padding: EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_gridData.length} ${languageProvider.getTranslatedText({'en': 'schedule entries', 'id': 'entri jadwal'})}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _exportToExcel,
                icon: Icon(Icons.file_download, size: 16),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Export Excel',
                    'id': 'Ekspor Excel',
                  }),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPrimaryColor(),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // DataGrid dengan format timetable yang di-merge
        Expanded(
          child: Card(
            margin: EdgeInsets.all(8), // Margin lebih kecil
            elevation: 2,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: DataTable(
                  columnSpacing: 1, // Spacing lebih kecil
                  horizontalMargin: 4,
                  headingRowHeight: 80, // Tinggi header tetap
                  dataRowMinHeight: 60, // Tinggi minimum row
                  dataRowMaxHeight: 120, // Tinggi maksimum row
                  headingRowColor: WidgetStateProperty.resolveWith<Color?>(
                    (states) => _getPrimaryColor(),
                  ),
                  dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                    (Set<MaterialState> states) =>
                        states.contains(MaterialState.selected)
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.08)
                        : null,
                  ),
                  columns: [
                    DataColumn(
                      label: Container(
                        width: 80, // Lebar lebih kecil
                        padding: EdgeInsets.all(4),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Time',
                            'id': 'Waktu',
                          }),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12, // Font lebih kecil
                          ),
                        ),
                      ),
                    ),
                    for (var day in days)
                      DataColumn(
                        label: Container(
                          width: 150, // Lebar kolom yang disesuaikan
                          padding: EdgeInsets.all(4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                day,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 12, // Font lebih kecil
                                ),
                              ),
                              SizedBox(height: 2),
                              Wrap(
                                spacing: 2,
                                runSpacing: 1,
                                children: classes.map((className) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 3,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(
                                      className.length > 3
                                          ? className.substring(0, 3)
                                          : className,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8, // Font sangat kecil
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  rows: timeSlots.map((timeSlot) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Container(
                            width: 80,
                            padding: EdgeInsets.all(4),
                            child: Text(
                              timeSlot.length > 11
                                  ? '${timeSlot.substring(0, 11)}\n${timeSlot.substring(11)}'
                                  : timeSlot,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 10, // Font lebih kecil
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        for (var day in days)
                          DataCell(
                            Container(
                              width: 150,
                              padding: EdgeInsets.all(2),
                              constraints: BoxConstraints(minHeight: 60),
                              child: _buildDayScheduleCell(timeSlot, day),
                            ),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayScheduleCell(String timeSlot, String day) {
    final classes = _classList.map((cls) => cls['nama'] ?? '').toList();

    return Container(
      padding: EdgeInsets.all(2),
      constraints: BoxConstraints(
        minHeight: 60, // Tinggi minimum untuk cell
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: classes.map((className) {
          final schedule = _gridData.firstWhere(
            (data) =>
                data.waktu == timeSlot &&
                data.hari == day &&
                data.kelas == className,
            orElse: () => ScheduleGridData(
              id: '',
              waktu: '',
              hari: '',
              kelas: '',
              mataPelajaran: '-',
              guru: '',
            ),
          );

          return Container(
            margin: EdgeInsets.only(bottom: 2),
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: schedule.mataPelajaran != '-'
                  ? _getPrimaryColor().withOpacity(0.1)
                  : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: schedule.mataPelajaran != '-'
                    ? _getPrimaryColor().withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama kelas - lebih kompak
                Container(
                  width: 30, // Lebar lebih kecil
                  padding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: schedule.mataPelajaran != '-'
                        ? _getPrimaryColor().withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    className,
                    style: TextStyle(
                      fontSize: 8, // Font lebih kecil
                      fontWeight: FontWeight.bold,
                      color: schedule.mataPelajaran != '-'
                          ? _getPrimaryColor()
                          : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4),
                // Info mapel dan guru
                Expanded(
                  child: schedule.mataPelajaran != '-'
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule.mataPelajaran,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 9, // Font lebih kecil
                                color: Colors.grey[800],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (schedule.guru.isNotEmpty) ...[
                              SizedBox(height: 1),
                              Text(
                                schedule.guru,
                                style: TextStyle(
                                  fontSize: 7, // Font lebih kecil
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        )
                      : Center(
                          child: Text(
                            '-',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                              fontSize: 9,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return LoadingScreen(
            message: languageProvider.getTranslatedText({
              'en': 'Loading schedule data...',
              'id': 'Memuat data jadwal...',
            }),
          );
        }

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
                                  'en': 'Manage teaching schedules',
                                  'id': 'Kelola jadwal mengajar',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showTableView = !_showTableView;
                              if (_showTableView) {
                                _updateGridData();
                              }
                            });
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _showTableView
                                  ? Icons.view_list
                                  : Icons.table_chart,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'export':
                                _exportToExcel();
                                break;
                              case 'import':
                                _importFromExcel();
                                break;
                              case 'template':
                                _downloadTemplate();
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
                            child: Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'export',
                              child: Row(
                                children: [
                                  Icon(Icons.download, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Export to Excel',
                                      'id': 'Export ke Excel',
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'import',
                              child: Row(
                                children: [
                                  Icon(Icons.upload, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Import from Excel',
                                      'id': 'Import dari Excel',
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'template',
                              child: Row(
                                children: [
                                  Icon(Icons.file_download, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Download Template',
                                      'id': 'Download Template',
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

                    // Search Bar with Filter Button
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) => setState(() {}),
                              style: TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: languageProvider.getTranslatedText({
                                  'en': 'Search schedules...',
                                  'id': 'Cari jadwal...',
                                }),
                                hintStyle: TextStyle(color: Colors.grey),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Filter Button
                        Container(
                          decoration: BoxDecoration(
                            color: _hasActiveFilter
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Stack(
                            children: [
                              IconButton(
                                onPressed: _showFilterSheet,
                                icon: Icon(
                                  Icons.tune,
                                  color: _hasActiveFilter
                                      ? _getPrimaryColor()
                                      : Colors.white,
                                ),
                                tooltip: languageProvider.getTranslatedText({
                                  'en': 'Filter',
                                  'id': 'Filter',
                                }),
                              ),
                              if (_hasActiveFilter)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: 8,
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
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
                                  }).toList(),
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
              Expanded(
                child: _showTableView
                    ? _buildTableView()
                    : filteredSchedules.isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No teaching schedules',
                          'id': 'Belum ada jadwal mengajar',
                        }),
                        subtitle:
                            _searchController.text.isEmpty && !_hasActiveFilter
                            ? languageProvider.getTranslatedText({
                                'en': 'Tap + to add new schedule',
                                'id': 'Tap + untuk menambah jadwal baru',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: Icons.schedule_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(
                            top: 16,
                            left: 16,
                            right: 16,
                            bottom: 16,
                          ),
                          itemCount:
                              filteredSchedules.length +
                              (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index == filteredSchedules.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            final schedule = filteredSchedules[index];
                            return _buildScheduleCard(schedule, index);
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _addSchedule,
            backgroundColor: _getPrimaryColor(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add, color: Colors.white, size: 20),
          ),
        );
      },
    );
  }

  // ... (sisanya tetap sama - _buildScheduleCard, _buildActionButton, _formatTime, _showScheduleDetail, _buildDetailItem)

  Widget _buildScheduleCard(Map<String, dynamic> schedule, int index) {
    final languageProvider = context.read<LanguageProvider>();

    return AnimatedBuilder(
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
          onTap: () => _showScheduleDetail(schedule),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: EdgeInsets.only(bottom: 12),
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

                // Content
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header dengan subject dan status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  schedule['mata_pelajaran_nama'] ??
                                      'No Subject',
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
                                  schedule['guru_nama'] ?? 'No Teacher',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getPrimaryColor().withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                color: _getPrimaryColor(),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      // Informasi kelas dan hari
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
                                    'en': 'Class',
                                    'id': 'Kelas',
                                  }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  schedule['kelas_nama'] ?? 'No Class',
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

                      // Informasi hari dan jam
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
                                    'en': 'Schedule',
                                    'id': 'Jadwal',
                                  }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  '${schedule['hari_nama'] ?? ''} • ${_formatTime(schedule)}',
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

                      // Action buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildActionButton(
                            icon: Icons.edit,
                            label: languageProvider.getTranslatedText({
                              'en': 'Edit',
                              'id': 'Edit',
                            }),
                            color: _getPrimaryColor(),
                            onPressed: () => _editSchedule(schedule),
                          ),
                          SizedBox(width: 8),
                          _buildActionButton(
                            icon: Icons.delete,
                            label: languageProvider.getTranslatedText({
                              'en': 'Delete',
                              'id': 'Hapus',
                            }),
                            color: Colors.red,
                            onPressed: () => _deleteSchedule(schedule['id']),
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 28,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 12, color: Colors.white),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 1,
        ),
      ),
    );
  }

  String _formatTime(Map<String, dynamic> schedule) {
    final startTime = schedule['jam_mulai'] ?? '';
    final endTime = schedule['jam_selesai'] ?? '';
    return '$startTime - $endTime';
  }

  void _showScheduleDetail(Map<String, dynamic> schedule) {
    final languageProvider = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.schedule, color: _getPrimaryColor()),
            SizedBox(width: 8),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Schedule Details',
                'id': 'Detail Jadwal',
              }),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getPrimaryColor(),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailItem(
              icon: Icons.subject,
              title: languageProvider.getTranslatedText({
                'en': 'Subject',
                'id': 'Mata Pelajaran',
              }),
              value: schedule['mata_pelajaran_nama'] ?? 'No Subject',
            ),
            _buildDetailItem(
              icon: Icons.person,
              title: languageProvider.getTranslatedText({
                'en': 'Teacher',
                'id': 'Guru',
              }),
              value: schedule['guru_nama'] ?? 'No Teacher',
            ),
            _buildDetailItem(
              icon: Icons.school,
              title: languageProvider.getTranslatedText({
                'en': 'Class',
                'id': 'Kelas',
              }),
              value: schedule['kelas_nama'] ?? 'No Class',
            ),
            _buildDetailItem(
              icon: Icons.calendar_today,
              title: languageProvider.getTranslatedText({
                'en': 'Day',
                'id': 'Hari',
              }),
              value: schedule['hari_nama'] ?? 'No Day',
            ),
            _buildDetailItem(
              icon: Icons.access_time,
              title: languageProvider.getTranslatedText({
                'en': 'Time',
                'id': 'Waktu',
              }),
              value: _formatTime(schedule),
            ),
            _buildDetailItem(
              icon: Icons.school,
              title: languageProvider.getTranslatedText({
                'en': 'Grade Level',
                'id': 'Tingkat Kelas',
              }),
              value: _getGradeLevel(schedule['kelas_id'] ?? ''),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Close',
                'id': 'Tutup',
              }),
              style: TextStyle(color: _getPrimaryColor()),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editSchedule(schedule);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getPrimaryColor(),
            ),
            child: Text(
              languageProvider.getTranslatedText({'en': 'Edit', 'id': 'Edit'}),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _getPrimaryColor()),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Data class untuk grid view
class ScheduleGridData {
  final String id;
  final String waktu;
  final String hari;
  final String kelas;
  final String mataPelajaran;
  final String guru;

  ScheduleGridData({
    required this.id,
    required this.waktu,
    required this.hari,
    required this.kelas,
    required this.mataPelajaran,
    required this.guru,
  });
}

// Data source untuk grid view
class ScheduleDataSource extends DataGridSource {
  ScheduleDataSource(List<ScheduleGridData> scheduleData) {
    _scheduleData = scheduleData
        .map<DataGridRow>(
          (e) => DataGridRow(
            cells: [
              DataGridCell<String>(columnName: 'waktu', value: e.waktu),
              DataGridCell<String>(columnName: 'hari', value: e.hari),
              DataGridCell<String>(columnName: 'kelas', value: e.kelas),
              DataGridCell<String>(
                columnName: 'mataPelajaran',
                value: e.mataPelajaran,
              ),
              DataGridCell<String>(columnName: 'guru', value: e.guru),
            ],
          ),
        )
        .toList();
  }

  List<DataGridRow> _scheduleData = [];

  @override
  List<DataGridRow> get rows => _scheduleData;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((e) {
        return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(8.0),
          child: Text(e.value.toString()),
        );
      }).toList(),
    );
  }
}
