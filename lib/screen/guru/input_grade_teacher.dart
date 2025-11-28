import 'dart:async';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/filter_sheet.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/components/separated_search_filter.dart';
import 'package:manajemensekolah/models/siswa.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class GradePage extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const GradePage({super.key, required this.teacher});

  @override
  GradePageState createState() => GradePageState();
}

class GradePageState extends State<GradePage> {
  final ApiSubjectService apiSubjectService = ApiSubjectService();
  final ApiTeacherService apiTeacherService = ApiTeacherService();

  List<dynamic> _mataPelajaranList = [];
  final List<dynamic> _filteredMataPelajaranList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _paginationMeta;

  // Filter States
  List<String> _selectedSubjectIds = [];
  bool _hasActiveFilter = false;

  // Search debounce
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);
    // Listen to search changes with debounce
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
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
        _loadMoreSubjects();
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

  void _filterMataPelajaran() {
    // Trigger reload data with new search query
    _currentPage = 1;
    _loadData();
  }

  Future<void> _loadData({bool resetPage = true}) async {
    try {
      if (resetPage) {
        setState(() {
          _isLoading = true;
          _currentPage = 1;
          _hasMoreData = true;
          _mataPelajaranList = []; // Reset list
        });
      }

      List<dynamic> mataPelajaran;

      if (widget.teacher['role'] == 'guru') {
        // For teachers, get subjects by teacher with pagination
        final response = await ApiTeacherService.getSubjectsByTeacherPaginated(
          guruId: widget.teacher['id'],
          page: _currentPage,
          limit: _perPage,
          search: _searchController.text,
          subjectIds: _selectedSubjectIds,
        );
        mataPelajaran = response['data'] ?? [];
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
      } else {
        // For admins, get all subjects with pagination
        final response = await ApiSubjectService.getSubjectsPaginated(
          page: _currentPage,
          limit: _perPage,
          search: _searchController.text,
          subjectIds: _selectedSubjectIds,
        );
        mataPelajaran = response['data'] ?? [];
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
      }

      setState(() {
        _mataPelajaranList = mataPelajaran;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  Future<void> _loadMoreSubjects() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      List<dynamic> newSubjects;

      if (widget.teacher['role'] == 'guru') {
        // For teachers, get subjects by teacher
        final response = await ApiTeacherService.getSubjectsByTeacherPaginated(
          guruId: widget.teacher['id'],
          page: _currentPage,
          limit: _perPage,
          search: _searchController.text,
          subjectIds: _selectedSubjectIds,
        );
        newSubjects = response['data'] ?? [];
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
      } else {
        // For admins, get all subjects
        final response = await ApiSubjectService.getSubjectsPaginated(
          page: _currentPage,
          limit: _perPage,
          search: _searchController.text,
          subjectIds: _selectedSubjectIds,
        );
        newSubjects = response['data'] ?? [];
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
      }

      setState(() {
        // Append new data to existing list
        _mataPelajaranList.addAll(newSubjects);
        _isLoadingMore = false;
      });

      print(
        '✅ Loaded more subjects: Page $_currentPage, Total: ${_mataPelajaranList.length}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });

      print('Error loading more subjects: $e');
      _showErrorSnackBar('Failed to load more subjects: $e');
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
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
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
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToClassSelection(Map<String, dynamic> mataPelajaran) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ClassSelectionPage(teacher: widget.teacher, subject: mataPelajaran),
      ),
    );
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withOpacity(0.8)],
    );
  }

  // Filter Methods
  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = _selectedSubjectIds.isNotEmpty;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedSubjectIds.clear();
      _searchController.clear();
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData(); // Reload data setelah clear filters
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedSubjectIds.isNotEmpty) {
      // Group subject IDs into a single chip or multiple chips?
      // Student management shows multiple chips for classes.
      // Here we filter by subject. Let's show one chip per subject if possible,
      // but we only have IDs. We need names.
      // Since we might not have the names of ALL selected subjects (if they are not in the current list),
      // we can try to find them in _mataPelajaranList OR just show a count.
      // However, the user wants it to look like student_management.dart.
      // In student_management.dart, it iterates _selectedClassIds and finds the name in _classList.
      // Here, we don't have a full list of subjects loaded, only paginated ones.
      // So showing names might be tricky if the selected subject is not in the current page.
      // BUT, the filter sheet shows options from `_mataPelajaranList`.
      // Wait, `_showFilterSheet` uses `_mataPelajaranList` to populate options.
      // If `_mataPelajaranList` only has partial data, the filter sheet will only show partial options.
      // This is a limitation of filtering based on paginated data.
      // Ideally, we should fetch "all subjects" for the filter options, separate from the display list.
      // For now, let's stick to what we have.

      for (var subjectId in _selectedSubjectIds) {
        final subject = _mataPelajaranList.firstWhere(
          (s) => s['id'].toString() == subjectId,
          orElse: () => {'nama': 'Subject #$subjectId'},
        );

        filterChips.add({
          'label':
              '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mapel'})}: ${subject['nama']}',
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

    return filterChips;
  }

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
              key: 'subjectIds',
              title: languageProvider.getTranslatedText({
                'en': 'Subjects',
                'id': 'Mata Pelajaran',
              }),
              options: _mataPelajaranList.map((subject) {
                return FilterOption(
                  label: subject['nama'] ?? 'Subject',
                  value: subject['id'].toString(),
                );
              }).toList(),
              multiSelect: true,
            ),
          ],
        ),
        initialFilters: {'subjectIds': _selectedSubjectIds},
        onApplyFilters: (filters) {
          setState(() {
            _selectedSubjectIds = List<String>.from(
              filters['subjectIds'] ?? [],
            );
            _checkActiveFilter();
          });
          // Navigator.pop(context); // Removed: FilterSheet already pops itself
          _loadData(); // Reload data setelah apply filter
        },
      ),
    );
  }

  Widget _buildSubjectCard(
    Map<String, dynamic> subject,
    LanguageProvider languageProvider,
    int index,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToClassSelection(subject),
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
                // Strip berwarna di pinggir kiri
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
                      // Header dengan judul
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject['nama'] ??
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
                                Text(
                                  '${languageProvider.getTranslatedText({'en': 'Code', 'id': 'Kode'})}: ${subject['kode'] ?? '-'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
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
                              Icons.arrow_forward,
                              color: _getPrimaryColor(),
                              size: 16,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      // Konten preview
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
                              Icons.description,
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
                                  subject['deskripsi'] ??
                                      languageProvider.getTranslatedText({
                                        'en': 'No description',
                                        'id': 'Tidak ada deskripsi',
                                      }),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final filteredSubjects =
            _mataPelajaranList; // Use direct list from backend

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
                                  'en': 'Input Grades',
                                  'id': 'Input Nilai',
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
                                  'en': 'Select subject to input grades',
                                  'id':
                                      'Pilih mata pelajaran untuk input nilai',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.grade,
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
                              widget.teacher['role'] == 'guru'
                                  ? Icons.school
                                  : Icons.admin_panel_settings,
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
                                  widget.teacher['nama'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  widget.teacher['role'] == 'guru'
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Teacher',
                                          'id': 'Guru',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Admin',
                                          'id': 'Admin',
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

                    // Search Bar with Filter Button using SeparatedSearchFilter
                    SeparatedSearchFilter(
                      controller: _searchController,
                      onChanged: (value) => setState(() {}),
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search subjects...',
                        'id': 'Cari mata pelajaran...',
                      }),
                      showFilter: true,
                      hasActiveFilter: _hasActiveFilter,
                      onFilterPressed: _showFilterSheet,
                      // Custom search styling - longer with white background
                      searchBackgroundColor: Colors.white.withOpacity(0.95),
                      searchIconColor: Colors.grey.shade600,
                      searchTextColor: Colors.black87,
                      searchHintColor: Colors.grey.shade500,
                      searchBorderRadius: 14,
                      // Custom filter styling - compact with primary color
                      filterActiveColor: _getPrimaryColor(),
                      filterInactiveColor: Colors.white.withOpacity(0.9),
                      filterIconColor: _hasActiveFilter
                          ? Colors.white
                          : _getPrimaryColor(),
                      filterBorderRadius: 14,
                      filterWidth: 56,
                      filterHeight: 48, // Match search bar height
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
                                            color: _getPrimaryColor(),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        deleteIcon: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: _getPrimaryColor(),
                                        ),
                                        onDeleted: filter['onRemove'],
                                        backgroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.5),
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
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.clear_all,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Clear',
                                        'id': 'Hapus',
                                      }),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
                child: _isLoading
                    ? LoadingScreen(
                        message: languageProvider.getTranslatedText({
                          'en': 'Loading subjects...',
                          'id': 'Memuat mata pelajaran...',
                        }),
                      )
                    : filteredSubjects.isEmpty
                    ? EmptyState(
                        icon: Icons.menu_book,
                        title: languageProvider.getTranslatedText({
                          'en': 'No Subjects Available',
                          'id': 'Tidak Ada Mata Pelajaran',
                        }),
                        subtitle: languageProvider.getTranslatedText({
                          'en':
                              _searchController.text.isNotEmpty ||
                                  _hasActiveFilter
                              ? 'No subjects found for your search'
                              : widget.teacher['role'] == 'guru'
                              ? 'No subjects assigned to you'
                              : 'No subjects available',
                          'id':
                              _searchController.text.isNotEmpty ||
                                  _hasActiveFilter
                              ? 'Tidak ada mata pelajaran yang sesuai dengan pencarian'
                              : widget.teacher['role'] == 'guru'
                              ? 'Tidak ada mata pelajaran yang diajarkan'
                              : 'Tidak ada mata pelajaran tersedia',
                        }),
                        buttonText: languageProvider.getTranslatedText({
                          'en': 'Refresh',
                          'id': 'Muat Ulang',
                        }),
                        onPressed: _loadData,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: _getPrimaryColor(),
                        backgroundColor: Colors.white,
                        child: Column(
                          children: [
                            if (filteredSubjects.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '${filteredSubjects.length} ${languageProvider.getTranslatedText({'en': 'subjects found', 'id': 'mata pelajaran ditemukan'})}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.only(top: 8, bottom: 16),
                                itemCount:
                                    _mataPelajaranList.length +
                                    (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // Show loading indicator at bottom
                                  if (index == _mataPelajaranList.length) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      alignment: Alignment.center,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }

                                  return _buildSubjectCard(
                                    _mataPelajaranList[index],
                                    languageProvider,
                                    index,
                                  );
                                },
                              ),
                            ),
                          ],
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

