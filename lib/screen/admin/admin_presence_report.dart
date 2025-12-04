import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/models/siswa.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/excel_presence_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/date_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

// Model for Attendance Summary
class AttendanceSummary {
  final String subjectId;
  final String subjectName;
  final DateTime date;
  final int totalStudents;
  final int present;
  final int absent;
  final String classId;
  final String className;

  AttendanceSummary({
    required this.subjectId,
    required this.subjectName,
    required this.date,
    required this.totalStudents,
    required this.present,
    required this.absent,
    required this.classId,
    required this.className,
  });

  String get key =>
      '$subjectId-$classId-${DateFormat('yyyy-MM-dd').format(date)}';
}

class AdminPresenceReportScreen extends StatefulWidget {
  const AdminPresenceReportScreen({super.key});

  @override
  State<AdminPresenceReportScreen> createState() =>
      _AdminPresenceReportScreenState();
}

class _AdminPresenceReportScreenState extends State<AdminPresenceReportScreen>
    with SingleTickerProviderStateMixin {
  // Data untuk mode View Results
  List<AttendanceSummary> _absensiSummaryList = [];
  bool _isLoadingSummary = false;

  // Pagination State
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  String?
  _selectedDateFilter; // 'today', 'week', 'month', atau null untuk semua
  List<String> _selectedSubjectIds = [];
  List<String> _selectedClassIds = [];
  bool _hasActiveFilter = false;

  // Data for filters
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];

  // Animations
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

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

    _scrollController.addListener(_onScroll);
    _loadData();
    _loadFilterData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreData();
    }
  }

  Future<void> _loadFilterData() async {
    try {
      final subjects = await ApiSubjectService().getSubject();
      final classes = await ApiClassService().getClass();

      if (mounted) {
        setState(() {
          _subjectList = subjects;
          _classList = classes;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading filter data: $e');
      }
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedDateFilter != null ||
          _selectedSubjectIds.isNotEmpty ||
          _selectedClassIds.isNotEmpty;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDateFilter = null;
      _selectedSubjectIds.clear();
      _selectedClassIds.clear();
      _hasActiveFilter = false;
    });
  }

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
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    // Show individual chips for each selected subject
    if (_selectedSubjectIds.isNotEmpty) {
      for (var subjectId in _selectedSubjectIds) {
        final subject = _subjectList.firstWhere(
          (s) => s['id'].toString() == subjectId,
          orElse: () => {'nama': 'Subject #$subjectId'},
        );
        filterChips.add({
          'label':
              '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mapel'})}: ${subject['name']}',
          'onRemove': () {
            setState(() {
              _selectedSubjectIds.remove(subjectId);
            });
            _checkActiveFilter();
            _loadData();
          },
        });
      }
    }

    // Show individual chips for each selected class
    if (_selectedClassIds.isNotEmpty) {
      for (var classId in _selectedClassIds) {
        final kelas = _classList.firstWhere(
          (k) => k['id'].toString() == classId,
          orElse: () => {'nama': 'Class #$classId'},
        );
        filterChips.add({
          'label':
              '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: ${kelas['name']}',
          'onRemove': () {
            setState(() {
              _selectedClassIds.remove(classId);
            });
            _checkActiveFilter();
            _loadData();
          },
        });
      }
    }

    return filterChips;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingSummary = true;
      _currentPage = 1;
      _hasMoreData = true;
      _absensiSummaryList.clear();
    });

    await _fetchData();
  }

  Future<void> _loadMoreData() async {
    if (!mounted || _isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Prepare filter parameters
      String? tanggal;
      String? tanggalStart;
      String? tanggalEnd;

      if (_selectedDateFilter == 'today') {
        tanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());
      } else if (_selectedDateFilter == 'week') {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(Duration(days: 6));
        tanggalStart = DateFormat('yyyy-MM-dd').format(startOfWeek);
        tanggalEnd = DateFormat('yyyy-MM-dd').format(endOfWeek);
      } else if (_selectedDateFilter == 'month') {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        tanggalStart = DateFormat('yyyy-MM-dd').format(startOfMonth);
        tanggalEnd = DateFormat('yyyy-MM-dd').format(endOfMonth);
      }

      // Call paginated API
      final result = await ApiService.getAbsensiSummaryPaginated(
        page: _currentPage,
        limit: _perPage,
        mataPelajaranId: _selectedSubjectIds.isNotEmpty
            ? _selectedSubjectIds
                  .first // Currently API supports single subject filter, or we can update backend to support array
            : null,
        classId: _selectedClassIds.isNotEmpty
            ? _selectedClassIds
                  .first // Currently API supports single class filter
            : null,
        tanggal: tanggal,
        tanggalStart: tanggalStart,
        tanggalEnd: tanggalEnd,
      );

      if (!mounted) return;

      final List<dynamic> data = result['data'] ?? [];
      final Map<String, dynamic> pagination = result['pagination'] ?? {};

      final List<AttendanceSummary> newItems = data.map((item) {
        return AttendanceSummary(
          subjectId: item['subject_id']?.toString() ?? '',
          subjectName: item['subject_name'] ?? 'Unknown',
          date: AppDateUtils.parseApiDate(item['date']) ?? DateTime.now(),
          totalStudents:
              int.tryParse(item['total_students']?.toString() ?? '0') ?? 0,
          present: int.tryParse(item['present']?.toString() ?? '0') ?? 0,
          absent: int.tryParse(item['absent']?.toString() ?? '0') ?? 0,
          classId: item['class_id']?.toString() ?? '',
          className: item['class_name'] ?? 'Unknown',
        );
      }).toList();

      setState(() {
        if (_currentPage == 1) {
          _absensiSummaryList = newItems;
        } else {
          _absensiSummaryList.addAll(newItems);
        }

        _hasMoreData = pagination['has_next_page'] ?? false;
        if (_hasMoreData) {
          _currentPage++;
        }

        _isLoadingSummary = false;
        _isLoadingMore = false;
      });

      if (_currentPage == 1 && newItems.isNotEmpty) {
        _animationController.forward(from: 0.0);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading absensi summary: $e');
      }
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
          _isLoadingMore = false;
        });
      }
    }
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

  void _showFilterSheet() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    String? tempSelectedDate = _selectedDateFilter;
    List<String> tempSelectedSubjects = List.from(_selectedSubjectIds);
    List<String> tempSelectedClasses = List.from(_selectedClassIds);

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
                          tempSelectedDate = null;
                          tempSelectedSubjects.clear();
                          tempSelectedClasses.clear();
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
                      // Date Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Date Range',
                          'id': 'Rentang Tanggal',
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
                        children: ['today', 'week', 'month'].map((period) {
                          final isSelected = tempSelectedDate == period;
                          final label = period == 'today'
                              ? languageProvider.getTranslatedText({
                                  'en': 'Today',
                                  'id': 'Hari Ini',
                                })
                              : period == 'week'
                              ? languageProvider.getTranslatedText({
                                  'en': 'This Week',
                                  'id': 'Minggu Ini',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'This Month',
                                  'id': 'Bulan Ini',
                                });
                          return FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedDate = selected ? period : null;
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

                      // Subject Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Subject',
                          'id': 'Mata Pelajaran',
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
                        children: _subjectList.map<Widget>((subject) {
                          final subjectId = subject['id'].toString();
                          final subjectName = subject['name'] ?? 'Subject';
                          final isSelected = tempSelectedSubjects.contains(
                            subjectId,
                          );
                          return FilterChip(
                            label: Text(subjectName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  tempSelectedSubjects.add(subjectId);
                                } else {
                                  tempSelectedSubjects.remove(subjectId);
                                }
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

                      // Class Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Class',
                          'id': 'Kelas',
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
                        children: _classList.map<Widget>((classItem) {
                          final classId = classItem['id'].toString();
                          final className = classItem['name'] ?? 'Class';
                          final isSelected = tempSelectedClasses.contains(
                            classId,
                          );
                          return FilterChip(
                            label: Text(className),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  tempSelectedClasses.add(classId);
                                } else {
                                  tempSelectedClasses.remove(classId);
                                }
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
                          setState(() {
                            _selectedDateFilter = tempSelectedDate;
                            _selectedSubjectIds = tempSelectedSubjects;
                            _selectedClassIds = tempSelectedClasses;
                            _checkActiveFilter();
                          });
                          _loadData(); // Reload data with new filters
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _getPrimaryColor(),
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

  Widget _buildSummaryCard(
    AttendanceSummary summary,
    LanguageProvider languageProvider,
    int index,
  ) {
    final presentaseHadir = summary.totalStudents > 0
        ? (summary.present / summary.totalStudents * 100).round()
        : 0;

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
          onTap: () => _navigateToDetailAbsensi(summary),
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
                                  summary.subjectName,
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
                                  summary.className, // Tampilkan nama kelas
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
                                  ).format(summary.date),
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
                              '${summary.totalStudents} Siswa',
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
                                  '${summary.present} Hadir • ${summary.absent} Tidak Hadir',
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
                                      (summary.totalStudents > 0
                                          ? summary.present /
                                                summary.totalStudents
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
          border: Border.all(color: Colors.white.withOpacity(0.3)),
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

  List<AttendanceSummary> _getFilteredSummaries() {
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
          summary.subjectName.toLowerCase().contains(searchTerm) ||
          summary.className.toLowerCase().contains(searchTerm);

      // Date filter
      bool matchesDateFilter = true;
      if (_selectedDateFilter != null) {
        if (_selectedDateFilter == 'today') {
          matchesDateFilter = _isSameDay(summary.date, now);
        } else if (_selectedDateFilter == 'week') {
          matchesDateFilter =
              summary.date.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
              summary.date.isBefore(endOfWeek.add(Duration(days: 1)));
        } else if (_selectedDateFilter == 'month') {
          matchesDateFilter =
              summary.date.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
              summary.date.isBefore(endOfMonth.add(Duration(days: 1)));
        }
      }

      // Subject filter
      final matchesSubject =
          _selectedSubjectIds.isEmpty ||
          _selectedSubjectIds.contains(summary.subjectId);

      // Class filter
      final matchesClass =
          _selectedClassIds.isEmpty ||
          _selectedClassIds.contains(summary.classId);

      return matchesSearch &&
          matchesDateFilter &&
          matchesSubject &&
          matchesClass;
    }).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _navigateToDetailAbsensi(AttendanceSummary summary) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminAbsensiDetailPage(
          mataPelajaranId: summary.subjectId,
          mataPelajaranNama: summary.subjectName,
          tanggal: summary.date,
          classId: summary.classId, // Kirim classId ke detail page
          kelasNama: summary.className, // Kirim kelasNama ke detail page
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                                  'en': 'Attendance Report',
                                  'id': 'Laporan Absensi',
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
                                  'en': 'View attendance reports',
                                  'id': 'Lihat laporan absensi',
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
                                _loadData();
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
                                  'en': 'Search attendance...',
                                  'id': 'Cari absensi...',
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
                                            color: _getPrimaryColor(),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        deleteIcon: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.red,
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
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.clear_all,
                                  size: 18,
                                  color: Colors.white,
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
                        padding: EdgeInsets.symmetric(vertical: 16),
                        itemCount: filteredSummaries.length,
                        itemBuilder: (context, index) {
                          final summary = filteredSummaries[index];
                          return _buildSummaryCard(
                            summary,
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

// ========== ADMIN ABSENSI DETAIL PAGE ==========
class AdminAbsensiDetailPage extends StatefulWidget {
  final String mataPelajaranId;
  final String mataPelajaranNama;
  final DateTime tanggal;
  final String classId; // Tambahkan
  final String kelasNama; // Tambahkan

  const AdminAbsensiDetailPage({
    super.key,
    required this.mataPelajaranId,
    required this.mataPelajaranNama,
    required this.tanggal,
    required this.classId, // Tambahkan
    required this.kelasNama, // Tambahkan
  });

  @override
  State<AdminAbsensiDetailPage> createState() => _AdminAbsensiDetailPageState();
}

class _AdminAbsensiDetailPageState extends State<AdminAbsensiDetailPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> _absensiData = [];
  List<Siswa> _siswaList = [];
  bool _isLoading = true;

  // Animations
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

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
      );

      // 2. Load students by class ID (from widget parameter)
      List<dynamic> siswaData;
      if (widget.classId.isNotEmpty) {
        siswaData = await ApiStudentService.getStudentByClass(widget.classId);
        if (kDebugMode) {
          print(
            'Loaded ${siswaData.length} students for class: ${widget.classId}',
          );
        }
      } else {
        // Fallback: if no classId provided, try to get from attendance data
        if (absensiData.isNotEmpty) {
          final classIdFromData = absensiData.first['kelas_id']?.toString();
          if (classIdFromData != null && classIdFromData.isNotEmpty) {
            siswaData = await ApiStudentService.getStudentByClass(
              classIdFromData,
            );
            if (kDebugMode) {
              print(
                'Loaded ${siswaData.length} students for class: $classIdFromData (from attendance data)',
              );
            }
          } else {
            siswaData = await ApiStudentService.getStudent();
            if (kDebugMode) {
              print('Loaded all students (no class ID available)');
            }
          }
        } else {
          siswaData = await ApiStudentService.getStudent();
          if (kDebugMode) {
            print('Loaded all students (no attendance data)');
          }
        }
      }

      if (kDebugMode) {
        print('Loaded ${absensiData.length} attendance records');
      }

      setState(() {
        _siswaList = siswaData.map((s) => Siswa.fromJson(s)).toList();
        _absensiData = absensiData;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      print('Error loading absensi detail for admin: $e');
      setState(() {
        _isLoading = false;
      });
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
      await ExcelPresenceService.exportPresenceToExcel(
        presenceData: _absensiData,
        context: context,
      );
    } catch (e) {
      print('Error exporting activities: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  // Method untuk mendapatkan status absensi siswa
  String _getStudentStatus(String siswaId) {
    try {
      final absenRecord = _absensiData.firstWhere(
        (a) => a['siswa_id']?.toString() == siswaId.toString(),
        orElse: () => {'status': 'alpha'}, // Fallback if not found
      );
      return absenRecord['status'] ?? 'alpha';
    } catch (e) {
      return 'alpha';
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

                        // Status Badge
                        Container(
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
    switch (status) {
      case 'hadir':
        return Colors.green;
      case 'izin':
        return Colors.blue;
      case 'sakit':
        return Colors.orange;
      case 'alpha':
        return Colors.red;
      case 'terlambat':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status, LanguageProvider languageProvider) {
    switch (status) {
      case 'hadir':
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
      case 'izin':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'sakit':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
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
      switch (status) {
        case 'hadir':
          hadir++;
          break;
        case 'terlambat':
          terlambat++;
          break;
        case 'izin':
          izin++;
          break;
        case 'sakit':
          sakit++;
          break;
        case 'alpha':
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
        final totalTidakHadir =
            stats['izin']! + stats['sakit']! + stats['alpha']!;

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
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  switch (value) {
                    case 'refresh':
                      _loadData();
                      break;
                    case 'export':
                      exportDetail();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.file_download, color: _getPrimaryColor()),
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
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, color: _getPrimaryColor()),
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
          body: _isLoading
              ? LoadingScreen(
                  message: languageProvider.getTranslatedText({
                    'en': 'Loading attendance details...',
                    'id': 'Memuat detail absensi...',
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
                            Colors.orange,
                            Icons.access_time,
                          ),
                          _buildStatCard(
                            languageProvider.getTranslatedText({
                              'en': 'Absent',
                              'id': 'Tidak Hadir',
                            }),
                            totalTidakHadir,
                            Colors.red,
                            Icons.cancel,
                          ),
                          if (stats['izin']! > 0)
                            _buildStatCard(
                              languageProvider.getTranslatedText({
                                'en': 'Permission',
                                'id': 'Izin',
                              }),
                              stats['izin']!,
                              Colors.blue,
                              Icons.event_note,
                            ),
                          if (stats['sakit']! > 0)
                            _buildStatCard(
                              languageProvider.getTranslatedText({
                                'en': 'Sick',
                                'id': 'Sakit',
                              }),
                              stats['sakit']!,
                              Colors.purple,
                              Icons.medical_services,
                            ),
                        ],
                      ),
                    ),

                    // Student List Header
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
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
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '${_siswaList.length} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Student List
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.only(bottom: 16),
                        itemCount: _siswaList.length,
                        itemBuilder: (context, index) => _buildStudentCard(
                          _siswaList[index],
                          languageProvider,
                          index,
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
