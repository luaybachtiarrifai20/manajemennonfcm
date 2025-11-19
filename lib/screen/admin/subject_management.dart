import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/excel_subject_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:provider/provider.dart';
import 'package:manajemensekolah/components/confirmation_dialog.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/enhanced_search_bar.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';

class SubjectManagementScreen extends StatefulWidget {
  const SubjectManagementScreen({super.key});

  @override
  SubjectManagementScreenState createState() => SubjectManagementScreenState();
}

class SubjectManagementScreenState extends State<SubjectManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _subjectList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  // Search dan filter
  final TextEditingController _searchController = TextEditingController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _paginationMeta;

  // Filter States (Backend filtering)
  String? _selectedStatusFilter; // 'active', 'inactive', atau null untuk semua
  String?
  _selectedKategoriFilter; // 'Utama', 'Tambahan', 'Ekstrakurikuler', atau null untuk semua
  String?
  _selectedKelasStatusFilter; // 'ada', 'tidak_ada', atau null untuk semua
  String? _selectedGradeLevelFilter; // '1' sampai '12', atau null untuk semua
  String?
  _selectedClassNameFilter; // Nama kelas spesifik (7A, 7B, dll), atau null untuk semua
  bool _hasActiveFilter = false;

  // Dynamic list untuk nama kelas yang tersedia
  List<String> _availableClassNames = [];
  List<String> _availableGradeLevels = [];

  // Filter Options (from backend)
  List<dynamic> _availableStatusOptions = [];

  // Search debounce
  Timer? _searchDebounce;

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

    // Listen to scroll for infinite scroll
    _scrollController.addListener(_onScroll);

    // Listen to search changes with debounce
    _searchController.addListener(_onSearchChanged);

    _loadFilterOptions();
    _loadSubjects();
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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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
      _loadSubjects();
    });
  }

  Future<void> _loadFilterOptions() async {
    try {
      final response = await ApiSubjectService.getSubjectFilterOptions();
      
      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _availableStatusOptions = response['data']['status_options'] ?? [];
        });
        print('✅ Filter options loaded');
      }
    } catch (e) {
      print('Error loading filter options: $e');
      // Continue with empty options - not critical error
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedKategoriFilter != null ||
          _selectedKelasStatusFilter != null ||
          _selectedGradeLevelFilter != null ||
          _selectedClassNameFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedKategoriFilter = null;
      _selectedKelasStatusFilter = null;
      _selectedGradeLevelFilter = null;
      _selectedClassNameFilter = null;
      _searchController.clear();
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadSubjects(); // Reload data setelah clear filters
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedKategoriFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Category', 'id': 'Kategori'})}: $_selectedKategoriFilter',
        'onRemove': () {
          setState(() {
            _selectedKategoriFilter = null;
          });
          _checkActiveFilter();
          _loadSubjects();
        },
      });
    }

    if (_selectedKelasStatusFilter != null) {
      final statusText = _selectedKelasStatusFilter == 'ada'
          ? languageProvider.getTranslatedText({
              'en': 'Has Classes',
              'id': 'Ada Kelas',
            })
          : languageProvider.getTranslatedText({
              'en': 'No Classes',
              'id': 'Tidak Ada Kelas',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Classes', 'id': 'Kelas'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedKelasStatusFilter = null;
          });
          _checkActiveFilter();
          _loadSubjects();
        },
      });
    }

    if (_selectedGradeLevelFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Tingkat Kelas'})}: $_selectedGradeLevelFilter',
        'onRemove': () {
          setState(() {
            _selectedGradeLevelFilter = null;
          });
          _checkActiveFilter();
          _loadSubjects();
        },
      });
    }

    if (_selectedClassNameFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Nama Kelas'})}: $_selectedClassNameFilter',
        'onRemove': () {
          setState(() {
            _selectedClassNameFilter = null;
          });
          _checkActiveFilter();
          _loadSubjects();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = context.read<LanguageProvider>();

    // Temporary state for bottom sheet
    String? tempSelectedKategori = _selectedKategoriFilter;
    String? tempSelectedKelasStatus = _selectedKelasStatusFilter;
    String? tempSelectedGradeLevel = _selectedGradeLevelFilter;
    String? tempSelectedClassName = _selectedClassNameFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
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
                          tempSelectedKategori = null;
                          tempSelectedKelasStatus = null;
                          tempSelectedGradeLevel = null;
                          tempSelectedClassName = null;
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
                      // Kategori Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Category',
                          'id': 'Kategori',
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
                        children: ['Utama', 'Tambahan', 'Ekstrakurikuler'].map((
                          kategori,
                        ) {
                          final isSelected = tempSelectedKategori == kategori;
                          return FilterChip(
                            label: Text(kategori),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedKategori = selected
                                    ? kategori
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

                      // Status Kelas Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Classes Status',
                          'id': 'Status Kelas',
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
                        children:
                            [
                              {
                                'value': 'ada',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Has Classes',
                                  'id': 'Ada Kelas',
                                }),
                              },
                              {
                                'value': 'tidak_ada',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'No Classes',
                                  'id': 'Tidak Ada Kelas',
                                }),
                              },
                            ].map((item) {
                              final isSelected =
                                  tempSelectedKelasStatus == item['value'];
                              return FilterChip(
                                label: Text(item['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempSelectedKelasStatus = selected
                                        ? item['value']
                                        : null;
                                  });
                                },
                                backgroundColor: Colors.grey.shade100,
                                selectedColor: _getPrimaryColor().withOpacity(
                                  0.2,
                                ),
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

                      // Tingkat Kelas Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Grade Level',
                          'id': 'Tingkat Kelas',
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
                        children: _availableGradeLevels.isEmpty
                            ? List.generate(12, (index) {
                                final gradeLevel = (index + 1).toString();
                                final isSelected =
                                    tempSelectedGradeLevel == gradeLevel;
                                return FilterChip(
                                  label: Text('Kelas $gradeLevel'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      tempSelectedGradeLevel = selected
                                          ? gradeLevel
                                          : null;
                                    });
                                  },
                                  backgroundColor: Colors.grey.shade100,
                                  selectedColor: _getPrimaryColor().withOpacity(
                                    0.2,
                                  ),
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
                              }).toList()
                            : _availableGradeLevels.map((gradeLevel) {
                                final isSelected =
                                    tempSelectedGradeLevel == gradeLevel;
                                return FilterChip(
                                  label: Text('Kelas $gradeLevel'),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      tempSelectedGradeLevel = selected
                                          ? gradeLevel
                                          : null;
                                    });
                                  },
                                  backgroundColor: Colors.grey.shade100,
                                  selectedColor: _getPrimaryColor().withOpacity(
                                    0.2,
                                  ),
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

                      // Class Name Filter (Dynamic)
                      if (_availableClassNames.isNotEmpty) ...[
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Class Name',
                            'id': 'Nama Kelas',
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
                          children: _availableClassNames.map((className) {
                            final isSelected =
                                tempSelectedClassName == className;
                            return FilterChip(
                              label: Text(className),
                              selected: isSelected,
                              onSelected: (selected) {
                                setModalState(() {
                                  tempSelectedClassName = selected
                                      ? className
                                      : null;
                                });
                              },
                              backgroundColor: Colors.grey.shade100,
                              selectedColor: _getPrimaryColor().withOpacity(
                                0.2,
                              ),
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
                      ],
                    ],
                  ),
                ),
              ),
              // Apply Button
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedKategoriFilter = tempSelectedKategori;
                        _selectedKelasStatusFilter = tempSelectedKelasStatus;
                        _selectedGradeLevelFilter = tempSelectedGradeLevel;
                        _selectedClassNameFilter = tempSelectedClassName;
                      });
                      _checkActiveFilter();
                      Navigator.pop(context);
                      _loadSubjects(); // Reload data setelah apply filter
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPrimaryColor(),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Apply Filter',
                        'id': 'Terapkan Filter',
                      }),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSubjects({bool resetPage = true}) async {
    try {
      if (resetPage) {
        setState(() {
          _isLoading = true;
          _currentPage = 1;
          _hasMoreData = true;
          _subjectList = []; // Reset list
          _errorMessage = '';
        });
      }

      // Load with pagination and backend filtering
      final response = await ApiSubjectService.getSubjectsPaginated(
        page: _currentPage,
        limit: _perPage,
        status: _selectedStatusFilter,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );

      if (!mounted) return;

      final data = response['data'] ?? [];
      
      // Extract unique class names and grade levels from subjects
      Set<String> classNamesSet = {};
      Set<String> gradeLevelsSet = {};

      for (var subject in data) {
        final kelasNames = subject['kelas_names']?.toString() ?? '';
        if (kelasNames.isNotEmpty) {
          final names = kelasNames
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          classNamesSet.addAll(names);
        }

        // Extract grade levels
        final kelasGradeLevels =
            subject['kelas_grade_levels']?.toString() ?? '';
        if (kelasGradeLevels.isNotEmpty) {
          final levels = kelasGradeLevels
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          gradeLevelsSet.addAll(levels);
        }
      }

      setState(() {
        _subjectList = data;
        _availableClassNames = classNamesSet.toList()..sort();
        _availableGradeLevels = gradeLevelsSet.toList()
          ..sort((a, b) {
            final aInt = int.tryParse(a) ?? 0;
            final bInt = int.tryParse(b) ?? 0;
            return aInt.compareTo(bInt);
          });
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
        _errorMessage = '';
      });

      _animationController.forward();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load subject data: $error';
      });
    }
  }

  Future<void> _loadMoreSubjects() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      final response = await ApiSubjectService.getSubjectsPaginated(
        page: _currentPage,
        limit: _perPage,
        status: _selectedStatusFilter,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );

      if (!mounted) return;

      final data = response['data'] ?? [];
      
      // Extract class names and grade levels
      Set<String> classNamesSet = Set.from(_availableClassNames);
      Set<String> gradeLevelsSet = Set.from(_availableGradeLevels);

      for (var subject in data) {
        final kelasNames = subject['kelas_names']?.toString() ?? '';
        if (kelasNames.isNotEmpty) {
          final names = kelasNames
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          classNamesSet.addAll(names);
        }

        final kelasGradeLevels = subject['kelas_grade_levels']?.toString() ?? '';
        if (kelasGradeLevels.isNotEmpty) {
          final levels = kelasGradeLevels
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          gradeLevelsSet.addAll(levels);
        }
      }

      setState(() {
        // Append new data to existing list
        _subjectList.addAll(data);
        _availableClassNames = classNamesSet.toList()..sort();
        _availableGradeLevels = gradeLevelsSet.toList()
          ..sort((a, b) {
            final aInt = int.tryParse(a) ?? 0;
            final bInt = int.tryParse(b) ?? 0;
            return aInt.compareTo(bInt);
          });
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      print('✅ Loaded more subjects: Page $_currentPage, Total: ${_subjectList.length}');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });

      print('Error loading more data: $e');
    }
  }

  Future<void> _exportToExcel() async {
    await ExcelSubjectService.exportSubjectsToExcel(
      subjects: _subjectList,
      context: context,
    );
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
        await ApiSubjectService.importSubjectFromExcel(
          File(result.files.single.path!),
        );

        // Refresh data setelah import
        await _loadSubjects();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Failed to import file: $e',
              'id': 'Gagal mengimpor file: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadTemplate() async {
    await ExcelSubjectService.downloadTemplate(context);
  }

  void _showAddEditDialog({Map<String, dynamic>? subject}) {
    final codeController = TextEditingController(text: subject?['kode']);
    final nameController = TextEditingController(text: subject?['nama']);
    final descriptionController = TextEditingController(
      text: subject?['deskripsi'],
    );

    showDialog(
      context: context,
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
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
                      gradient: _getCardGradient(),
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
                            subject == null ? Icons.add : Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            subject == null
                                ? languageProvider.getTranslatedText({
                                    'en': 'Add Subject',
                                    'id': 'Tambah Mata Pelajaran',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Edit Subject',
                                    'id': 'Edit Mata Pelajaran',
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDialogTextField(
                          controller: codeController,
                          label: languageProvider.getTranslatedText({
                            'en': 'Code',
                            'id': 'Kode',
                          }),
                          icon: Icons.code,
                        ),
                        SizedBox(height: 12),
                        _buildDialogTextField(
                          controller: nameController,
                          label: languageProvider.getTranslatedText({
                            'en': 'Subject Name',
                            'id': 'Nama Mata Pelajaran',
                          }),
                          icon: Icons.menu_book,
                        ),
                        SizedBox(height: 12),
                        _buildDialogTextField(
                          controller: descriptionController,
                          label: languageProvider.getTranslatedText({
                            'en': 'Description',
                            'id': 'Deskripsi',
                          }),
                          icon: Icons.description,
                          maxLines: 3,
                        ),
                      ],
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
                            onPressed: () async {
                              if (codeController.text.isEmpty ||
                                  nameController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Code and name must be filled',
                                        'id': 'Kode dan nama harus diisi',
                                      }),
                                    ),
                                    backgroundColor: Colors.red.shade400,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              try {
                                final data = {
                                  'kode': codeController.text,
                                  'nama': nameController.text,
                                  'deskripsi': descriptionController.text,
                                };

                                if (subject == null) {
                                  await _apiService.post(
                                    '/mata-pelajaran',
                                    data,
                                  );
                                } else {
                                  await _apiService.put(
                                    '/mata-pelajaran/${subject['id']}',
                                    data,
                                  );
                                }
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                _loadSubjects();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.getTranslatedText({
                                          'en': 'Data saved successfully',
                                          'id': 'Data berhasil disimpan',
                                        }),
                                      ),
                                      backgroundColor: Colors.green.shade400,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.getTranslatedText({
                                          'en': 'Failed to save data',
                                          'id': 'Gagal menyimpan data',
                                        }),
                                      ),
                                      backgroundColor: Colors.red.shade400,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              AppLocalizations.save.tr,
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
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Future<void> _deleteSubject(Map<String, dynamic> subject) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return ConfirmationDialog(
            title: languageProvider.getTranslatedText({
              'en': 'Delete Subject',
              'id': 'Hapus Mata Pelajaran',
            }),
            content: languageProvider.getTranslatedText({
              'en':
                  'Are you sure you want to delete subject "${subject['nama']}"?',
              'id':
                  'Yakin ingin menghapus mata pelajaran "${subject['nama']}"?',
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
        await _apiService.delete('/mata-pelajaran/${subject['id']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<LanguageProvider>().getTranslatedText({
                  'en': 'Subject successfully deleted',
                  'id': 'Mata pelajaran berhasil dihapus',
                }),
              ),
              backgroundColor: Colors.green.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadSubjects();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<LanguageProvider>().getTranslatedText({
                  'en': 'Failed to delete subject',
                  'id': 'Gagal menghapus mata pelajaran',
                }),
              ),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  // Navigasi ke halaman manajemen kelas untuk mata pelajaran
  void _navigateToClassManagement(Map<String, dynamic> subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubjectClassManagementPage(subject: subject),
      ),
    );
  }

  List<dynamic> _getFilteredSubjects() {
    return _subjectList.where((subject) {
      final searchTerm = _searchController.text.toLowerCase();
      final subjectName = subject['nama']?.toString().toLowerCase() ?? '';
      final subjectCode = subject['kode']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          subjectCode.contains(searchTerm);

      // Kategori filter
      final kategori = subject['kategori']?.toString() ?? '';
      final matchesKategoriFilter =
          _selectedKategoriFilter == null ||
          kategori == _selectedKategoriFilter;

      // Kelas status filter
      final hasClasses = (subject['jumlah_kelas'] ?? 0) > 0;
      final matchesKelasStatusFilter =
          _selectedKelasStatusFilter == null ||
          (_selectedKelasStatusFilter == 'ada' && hasClasses) ||
          (_selectedKelasStatusFilter == 'tidak_ada' && !hasClasses);

      // Tingkat Kelas filter (1-12)
      final kelasNames = subject['kelas_names']?.toString() ?? '';
      final kelasGradeLevelsStr =
          subject['kelas_grade_levels']?.toString() ?? '';

      final matchesGradeLevelFilter =
          _selectedGradeLevelFilter == null ||
          (kelasGradeLevelsStr.isNotEmpty &&
              kelasGradeLevelsStr
                  .split(',')
                  .map((e) => e.trim())
                  .contains(_selectedGradeLevelFilter));

      // Class Name filter
      final matchesClassNameFilter =
          _selectedClassNameFilter == null ||
          (kelasNames.isNotEmpty &&
              kelasNames
                  .split(',')
                  .map((e) => e.trim())
                  .contains(_selectedClassNameFilter));

      return matchesSearch &&
          matchesKategoriFilter &&
          matchesKelasStatusFilter &&
          matchesGradeLevelFilter &&
          matchesClassNameFilter;
    }).toList();
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject, int index) {
    final languageProvider = context.read<LanguageProvider>();
    final kelasCount = subject['jumlah_kelas'] ?? 0;
    final kelasNames = subject['kelas_names']?.toString().split(',') ?? [];

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
      child: GestureDetector(
        onTap: () => _navigateToClassManagement(subject),
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _navigateToClassManagement(subject),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header dengan nama dan kode
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject['nama'] ?? 'No Name',
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
                                      'Kode: ${subject['kode'] ?? 'No Code'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
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
                                  '$kelasCount ' +
                                      languageProvider.getTranslatedText({
                                        'en': 'Classes',
                                        'id': 'Kelas',
                                      }),
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

                          // Informasi kelas
                          if (kelasNames.isNotEmpty)
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
                                    Icons.class_,
                                    color: _getPrimaryColor(),
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
                                          'en': 'Registered Classes',
                                          'id': 'Kelas Terdaftar',
                                        }),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 1),
                                      Text(
                                        kelasNames.take(2).join(', ') +
                                            (kelasNames.length > 2
                                                ? '...'
                                                : ''),
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

                          // Informasi deskripsi
                          if (subject['deskripsi'] != null &&
                              subject['deskripsi'].isNotEmpty) ...[
                            SizedBox(height: 8),
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
                                        subject['deskripsi'],
                                        style: TextStyle(
                                          fontSize: 12,
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
                                backgroundColor: Colors.white,
                                borderColor: _getPrimaryColor(),
                                onPressed: () =>
                                    _showAddEditDialog(subject: subject),
                              ),
                              SizedBox(width: 8),
                              _buildActionButton(
                                icon: Icons.delete,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Delete',
                                  'id': 'Hapus',
                                }),
                                color: Colors.red,
                                backgroundColor: Colors.white,
                                borderColor: Colors.red,
                                onPressed: () => _deleteSubject(subject),
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
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    Color? backgroundColor,
    Color? borderColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor ?? Colors.white.withOpacity(0.3),
            width: 1,
          ),
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

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withOpacity(0.7)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return LoadingScreen(
            message: languageProvider.getTranslatedText({
              'en': 'Loading subject data...',
              'id': 'Memuat data mata pelajaran...',
            }),
          );
        }

        if (_errorMessage.isNotEmpty) {
          return ErrorScreen(
            errorMessage: _errorMessage,
            onRetry: _loadSubjects,
          );
        }

        final filteredSubjects = _getFilteredSubjects();

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_getPrimaryColor(), _getPrimaryColor()],
                  ),
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
                                  'en': 'Subject Management',
                                  'id': 'Manajemen Mata Pelajaran',
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
                                  'en': 'Manage and monitor subjects',
                                  'id': 'Kelola dan pantau mata pelajaran',
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
                                  'en': 'Search subjects...',
                                  'id': 'Cari mata pelajaran...',
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

                    // Show active filters as chips
                    if (_hasActiveFilter) ...[
                      SizedBox(height: 12),
                      Container(
                        height: 42,
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.filter_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
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
                                        backgroundColor: _getPrimaryColor()
                                            .withOpacity(0.1),
                                        side: BorderSide(
                                          color: _getPrimaryColor().withOpacity(
                                            0.3,
                                          ),
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

              if (filteredSubjects.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${filteredSubjects.length} ${languageProvider.getTranslatedText({'en': 'subjects found', 'id': 'mata pelajaran ditemukan'})}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 4),
              Expanded(
                child: filteredSubjects.isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No subjects',
                          'id': 'Tidak ada mata pelajaran',
                        }),
                        subtitle:
                            _searchController.text.isEmpty && !_hasActiveFilter
                            ? languageProvider.getTranslatedText({
                                'en': 'Tap + to add a subject',
                                'id': 'Tap + untuk menambah mata pelajaran',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: Icons.school_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSubjects,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(16),
                          itemCount: filteredSubjects.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index == filteredSubjects.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            
                            return _buildSubjectCard(
                              filteredSubjects[index],
                              index,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddEditDialog(),
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
}

// Halaman Manajemen Kelas untuk Mata Pelajaran (Updated dengan style yang sama)
class SubjectClassManagementPage extends StatefulWidget {
  final Map<String, dynamic> subject;

  const SubjectClassManagementPage({super.key, required this.subject});

  @override
  SubjectClassManagementPageState createState() =>
      SubjectClassManagementPageState();
}

class SubjectClassManagementPageState extends State<SubjectClassManagementPage>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _availableClasses = [];
  List<dynamic> _assignedClasses = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Filter options untuk EnhancedSearchBar
  final List<String> _filterOptions = ['All', 'Assigned', 'Unassigned'];
  String _selectedFilter = 'All';

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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load semua kelas yang tersedia
      final allClassesResponse = await _apiService.get('/kelas');

      // Load kelas yang sudah ditetapkan untuk mata pelajaran ini
      // getKelasByMataPelajaran already returns List<dynamic>
      final assignedClasses = await _apiService.getKelasByMataPelajaran(
        widget.subject['id'].toString(),
      );

      // Handle both Map (pagination) and List formats for allClasses
      List<dynamic> allClasses;
      if (allClassesResponse is Map<String, dynamic>) {
        allClasses = allClassesResponse['data'] ?? [];
      } else if (allClassesResponse is List) {
        allClasses = allClassesResponse;
      } else {
        allClasses = [];
      }

      setState(() {
        _availableClasses = allClasses;
        _assignedClasses = assignedClasses;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addClassToSubject(Map<String, dynamic> kelas) async {
    try {
      await _apiService.post('/mata-pelajaran-kelas', {
        'mata_pelajaran_id': widget.subject['id'],
        'kelas_id': kelas['id'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kelas ${kelas['nama']} berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeClassFromSubject(Map<String, dynamic> kelas) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Hapus Kelas',
        content:
            'Yakin ingin menghapus kelas ${kelas['nama']} dari mata pelajaran ini?',
        confirmText: 'Hapus',
        confirmColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.delete(
          '/mata-pelajaran-kelas?mata_pelajaran_id=${widget.subject['id']}&kelas_id=${kelas['id']}',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Kelas ${kelas['nama']} berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
        }

        _loadData();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Method untuk menambah kelas secara cepat
  void _showQuickAddClassDialog() {
    final unassignedClasses = _availableClasses.where((kelas) {
      return !_isClassAssigned(kelas['id']);
    }).toList();

    if (unassignedClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Semua kelas sudah ditambahkan ke mata pelajaran ini'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
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
                      gradient: _getCardGradient(),
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
                            Icons.add_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tambah Kelas',
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pilih kelas yang ingin ditambahkan ke ${widget.subject['nama']}:',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),

                        // Search bar dalam dialog
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Cari kelas...',
                              prefixIcon: Icon(
                                Icons.search,
                                color: _getPrimaryColor(),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                            ),
                            onChanged: (value) {
                              setDialogState(() {});
                            },
                          ),
                        ),
                        SizedBox(height: 16),

                        Container(
                          constraints: BoxConstraints(maxHeight: 300),
                          child: unassignedClasses.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 48,
                                        color: Colors.green,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Semua kelas sudah ditambahkan',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: unassignedClasses.length,
                                  itemBuilder: (context, index) {
                                    final kelas = unassignedClasses[index];
                                    return Card(
                                      margin: EdgeInsets.symmetric(vertical: 4),
                                      elevation: 1,
                                      child: ListTile(
                                        leading: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: _getPrimaryColor()
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.class_,
                                            color: _getPrimaryColor(),
                                            size: 18,
                                          ),
                                        ),
                                        title: Text(
                                          kelas['nama'] ?? 'Kelas',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (kelas['tingkat'] != null)
                                              Text(
                                                'Tingkat: ${kelas['tingkat']}',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            if (kelas['wali_kelas_nama'] !=
                                                null)
                                              Text(
                                                'Wali: ${kelas['wali_kelas_nama']}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: Container(
                                          decoration: BoxDecoration(
                                            color: _getPrimaryColor(),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          padding: EdgeInsets.all(6),
                                          child: Icon(
                                            Icons.add,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _addClassToSubject(kelas);
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
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
                              'Batal',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Lihat Semua',
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
      ),
    );
  }

  bool _isClassAssigned(String kelasId) {
    return _assignedClasses.any((kelas) => kelas['id'] == kelasId);
  }

  List<dynamic> _getFilteredClasses() {
    final searchTerm = _searchController.text.toLowerCase();
    return _availableClasses.where((kelas) {
      final className = kelas['nama']?.toString().toLowerCase() ?? '';
      final classLevel = kelas['tingkat']?.toString().toLowerCase() ?? '';
      final homeroomTeacher =
          kelas['wali_kelas_nama']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          className.contains(searchTerm) ||
          classLevel.contains(searchTerm) ||
          homeroomTeacher.contains(searchTerm);

      final isAssigned = _isClassAssigned(kelas['id']);

      final matchesFilter =
          _selectedFilter == 'All' ||
          (_selectedFilter == 'Assigned' && isAssigned) ||
          (_selectedFilter == 'Unassigned' && !isAssigned);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Widget _buildClassCard(
    Map<String, dynamic> kelas,
    int index,
    bool isAssigned,
  ) {
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
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (isAssigned) {
                _removeClassFromSubject(kelas);
              } else {
                _addClassToSubject(kelas);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: isAssigned
                    ? _getCardGradient()
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.grey.shade100, Colors.grey.shade50],
                      ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (isAssigned ? _getPrimaryColor() : Colors.grey)
                        .withOpacity(0.2),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isAssigned
                      ? _getPrimaryColor().withOpacity(0.3)
                      : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Background pattern untuk kelas yang sudah ditetapkan
                  if (isAssigned)
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icon kelas
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isAssigned
                                ? Colors.white.withOpacity(0.2)
                                : _getPrimaryColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.class_,
                            color: isAssigned
                                ? Colors.white
                                : _getPrimaryColor(),
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),

                        // Informasi kelas
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                kelas['nama'] ?? 'Kelas',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isAssigned
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              SizedBox(height: 2),
                              if (kelas['tingkat'] != null)
                                Text(
                                  'Tingkat: ${kelas['tingkat']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isAssigned
                                        ? Colors.white.withOpacity(0.8)
                                        : Colors.grey[600],
                                  ),
                                ),
                              if (kelas['wali_kelas_nama'] != null)
                                Text(
                                  'Wali: ${kelas['wali_kelas_nama']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isAssigned
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.grey[500],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Status indicator
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isAssigned
                                ? Colors.white.withOpacity(0.2)
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAssigned
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAssigned
                                    ? Icons.check_circle
                                    : Icons.add_circle,
                                size: 12,
                                color: isAssigned
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
                              SizedBox(width: 4),
                              Text(
                                isAssigned ? 'Terdaftar' : 'Tambahkan',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isAssigned
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
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
            ),
          ),
        ),
      ),
    );
  }

  Color _getPrimaryColor() {
    return Color(0xFF4361EE); // Blue untuk admin
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withOpacity(0.7)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClasses = _getFilteredClasses();
    final assignedCount = _assignedClasses.length;

    // Terjemahan filter options
    final languageProvider = context.read<LanguageProvider>();
    final translatedFilterOptions = [
      languageProvider.getTranslatedText({'en': 'All', 'id': 'Semua'}),
      languageProvider.getTranslatedText({'en': 'Assigned', 'id': 'Terdaftar'}),
      languageProvider.getTranslatedText({
        'en': 'Unassigned',
        'id': 'Belum Terdaftar',
      }),
    ];

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject['nama'] ?? 'Subject',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Kelas Management',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
        backgroundColor: _getPrimaryColor(),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? LoadingScreen(message: 'Loading class data...')
          : Column(
              children: [
                // Quick stats
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: _getCardGradient(),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _getPrimaryColor().withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.class_,
                        value: _availableClasses.length.toString(),
                        label: 'Total Kelas',
                        color: Colors.white,
                      ),
                      _buildStatItem(
                        icon: Icons.check_circle,
                        value: assignedCount.toString(),
                        label: 'Terdaftar',
                        color: Colors.white,
                      ),
                      _buildStatItem(
                        icon: Icons.add_circle,
                        value: (_availableClasses.length - assignedCount)
                            .toString(),
                        label: 'Belum Terdaftar',
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),

                EnhancedSearchBar(
                  controller: _searchController,
                  hintText: 'Cari kelas...',
                  onChanged: (value) {
                    setState(() {});
                  },
                  filterOptions: translatedFilterOptions,
                  selectedFilter:
                      translatedFilterOptions[_selectedFilter == 'All'
                          ? 0
                          : _selectedFilter == 'Assigned'
                          ? 1
                          : 2],
                  onFilterChanged: (filter) {
                    final index = translatedFilterOptions.indexOf(filter);
                    setState(() {
                      _selectedFilter = index == 0
                          ? 'All'
                          : index == 1
                          ? 'Assigned'
                          : 'Unassigned';
                    });
                  },
                  showFilter: true,
                ),

                if (filteredClasses.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          '${filteredClasses.length} kelas ditemukan',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(height: 4),

                Expanded(
                  child: filteredClasses.isEmpty
                      ? EmptyState(
                          title: 'Tidak ada kelas',
                          subtitle:
                              _searchController.text.isEmpty &&
                                  _selectedFilter == 'All'
                              ? 'Semua kelas sudah ditampilkan'
                              : 'Tidak ditemukan hasil pencarian',
                          icon: Icons.class_outlined,
                        )
                      : ListView.builder(
                          itemCount: filteredClasses.length,
                          itemBuilder: (context, index) {
                            final kelas = filteredClasses[index];
                            final isAssigned = _isClassAssigned(kelas['id']);
                            return _buildClassCard(kelas, index, isAssigned);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQuickAddClassDialog,
        backgroundColor: _getPrimaryColor(),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.add, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }
}