// Halaman Pemilihan Kelas - Diperbaiki agar langsung ke tabel nilai
class ClassSelectionPage extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;

  const ClassSelectionPage({
    super.key,
    required this.teacher,
    required this.subject,
  });

  @override
  ClassSelectionPageState createState() => ClassSelectionPageState();
}

class ClassSelectionPageState extends State<ClassSelectionPage> {
  List<dynamic> _kelasList = [];
  List<dynamic> _filteredKelasList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  List<String> _selectedClassIds = [];
  bool _hasActiveFilter = false;

  @override
  void initState() {
    super.initState();
    _loadKelas();
    _searchController.addListener(_filterKelas);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterKelas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredKelasList = List.from(_kelasList);
      } else {
        _filteredKelasList = _kelasList
            .where(
              (kelas) =>
                  kelas['nama'].toLowerCase().contains(query) ||
                  (kelas['tingkat']?.toString().toLowerCase().contains(query) ??
                      false),
            )
            .toList();
      }
    });
  }

  Future<void> _loadKelas() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final kelasData = await ApiService().getKelasByMataPelajaran(
        widget.subject['id'],
      );

      setState(() {
        _kelasList = kelasData;
        _filteredKelasList = List.from(_kelasList);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load classes: $e');
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
                'Failed to load classes:',
                'Gagal memuat kelas:',
              ),
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToGradeBook(Map<String, dynamic> kelas) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeBookPage(
          teacher: widget.teacher,
          subject: widget.subject,
          kelas: kelas,
        ),
      ),
    );
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withOpacity(0.8)],
    );
  }

  // Filter Methods untuk Class Selection
  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = _selectedClassIds.isNotEmpty;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedClassIds.clear();
      _hasActiveFilter = false;
    });
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedClassIds.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: ${_selectedClassIds.length}',
        'onRemove': () {
          setState(() {
            _selectedClassIds.clear();
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterSheet(
        primaryColor: _getPrimaryColor(),
        config: FilterConfig(
          sections: [
            FilterSection(
              key: 'classIds',
              title: languageProvider.getTranslatedText({
                'en': 'Classes',
                'id': 'Kelas',
              }),
              options: _kelasList.map((classItem) {
                return FilterOption(
                  label: classItem['nama'] ?? 'Class',
                  value: classItem['id'].toString(),
                );
              }).toList(),
              multiSelect: true,
            ),
          ],
        ),
        initialFilters: {'classIds': _selectedClassIds},
        onApplyFilters: (filters) {
          setState(() {
            _selectedClassIds = List<String>.from(filters['classIds'] ?? []);
            _checkActiveFilter();
          });
        },
      ),
    );
  }

  List<dynamic> _getFilteredClasses() {
    final searchTerm = _searchController.text.toLowerCase();

    return _kelasList.where((kelas) {
      // Search filter
      final matchesSearch =
          searchTerm.isEmpty ||
          kelas['nama'].toLowerCase().contains(searchTerm) ||
          (kelas['tingkat']?.toString().toLowerCase().contains(searchTerm) ??
              false);

      // Class filter
      final matchesClass =
          _selectedClassIds.isEmpty ||
          _selectedClassIds.contains(kelas['id'].toString());

      return matchesSearch && matchesClass;
    }).toList();
  }

  Widget _buildClassCard(
    Map<String, dynamic> kelas,
    LanguageProvider languageProvider,
    int index,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToGradeBook(kelas),
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
                // Strip berwarna di pinggir kiri
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
                      // Header dengan nama kelas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  kelas['nama'] ??
                                      languageProvider.getTranslatedText({
                                        'en': 'Class',
                                        'id': 'Kelas',
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
                                Text(
                                  '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Tingkat'})}: ${kelas['tingkat'] ?? '-'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
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
                              Icons.arrow_forward,
                              color: _getPrimaryColor(),
                              size: 16,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 12),

                      // Konten preview
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
                                  languageProvider.getTranslatedText({
                                    'en': 'Subject',
                                    'id': 'Mata Pelajaran',
                                  }),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  widget.subject['nama'] ??
                                      languageProvider.getTranslatedText({
                                        'en': 'No subject',
                                        'id': 'Tidak ada mata pelajaran',
                                      }),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final filteredClasses = _getFilteredClasses();

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
                                  'en': 'Select Class',
                                  'id': 'Pilih Kelas',
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
                                  'en': 'Choose class to input grades',
                                  'id': 'Pilih kelas untuk input nilai',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.class_,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Info Mata Pelajaran
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
                              Icons.menu_book,
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
                                  widget.subject['nama'] ?? 'Subject',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${languageProvider.getTranslatedText({'en': 'Code', 'id': 'Kode'})}: ${widget.subject['kode'] ?? '-'}',
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

                    // Search Bar with Filter Button using SeparatedSearchFilter
                    SeparatedSearchFilter(
                      controller: _searchController,
                      onChanged: (value) => setState(() {}),
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search classes...',
                        'id': 'Cari kelas...',
                      }),
                      showFilter: true,
                      hasActiveFilter: _hasActiveFilter,
                      onFilterPressed: _showFilterSheet,
                      // Different styling for ClassSelectionPage - more compact
                      searchBackgroundColor: Colors.white.withOpacity(0.92),
                      searchIconColor: _getPrimaryColor().withOpacity(0.7),
                      searchTextColor: Colors.black,
                      searchHintColor: Colors.grey.shade400,
                      searchBorderRadius: 12,
                      // Filter with accent color
                      filterActiveColor: Colors.orange.shade600,
                      filterInactiveColor: Colors.white.withOpacity(0.85),
                      filterIconColor: _hasActiveFilter
                          ? Colors.white
                          : Colors.orange.shade600,
                      filterBorderRadius: 12,
                      filterWidth: 52,
                      filterHeight: 48, // Match search bar height
                      spacing: 10,
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
                          'en': 'Loading classes...',
                          'id': 'Memuat kelas...',
                        }),
                      )
                    : filteredClasses.isEmpty
                    ? EmptyState(
                        icon: Icons.class_,
                        title: languageProvider.getTranslatedText({
                          'en': 'No Classes Available',
                          'id': 'Tidak Ada Kelas',
                        }),
                        subtitle: languageProvider.getTranslatedText({
                          'en':
                              _searchController.text.isNotEmpty ||
                                  _hasActiveFilter
                              ? 'No classes found for your search'
                              : 'No classes available for this subject',
                          'id':
                              _searchController.text.isNotEmpty ||
                                  _hasActiveFilter
                              ? 'Tidak ada kelas yang sesuai dengan pencarian'
                              : 'Tidak ada kelas tersedia untuk mata pelajaran ini',
                        }),
                        buttonText: languageProvider.getTranslatedText({
                          'en': 'Refresh',
                          'id': 'Muat Ulang',
                        }),
                        onPressed: _loadKelas,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadKelas,
                        color: _getPrimaryColor(),
                        backgroundColor: Colors.white,
                        child: Column(
                          children: [
                            if (filteredClasses.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '${filteredClasses.length} ${languageProvider.getTranslatedText({'en': 'classes found', 'id': 'kelas ditemukan'})}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: ListView.builder(
                                padding: EdgeInsets.only(top: 8, bottom: 16),
                                itemCount: filteredClasses.length,
                                itemBuilder: (context, index) {
                                  return _buildClassCard(
                                    filteredClasses[index],
                                    languageProvider,
                                    index,
                                  );
                                },
                              ),
                            ),
                          ],
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

// Halaman Grade Book/Tabel Nilai
class GradeBookPage extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final Map<String, dynamic> kelas;

  const GradeBookPage({
    super.key,
    required this.teacher,
    required this.subject,
    required this.kelas,
  });

  @override
  GradeBookPageState createState() => GradeBookPageState();
}

class GradeBookPageState extends State<GradeBookPage> {
  List<Siswa> _siswaList = [];
  List<Siswa> _filteredSiswaList = [];
  List<Map<String, dynamic>> _nilaiList = [];
  final List<String> _allJenisNilaiList = [
    'harian',
    'tugas',
    'ulangan',
    'uts',
    'uas',
  ];
  List<String> _filteredJenisNilaiList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  final Map<String, bool> _jenisNilaiFilter = {
    'harian': true,
    'tugas': true,
    'ulangan': true,
    'uts': true,
    'uas': true,
  };

  // Map to store unique dates for each grade type
  // Key: jenis (e.g., 'harian'), Value: List of dates (YYYY-MM-DD)
  Map<String, List<String>> _assessmentDates = {};

  // Scroll controller untuk sinkronisasi scroll horizontal
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _updateFilteredJenisNilai();
    _searchController.addListener(_filterSiswa);
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterSiswa() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSiswaList = List.from(_siswaList);
      } else {
        _filteredSiswaList = _siswaList
            .where(
              (siswa) =>
                  siswa.nama.toLowerCase().contains(query) ||
                  siswa.nis.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  Future<void> _loadData() async {
    try {
      // Load siswa berdasarkan kelas
      final siswaData = await ApiStudentService.getStudentByClass(
        widget.kelas['id'],
      );

      // Load nilai yang sudah ada
      final nilaiData = await ApiService().getNilaiByMataPelajaran(
        widget.subject['id'],
      );

      setState(() {
        _siswaList = siswaData.map((s) => Siswa.fromJson(s)).toList();
        _filteredSiswaList = List.from(_siswaList);
        _nilaiList = List<Map<String, dynamic>>.from(nilaiData);

        // Process unique dates for each grade type
        _assessmentDates = {};
        for (var nilai in _nilaiList) {
          final jenis = nilai['jenis'];
          // Ensure date is in YYYY-MM-DD format
          String? rawDate = nilai['tanggal'];
          if (rawDate != null) {
            // Take only the date part if it's a full datetime string
            final datePart = rawDate.split('T')[0];

            if (!_assessmentDates.containsKey(jenis)) {
              _assessmentDates[jenis] = [];
            }
            if (!_assessmentDates[jenis]!.contains(datePart)) {
              _assessmentDates[jenis]!.add(datePart);
            }
          }
        }

        // Sort dates for each type
        for (var key in _assessmentDates.keys) {
          _assessmentDates[key]!.sort();
        }

        // Ensure at least one empty column (or default) if no data exists for a type
        // Actually, we don't force an empty column if there's no data,
        // but we need a way to add the first one.
        // We'll handle this in the UI by showing a "+" button even if list is empty.

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load grade data: $e');
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
                'Failed to load grade data:',
                'Gagal memuat data nilai:',
              ),
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
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
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _updateFilteredJenisNilai() {
    setState(() {
      _filteredJenisNilaiList = _allJenisNilaiList
          .where((jenis) => _jenisNilaiFilter[jenis] == true)
          .toList();
    });
  }

  void _showFilterDialog(LanguageProvider languageProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.filter_list, color: _getPrimaryColor()),
              SizedBox(width: 8),
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Filter Grade Types',
                  'id': 'Filter Jenis Nilai',
                }),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _allJenisNilaiList.map((jenis) {
                return CheckboxListTile(
                  title: Text(_getJenisNilaiLabel(jenis, languageProvider)),
                  value: _jenisNilaiFilter[jenis],
                  onChanged: (bool? value) {
                    setState(() {
                      _jenisNilaiFilter[jenis] = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                languageProvider.getTranslatedText({
                  'en': 'Cancel',
                  'id': 'Batal',
                }),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _updateFilteredJenisNilai();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getPrimaryColor(),
                foregroundColor: Colors.white,
              ),
              child: Text(
                languageProvider.getTranslatedText({
                  'en': 'Apply',
                  'id': 'Terapkan',
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, dynamic>? _getNilaiForSiswaAndJenisAndDate(
    String siswaId,
    String jenis,
    String date,
  ) {
    try {
      return _nilaiList.firstWhere((nilai) {
        final nilaiDate = nilai['tanggal']?.toString().split('T')[0];
        return nilai['siswa_id'] == siswaId &&
            nilai['jenis'] == jenis &&
            nilaiDate == date;
      }, orElse: () => <String, dynamic>{});
    } catch (e) {
      return null;
    }
  }

  void _openInputForm(
    Siswa siswa,
    String jenisNilai,
    LanguageProvider languageProvider, {
    String? date,
  }) {
    final existingNilai = date != null
        ? _getNilaiForSiswaAndJenisAndDate(siswa.id, jenisNilai, date)
        : null; // Should not happen in new logic, we always pass date

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeInputForm(
          teacher: widget.teacher,
          subject: widget.subject,
          siswa: siswa,
          jenisNilai: jenisNilai,
          existingNilai: existingNilai?.isNotEmpty == true
              ? existingNilai
              : null,
          initialDate: date != null ? DateTime.parse(date) : null,
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  void _showColumnOptions(
    String jenis,
    String date,
    LanguageProvider languageProvider,
  ) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                "${_getJenisNilaiLabel(jenis, languageProvider)} - ${_formatDateDisplay(date)}",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.visibility, color: Colors.blue),
                ),
                title: Text(
                  languageProvider.getTranslatedText({
                    'en': 'View Details',
                    'id': 'Lihat Detail',
                  }),
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAssessmentDetail(jenis, date, languageProvider);
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_outline, color: Colors.red),
                ),
                title: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Delete Assessment',
                    'id': 'Hapus Penilaian',
                  }),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Delete all grades for this date',
                    'id': 'Hapus semua nilai pada tanggal ini',
                  }),
                  style: TextStyle(fontSize: 12, color: Colors.red.shade300),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteAssessment(jenis, date, languageProvider);
                },
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  String _formatDateDisplay(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}";
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  void _showAssessmentDetail(
    String jenis,
    String date,
    LanguageProvider languageProvider,
  ) {
    // Calculate stats
    int totalSiswa = _siswaList.length;
    int gradedCount = 0;
    double totalNilai = 0;

    for (var siswa in _siswaList) {
      final nilai = _getNilaiForSiswaAndJenisAndDate(siswa.id, jenis, date);
      if (nilai != null && nilai.isNotEmpty) {
        gradedCount++;
        totalNilai += double.tryParse(nilai['nilai'].toString()) ?? 0.0;
      }
    }

    double average = gradedCount > 0 ? totalNilai / gradedCount : 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Assessment Details',
            'id': 'Detail Penilaian',
          }),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
              languageProvider.getTranslatedText({'en': 'Type', 'id': 'Jenis'}),
              _getJenisNilaiLabel(jenis, languageProvider),
            ),
            _buildDetailRow(
              languageProvider.getTranslatedText({
                'en': 'Date',
                'id': 'Tanggal',
              }),
              _formatDateDisplay(date),
            ),
            Divider(),
            _buildDetailRow(
              languageProvider.getTranslatedText({
                'en': 'Total Students',
                'id': 'Total Siswa',
              }),
              totalSiswa.toString(),
            ),
            _buildDetailRow(
              languageProvider.getTranslatedText({
                'en': 'Graded',
                'id': 'Sudah Dinilai',
              }),
              "$gradedCount / $totalSiswa",
            ),
            _buildDetailRow(
              languageProvider.getTranslatedText({
                'en': 'Average Score',
                'id': 'Rata-rata Nilai',
              }),
              average.toStringAsFixed(2),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmDeleteAssessment(
    String jenis,
    String date,
    LanguageProvider languageProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Delete Assessment?',
            'id': 'Hapus Penilaian?',
          }),
        ),
        content: Text(
          languageProvider.getTranslatedText({
            'en':
                'Are you sure you want to delete all grades for ${_getJenisNilaiLabel(jenis, languageProvider)} on ${_formatDateDisplay(date)}? This action cannot be undone.',
            'id':
                'Apakah Anda yakin ingin menghapus semua nilai ${_getJenisNilaiLabel(jenis, languageProvider)} pada tanggal ${_formatDateDisplay(date)}? Tindakan ini tidak dapat dibatalkan.',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Cancel',
                'id': 'Batal',
              }),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAssessment(jenis, date);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Delete',
                'id': 'Hapus',
              }),
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAssessment(String jenis, String date) async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();
      // Use the new batch delete endpoint
      // We need to construct the query parameters manually or add a method to ApiService
      // For now, let's use the generic delete with query params if supported,
      // or we might need to use a custom request.
      // Since ApiService.delete takes a path, we can append query params.

      final queryParams = {
        'mata_pelajaran_id': widget.subject['id'],
        'jenis': jenis,
        'tanggal': date,
      };

      final queryString = Uri(queryParameters: queryParams).query;

      await apiService.delete('/nilai/batch?$queryString');

      _showSuccessSnackBar('Assessment deleted successfully');
      _loadData(); // Reload to refresh the table
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to delete assessment: $e');
    }
  }

  Future<void> _addNewAssessment(String jenis) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      final dateStr =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

      setState(() {
        if (!_assessmentDates.containsKey(jenis)) {
          _assessmentDates[jenis] = [];
        }
        if (!_assessmentDates[jenis]!.contains(dateStr)) {
          _assessmentDates[jenis]!.add(dateStr);
          _assessmentDates[jenis]!.sort();
        }
      });
    }
  }

  void _openNewInputForm(LanguageProvider languageProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeInputFormNew(
          teacher: widget.teacher,
          subject: widget.subject,
          siswaList: _siswaList,
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  Widget _buildGradeTable(LanguageProvider languageProvider) {
    // Calculate total width based on columns
    double totalWidth = 120.0; // Name column

    for (var jenis in _filteredJenisNilaiList) {
      final dates = _assessmentDates[jenis] ?? [];
      // Width for dates columns + 1 for "Add" button column
      totalWidth += (dates.length * 90.0) + 50.0;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _horizontalScrollController,
      child: SizedBox(
        width: totalWidth,
        child: Column(
          children: [
            // Header tabel
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  // Kolom Nama Siswa - Lebar tetap
                  Container(
                    width: 120,
                    padding: EdgeInsets.all(12),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Name',
                        'id': 'Nama',
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Kolom jenis nilai (Dynamic)
                  ..._filteredJenisNilaiList.expand((jenis) {
                    final dates = _assessmentDates[jenis] ?? [];

                    List<Widget> columns = [];

                    // Existing date columns
                    for (var date in dates) {
                      // Format date for display (e.g. 10/10)
                      final parts = date.split('-');
                      final displayDate = parts.length == 3
                          ? "${parts[2]}/${parts[1]}"
                          : date;

                      columns.add(
                        InkWell(
                          onTap: () =>
                              _showColumnOptions(jenis, date, languageProvider),
                          child: Container(
                            width: 90,
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getJenisNilaiLabel(jenis, languageProvider),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                ),
                                Text(
                                  displayDate,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    // Add button column
                    columns.add(
                      Container(
                        width: 50,
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: _getPrimaryColor(),
                          ),
                          onPressed: () => _addNewAssessment(jenis),
                          tooltip: "Add $jenis",
                        ),
                      ),
                    );

                    return columns;
                  }),
                ],
              ),
            ),
            // Body tabel
            ..._filteredSiswaList.map((siswa) {
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    // Kolom Nama Siswa - Tetap
                    Container(
                      width: 120,
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            siswa.nama ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          Text(
                            '${languageProvider.getTranslatedText({'en': 'NIS', 'id': 'NIS'})}: ${siswa.nis ?? ''}',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    // Kolom Nilai (Dynamic)
                    ..._filteredJenisNilaiList.expand((jenis) {
                      final dates = _assessmentDates[jenis] ?? [];

                      List<Widget> columns = [];

                      // Existing date columns
                      for (var date in dates) {
                        final nilai = _getNilaiForSiswaAndJenisAndDate(
                          siswa.id,
                          jenis,
                          date,
                        );
                        final nilaiText = nilai?.isNotEmpty == true
                            ? nilai!['nilai'].toString()
                            : '-';
                        final hasValue = nilai?.isNotEmpty == true;

                        columns.add(
                          Container(
                            width: 90,
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: GestureDetector(
                              onTap: () => _openInputForm(
                                siswa,
                                jenis,
                                languageProvider,
                                date: date,
                              ),
                              child: Container(
                                height: 40,
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: hasValue
                                      ? Colors.green.shade50
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: hasValue
                                        ? Colors.green.shade200
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    nilaiText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: hasValue
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: hasValue
                                          ? Colors.green.shade800
                                          : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      // Spacer for Add button column
                      columns.add(
                        Container(
                          width: 50,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade200),
                            ),
                            color: Colors.grey.shade50.withOpacity(0.5),
                          ),
                        ),
                      );

                      return columns;
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getJenisNilaiLabel(String jenis, LanguageProvider languageProvider) {
    switch (jenis) {
      case 'harian':
        return languageProvider.getTranslatedText({
          'en': 'Daily',
          'id': 'Harian',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'ulangan':
        return languageProvider.getTranslatedText({
          'en': 'Quiz',
          'id': 'Ulangan',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      default:
        return jenis;
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final activeFilterCount = _jenisNilaiFilter.values
            .where((v) => v)
            .length;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              '${languageProvider.getTranslatedText({'en': 'Grades', 'id': 'Nilai'})} - ${widget.subject['nama']} - ${widget.kelas['nama']}',
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
              // Tombol Filter dengan badge
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.filter_list, color: Colors.black),
                    onPressed: () => _showFilterDialog(languageProvider),
                    tooltip: languageProvider.getTranslatedText({
                      'en': 'Filter Grade Types',
                      'id': 'Filter Jenis Nilai',
                    }),
                  ),
                  if (activeFilterCount < _allJenisNilaiList.length)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '${_allJenisNilaiList.length - activeFilterCount}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
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
                    'en': 'Loading grade data...',
                    'id': 'Memuat data nilai...',
                  }),
                )
              : Column(
                  children: [
                    // Header Info
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.subject['nama']} - ${widget.kelas['nama']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${languageProvider.getTranslatedText({'en': 'Grade types', 'id': 'Jenis nilai'})}: ${_filteredJenisNilaiList.map((jenis) => _getJenisNilaiLabel(jenis, languageProvider)).join(', ')}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Bar
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: languageProvider.getTranslatedText({
                              'en': 'Search students...',
                              'id': 'Cari siswa...',
                            }),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade600,
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

                    if (_filteredSiswaList.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              '${_filteredSiswaList.length} ${languageProvider.getTranslatedText({'en': 'students found', 'id': 'siswa ditemukan'})}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(height: 8),

                    // Instruction
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Click on grade cells to input/edit',
                          'id':
                              'Klik pada kolom nilai untuk menginput/mengedit',
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),

                    // Tabel Nilai
                    Expanded(
                      child: _filteredSiswaList.isEmpty
                          ? EmptyState(
                              title: languageProvider.getTranslatedText({
                                'en': 'No students found',
                                'id': 'Tidak ada siswa',
                              }),
                              subtitle: _searchController.text.isEmpty
                                  ? languageProvider.getTranslatedText({
                                      'en': 'No students in this class',
                                      'id': 'Tidak ada siswa di kelas ini',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'No search results found',
                                      'id': 'Tidak ditemukan hasil pencarian',
                                    }),
                              icon: Icons.people_outline,
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: _buildGradeTable(languageProvider),
                            ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openNewInputForm(languageProvider),
            backgroundColor: _getPrimaryColor(),
            foregroundColor: Colors.white,
            child: Icon(Icons.add),
          ),
        );
      },
    );
  }
}

// Form Input Nilai Individual
class GradeInputForm extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final Siswa siswa;
  final String jenisNilai;
  final Map<String, dynamic>? existingNilai;
  final DateTime? initialDate;

  const GradeInputForm({
    super.key,
    required this.teacher,
    required this.subject,
    required this.siswa,
    required this.jenisNilai,
    this.existingNilai,
    this.initialDate,
  });

  @override
  GradeInputFormState createState() => GradeInputFormState();
}

class GradeInputFormState extends State<GradeInputForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nilaiController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Pre-fill data jika edit
    if (widget.existingNilai != null) {
      _nilaiController.text = widget.existingNilai!['nilai'].toString();
      _deskripsiController.text =
          widget.existingNilai!['deskripsi']?.toString() ?? '';

      if (widget.existingNilai!['tanggal'] != null) {
        _selectedDate = DateTime.parse(widget.existingNilai!['tanggal']);
      }
    } else if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    }
  }

  @override
  void dispose() {
    _nilaiController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitNilai() async {
    if (_formKey.currentState!.validate()) {
      try {
        final data = {
          'siswa_id': widget.siswa.id,
          'guru_id': widget.teacher['id'],
          'mata_pelajaran_id': widget.subject['id'],
          'jenis': widget.jenisNilai,
          'nilai': double.parse(_nilaiController.text),
          'deskripsi': _deskripsiController.text,
          'tanggal':
              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        };

        if (widget.existingNilai != null) {
          // Update nilai yang sudah ada
          await ApiService().put('/nilai/${widget.existingNilai!['id']}', data);
        } else {
          // Tambah nilai baru
          await ApiService().post('/nilai', data);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<LanguageProvider>().getTranslatedText({
                'en': widget.existingNilai != null
                    ? 'Grade successfully updated'
                    : 'Grade successfully saved',
                'id': widget.existingNilai != null
                    ? 'Nilai berhasil diupdate'
                    : 'Nilai berhasil disimpan',
              }),
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.read<LanguageProvider>().getTranslatedText({'en': 'Error:', 'id': 'Error:'})} $e',
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getJenisNilaiLabel(String jenis, LanguageProvider languageProvider) {
    switch (jenis) {
      case 'harian':
        return languageProvider.getTranslatedText({
          'en': 'Daily',
          'id': 'Harian',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'ulangan':
        return languageProvider.getTranslatedText({
          'en': 'Quiz',
          'id': 'Ulangan',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      default:
        return jenis;
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
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
                'en': 'Input Grade',
                'id': 'Input Nilai',
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
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Container(height: 1, color: Colors.grey.shade300),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Info Siswa dan Mata Pelajaran
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person, color: _getPrimaryColor()),
                            SizedBox(width: 8),
                            Text(
                              '${languageProvider.getTranslatedText({'en': 'Student', 'id': 'Siswa'})}: ${widget.siswa.nama}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getPrimaryColor(),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.badge, color: _getPrimaryColor()),
                            SizedBox(width: 8),
                            Text(
                              '${languageProvider.getTranslatedText({'en': 'NIS', 'id': 'NIS'})}: ${widget.siswa.nis}',
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.menu_book, color: _getPrimaryColor()),
                            SizedBox(width: 8),
                            Text(
                              '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})}: ${widget.subject['nama']}',
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.assignment, color: _getPrimaryColor()),
                            SizedBox(width: 8),
                            Text(
                              '${languageProvider.getTranslatedText({'en': 'Type', 'id': 'Jenis'})}: ${_getJenisNilaiLabel(widget.jenisNilai, languageProvider)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Input Nilai
                  TextFormField(
                    controller: _nilaiController,
                    decoration: InputDecoration(
                      labelText: languageProvider.getTranslatedText({
                        'en': 'Grade',
                        'id': 'Nilai',
                      }),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.score, color: _getPrimaryColor()),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return languageProvider.getTranslatedText({
                          'en': 'Please enter grade',
                          'id': 'Masukkan nilai',
                        });
                      }
                      if (double.tryParse(value) == null) {
                        return languageProvider.getTranslatedText({
                          'en': 'Please enter valid number',
                          'id': 'Masukkan angka yang valid',
                        });
                      }
                      final nilai = double.parse(value);
                      if (nilai < 0 || nilai > 100) {
                        return languageProvider.getTranslatedText({
                          'en': 'Grade must be between 0-100',
                          'id': 'Nilai harus antara 0-100',
                        });
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Input Deskripsi
                  TextFormField(
                    controller: _deskripsiController,
                    decoration: InputDecoration(
                      labelText: languageProvider.getTranslatedText({
                        'en': 'Description',
                        'id': 'Deskripsi',
                      }),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(
                        Icons.description,
                        color: _getPrimaryColor(),
                      ),
                    ),
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),

                  // Pilih Tanggal
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: _getPrimaryColor()),
                        SizedBox(width: 12),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Date:',
                            'id': 'Tanggal:',
                          }),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Spacer(),
                        TextButton(
                          onPressed: () => _selectDate(context),
                          child: Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: TextStyle(
                              fontSize: 16,
                              color: _getPrimaryColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tombol Simpan
                  ElevatedButton(
                    onPressed: _submitNilai,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPrimaryColor(),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.existingNilai != null
                          ? languageProvider.getTranslatedText({
                              'en': 'Update Grade',
                              'id': 'Update Nilai',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Save Grade',
                              'id': 'Simpan Nilai',
                            }),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Form Input Nilai Baru untuk Multiple Siswa
class GradeInputFormNew extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final List<Siswa> siswaList;

  const GradeInputFormNew({
    super.key,
    required this.teacher,
    required this.subject,
    required this.siswaList,
  });

  @override
  GradeInputFormNewState createState() => GradeInputFormNewState();
}

class GradeInputFormNewState extends State<GradeInputFormNew> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();

  // Variabel untuk state
  String? _selectedJenisNilai;
  final List<String> _jenisNilaiList = [
    'harian',
    'tugas',
    'ulangan',
    'uts',
    'uas',
  ];

  // Map untuk menyimpan nilai per siswa
  final Map<String, Map<String, dynamic>> _nilaiSiswaMap = {};

  @override
  void initState() {
    super.initState();
    // Initialize map dengan nilai default untuk setiap siswa
    for (var siswa in widget.siswaList) {
      _nilaiSiswaMap[siswa.id] = {'nilai': '', 'deskripsi': ''};
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitNilai() async {
    final languageProvider = context.read<LanguageProvider>();

    if (_formKey.currentState!.validate()) {
      if (_selectedJenisNilai == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Please select grade type first',
                'id': 'Pilih jenis nilai terlebih dahulu',
              }),
            ),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Cek apakah ada setidaknya satu siswa yang memiliki nilai
      bool hasData = false;
      for (var siswa in widget.siswaList) {
        final nilaiData = _nilaiSiswaMap[siswa.id];
        if (nilaiData?['nilai']?.isNotEmpty == true) {
          hasData = true;
          break;
        }
      }

      if (!hasData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Enter grade for at least one student',
                'id': 'Masukkan nilai untuk setidaknya satu siswa',
              }),
            ),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      try {
        int successCount = 0;

        for (var siswa in widget.siswaList) {
          final nilaiData = _nilaiSiswaMap[siswa.id];
          final nilai = nilaiData?['nilai']?.toString().trim();

          // Skip jika tidak ada nilai yang diinput
          if (nilai == null || nilai.isEmpty) {
            continue;
          }

          final data = {
            'siswa_id': siswa.id,
            'guru_id': widget.teacher['id'],
            'mata_pelajaran_id': widget.subject['id'],
            'jenis': _selectedJenisNilai!,
            'nilai': double.parse(nilai),
            'deskripsi': nilaiData?['deskripsi']?.toString().trim() ?? '',
            'tanggal':
                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
          };

          // Tambah nilai baru
          await ApiService().post('/nilai', data);
          successCount++;
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': '$successCount grades successfully saved',
                'id': '$successCount nilai berhasil disimpan',
              }),
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
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
  }

  String _getJenisNilaiLabel(String jenis, LanguageProvider languageProvider) {
    switch (jenis) {
      case 'harian':
        return languageProvider.getTranslatedText({
          'en': 'Daily',
          'id': 'Harian',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'ulangan':
        return languageProvider.getTranslatedText({
          'en': 'Quiz',
          'id': 'Ulangan',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      default:
        return jenis;
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  Widget _buildSiswaInputCard(Siswa siswa, LanguageProvider languageProvider) {
    final nilaiData = _nilaiSiswaMap[siswa.id] ?? {};
    final nilaiController = TextEditingController(
      text: nilaiData['nilai'] ?? '',
    );
    final deskripsiController = TextEditingController(
      text: nilaiData['deskripsi'] ?? '',
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getPrimaryColor().withOpacity(0.1),
          child: Text(
            siswa.nama.substring(0, 1).toUpperCase(),
            style: TextStyle(color: _getPrimaryColor()),
          ),
        ),
        title: Text(siswa.nama, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          '${languageProvider.getTranslatedText({'en': 'NIS', 'id': 'NIS'})}: ${siswa.nis ?? '-'}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Input Nilai
                TextFormField(
                  controller: nilaiController,
                  decoration: InputDecoration(
                    labelText: languageProvider.getTranslatedText({
                      'en': 'Grade',
                      'id': 'Nilai',
                    }),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.score, color: _getPrimaryColor()),
                    hintText: languageProvider.getTranslatedText({
                      'en': 'Enter grade 0-100',
                      'id': 'Masukkan nilai 0-100',
                    }),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    _nilaiSiswaMap[siswa.id]?['nilai'] = value;
                  },
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (double.tryParse(value) == null) {
                        return languageProvider.getTranslatedText({
                          'en': 'Please enter valid number',
                          'id': 'Masukkan angka yang valid',
                        });
                      }
                      final nilai = double.parse(value);
                      if (nilai < 0 || nilai > 100) {
                        return languageProvider.getTranslatedText({
                          'en': 'Grade must be between 0-100',
                          'id': 'Nilai harus antara 0-100',
                        });
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Input Deskripsi
                TextFormField(
                  controller: deskripsiController,
                  decoration: InputDecoration(
                    labelText: languageProvider.getTranslatedText({
                      'en': 'Description (Optional)',
                      'id': 'Deskripsi (Opsional)',
                    }),
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(
                      Icons.description,
                      color: _getPrimaryColor(),
                    ),
                    hintText: languageProvider.getTranslatedText({
                      'en': 'Enter grade description',
                      'id': 'Masukkan deskripsi nilai',
                    }),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    _nilaiSiswaMap[siswa.id]?['deskripsi'] = value;
                  },
                ),
                const SizedBox(height: 8),
                // Status indicator
                if (nilaiData['nilai']?.isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade600,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Nilai'})}: ${nilaiData['nilai']}',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final siswaWithNilaiCount = widget.siswaList.where((siswa) {
          final nilaiData = _nilaiSiswaMap[siswa.id];
          return nilaiData?['nilai']?.isNotEmpty == true;
        }).length;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              languageProvider.getTranslatedText({
                'en': 'New Grade Input',
                'id': 'Input Nilai Baru',
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
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Container(height: 1, color: Colors.grey.shade300),
            ),
          ),
          body: Form(
            key: _formKey,
            child: Column(
              children: [
                // Header Info
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.menu_book,
                            color: _getPrimaryColor(),
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})}: ${widget.subject['nama']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _getPrimaryColor(),
                                  ),
                                ),
                                if (widget.subject['kode'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      '${languageProvider.getTranslatedText({'en': 'Code', 'id': 'Kode'})}: ${widget.subject['kode']}',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Pilih Jenis Nilai
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedJenisNilai,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.assignment,
                              color: _getPrimaryColor(),
                            ),
                            hintText: languageProvider.getTranslatedText({
                              'en': 'Select grade type',
                              'id': 'Pilih jenis nilai',
                            }),
                          ),
                          items: _jenisNilaiList.map((String jenis) {
                            return DropdownMenuItem<String>(
                              value: jenis,
                              child: Text(
                                _getJenisNilaiLabel(jenis, languageProvider),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedJenisNilai = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return languageProvider.getTranslatedText({
                                'en': 'Please select grade type',
                                'id': 'Pilih jenis nilai terlebih dahulu',
                              });
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Pilih Tanggal
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: _getPrimaryColor(),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Date:',
                                'id': 'Tanggal:',
                              }),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _selectDate(context),
                              child: Text(
                                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _getPrimaryColor(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Header List Siswa
                if (_selectedJenisNilai != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Student List',
                            'id': 'Daftar Siswa',
                          }),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: siswaWithNilaiCount > 0
                                ? Colors.green.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: siswaWithNilaiCount > 0
                                  ? Colors.green.shade200
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            '$siswaWithNilaiCount/${widget.siswaList.length} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                            style: TextStyle(
                              color: siswaWithNilaiCount > 0
                                  ? Colors.green.shade800
                                  : Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Click on student name to input grade',
                        'id': 'Klik pada nama siswa untuk menginput nilai',
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],

                // List Siswa dengan Input Nilai
                if (_selectedJenisNilai != null) ...[
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.siswaList.length,
                      itemBuilder: (context, index) {
                        final siswa = widget.siswaList[index];
                        return _buildSiswaInputCard(siswa, languageProvider);
                      },
                    ),
                  ),
                ] else ...[
                  const Expanded(
                    child: EmptyState(
                      title: 'Select grade type',
                      subtitle:
                          'Please select grade type first to see student list',
                      icon: Icons.assignment,
                    ),
                  ),
                ],

                // Tombol Simpan
                if (_selectedJenisNilai != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _submitNilai,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getPrimaryColor(),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Save All Grades',
                          'id': 'Simpan Semua Nilai',
                        }),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
