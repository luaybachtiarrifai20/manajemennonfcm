import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/confirmation_dialog.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/excel_class_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  ClassManagementScreenState createState() => ClassManagementScreenState();
}

class ClassManagementScreenState extends State<ClassManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiClassService _classService = ApiClassService();
  final ApiTeacherService _teacherService = ApiTeacherService();
  List<dynamic> _classes = [];
  List<dynamic> _teachers = [];
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _searchController = TextEditingController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _paginationMeta;

  // Filter States (Backend filtering)
  String? _selectedGradeFilter; // '1' to '12', or null for all
  bool _hasActiveFilter = false;

  // Filter Options (from backend)
  List<String> _availableGradeLevels = [];

  // Search debounce
  Timer? _searchDebounce;

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
    _fetchTeachers();
    _loadData();
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
      // 200px before bottom
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
      final response = await ApiClassService.getClassFilterOptions();

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _availableGradeLevels = List<String>.from(
            response['data']['grade_levels'] ?? [],
          );
        });
        print(
          '✅ Filter options loaded: ${_availableGradeLevels.length} grades',
        );
      }
    } catch (e) {
      print('Error loading filter options: $e');
      // Continue with empty options - not critical error
    }
  }

  Future<void> _fetchTeachers() async {
    try {
      final teachers = await _teacherService.getTeacher();
      if (!mounted) return;
      setState(() {
        _teachers = teachers;
      });
      print('✅ Loaded ${_teachers.length} teachers for wali kelas selection');
    } catch (e) {
      print('Error loading teachers: $e');
      // Continue with empty list - not critical error
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = _selectedGradeFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedGradeFilter = null;
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

    if (_selectedGradeFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})}: $_selectedGradeFilter',
        'onRemove': () {
          setState(() {
            _selectedGradeFilter = null;
          });
          _checkActiveFilter();
          _loadData(); // Reload data setelah remove filter
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = context.read<LanguageProvider>();

    // Temporary state for bottom sheet
    String? tempSelectedClass = _selectedGradeFilter;

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
                          tempSelectedClass = null;
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
                      // Kelas Filter (1-12)
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Grade (1-12)',
                          'id': 'Kelas (1-12)',
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
                        children: List.generate(12, (index) {
                          final kelas = (index + 1).toString();
                          final isSelected = tempSelectedClass == kelas;
                          return FilterChip(
                            label: Text(kelas),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedClass = selected ? kelas : null;
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
                        _selectedGradeFilter = tempSelectedClass;
                      });
                      _checkActiveFilter();
                      Navigator.pop(context);
                      _loadData(); // Reload data dengan filter baru
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

  Future<void> _loadData({bool resetPage = true}) async {
    try {
      if (resetPage) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _currentPage = 1;
          _hasMoreData = true;
          _classes = []; // Reset list
        });
      }

      final response = await ApiClassService.getClassPaginated(
        page: _currentPage,
        limit: _perPage,
        gradeLevel: _selectedGradeFilter,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _classes = response['data'] ?? [];
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': 'Failed to load class data: $e',
              'id': 'Gagal memuat data kelas: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      final response = await ApiClassService.getClassPaginated(
        page: _currentPage,
        limit: _perPage,
        gradeLevel: _selectedGradeFilter,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        // Append new data to existing list
        _classes.addAll(response['data'] ?? []);
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      print(
        '✅ Loaded more data: Page $_currentPage, Total items: ${_classes.length}',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });

      print('Error loading more data: $e');
    }
  }

  // Export classes to Excel
  Future<void> _exportToExcel() async {
    await ExcelClassService.exportClassesToExcel(
      classes: _classes,
      context: context,
    );
  }

  // Import classes from Excel
  Future<void> _importFromExcel() async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await ApiClassService.importClassesFromExcel(
          File(result.files.single.path!),
        );

        // Refresh data setelah import
        await _loadData();
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

  // Download template
  Future<void> _downloadTemplate() async {
    await ExcelClassService.downloadTemplate(context);
  }

  void _showAddEditDialog({Map<String, dynamic>? classData}) {
    final nameController = TextEditingController(
      text: classData?['nama'] ?? '',
    );

    final isEdit = classData != null;

    // Initialize state variables outside builder to preserve state across rebuilds
    String? selectedGradeLevel = classData != null
        ? classData['grade_level']?.toString()
        : null;
    String? selectedWaliKelasId = classData != null
        ? classData['wali_kelas_id']?.toString()
        : null;

    showDialog(
      context: context,
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
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
                                isEdit ? Icons.edit : Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isEdit
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Edit Class',
                                        'id': 'Edit Kelas',
                                      })
                                    : languageProvider.getTranslatedText({
                                        'en': 'Add Class',
                                        'id': 'Tambah Kelas',
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
                              controller: nameController,
                              label: languageProvider.getTranslatedText({
                                'en': 'Class Name',
                                'id': 'Nama Kelas',
                              }),
                              icon: Icons.school,
                            ),
                            SizedBox(height: 12),
                            _buildGradeLevelDropdown(
                              value: selectedGradeLevel,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedGradeLevel = value;
                                });
                              },
                              languageProvider: languageProvider,
                            ),
                            SizedBox(height: 12),
                            _buildWaliKelasDropdown(
                              value: selectedWaliKelasId,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedWaliKelasId = value;
                                });
                              },
                              languageProvider: languageProvider,
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
                                  final nama = nameController.text.trim();

                                  if (nama.isEmpty ||
                                      selectedGradeLevel == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          languageProvider.getTranslatedText({
                                            'en':
                                                'Class name and grade level must be filled',
                                            'id':
                                                'Nama kelas dan grade level harus diisi',
                                          }),
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  try {
                                    final data = {
                                      'nama': nama,
                                      'grade_level': int.parse(
                                        selectedGradeLevel!,
                                      ),
                                      'wali_kelas_id': selectedWaliKelasId,
                                    };

                                    if (isEdit) {
                                      await _classService.updateClass(
                                        classData['id'],
                                        data,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              languageProvider.getTranslatedText({
                                                'en':
                                                    'Class successfully updated',
                                                'id':
                                                    'Kelas berhasil diperbarui',
                                              }),
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        Navigator.pop(context);
                                      }
                                    } else {
                                      await _classService.addClass(data);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              languageProvider.getTranslatedText({
                                                'en':
                                                    'Class successfully added',
                                                'id':
                                                    'Kelas berhasil ditambahkan',
                                              }),
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        Navigator.pop(context);
                                      }
                                    }
                                    _loadData();
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            languageProvider.getTranslatedText({
                                              'en': 'Failed to save class: $e',
                                              'id': 'Gagal menyimpan kelas: $e',
                                            }),
                                          ),
                                          backgroundColor: Colors.red,
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
                                  isEdit
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Update',
                                          'id': 'Perbarui',
                                        })
                                      : AppLocalizations.save.tr,
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
        },
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildGradeLevelDropdown({
    required String? value,
    required Function(String?) onChanged,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({
            'en': 'Grade Level',
            'id': 'Tingkat Kelas',
          }),
          prefixIcon: Icon(Icons.grade, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: List.generate(12, (index) {
          final grade = index + 1;
          String gradeText;
          if (grade <= 6) {
            gradeText = 'Kelas $grade SD';
          } else if (grade <= 9) {
            gradeText = 'Kelas $grade SMP';
          } else {
            gradeText = 'Kelas $grade SMA';
          }

          return DropdownMenuItem<String>(
            value: grade.toString(),
            child: Text(gradeText),
          );
        }),
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildWaliKelasDropdown({
    required String? value,
    required Function(String?) onChanged,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({
            'en': 'Homeroom Teacher',
            'id': 'Wali Kelas',
          }),
          prefixIcon: Icon(Icons.person, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'No Homeroom Teacher',
                'id': 'Tidak ada wali kelas',
              }),
            ),
          ),
          ..._teachers.map((teacher) {
            return DropdownMenuItem<String>(
              value: teacher['id']?.toString(),
              child: Text(teacher['nama'] ?? 'Unknown'),
            );
          }),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _deleteClass(Map<String, dynamic> classData) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Delete Class',
          'id': 'Hapus Kelas',
        }),
        content: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Are you sure you want to delete this class?',
          'id': 'Yakin ingin menghapus kelas ini?',
        }),
        confirmText: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Delete',
          'id': 'Hapus',
        }),
        confirmColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      try {
        await _classService.deleteClass(classData['id']);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<LanguageProvider>().getTranslatedText({
                  'en': 'Class successfully deleted',
                  'id': 'Kelas berhasil dihapus',
                }),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<LanguageProvider>().getTranslatedText({
                  'en': 'Failed to delete class: $e',
                  'id': 'Gagal menghapus kelas: $e',
                }),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildClassCard(Map<String, dynamic> classData, int index) {
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
      child: GestureDetector(
        onTap: () {
          _showClassDetail(classData);
        },
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showClassDetail(classData),
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
                          // Header dengan nama kelas
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      classData['nama'] ?? 'No Name',
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
                                      _getGradeLevelText(
                                        classData['grade_level'],
                                        languageProvider,
                                      ),
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
                                  '${classData['jumlah_siswa'] ?? 0} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
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

                          // Informasi wali kelas
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
                                  Icons.person,
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
                                        'en': 'Homeroom Teacher',
                                        'id': 'Wali Kelas',
                                      }),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      classData['wali_kelas_nama'] ??
                                          languageProvider.getTranslatedText({
                                            'en': 'Not Assigned',
                                            'id': 'Belum Ditugaskan',
                                          }),
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
                                backgroundColor: Colors.white,
                                borderColor: _getPrimaryColor(),
                                onPressed: () =>
                                    _showAddEditDialog(classData: classData),
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
                                onPressed: () => _deleteClass(classData),
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

  void _showClassDetail(Map<String, dynamic> classData) {
    final languageProvider = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(Icons.school, size: 30, color: Colors.white),
                    ),
                    SizedBox(height: 12),
                    Text(
                      classData['nama'] ?? 'No Name',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      _getGradeLevelText(
                        classData['grade_level'],
                        languageProvider,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(
                      icon: Icons.people,
                      label: languageProvider.getTranslatedText({
                        'en': 'Total Students',
                        'id': 'Jumlah Siswa',
                      }),
                      value:
                          '${classData['jumlah_siswa'] ?? 0} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                    ),
                    _buildDetailItem(
                      icon: Icons.person,
                      label: languageProvider.getTranslatedText({
                        'en': 'Homeroom Teacher',
                        'id': 'Wali Kelas',
                      }),
                      value:
                          classData['wali_kelas_nama'] ??
                          languageProvider.getTranslatedText({
                            'en': 'Not Assigned',
                            'id': 'Belum Ditugaskan',
                          }),
                    ),

                    SizedBox(height: 20),
                    Row(
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
                              languageProvider.getTranslatedText({
                                'en': 'Close',
                                'id': 'Tutup',
                              }),
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAddEditDialog(classData: classData);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Edit',
                                'id': 'Edit',
                              }),
                              style: TextStyle(color: Colors.white),
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
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getPrimaryColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: _getPrimaryColor()),
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
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGradeLevelText(
    dynamic gradeLevel,
    LanguageProvider languageProvider,
  ) {
    if (gradeLevel == null) return '-';

    final level = int.tryParse(gradeLevel.toString());
    if (level == null) return '-';

    if (level <= 6) {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SD';
    } else if (level <= 9) {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SMP';
    } else {
      return '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Kelas'})} $level SMA';
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

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        if (_isLoading) {
          return LoadingScreen(
            message: languageProvider.getTranslatedText({
              'en': 'Loading class data...',
              'id': 'Memuat data kelas...',
            }),
          );
        }

        if (_errorMessage != null) {
          return ErrorScreen(errorMessage: _errorMessage!, onRetry: _loadData);
        }

        // Backend handles all filtering, so we use _classes directly
        final filteredClasses = _classes;

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
                                  'en': 'Class Management',
                                  'id': 'Manajemen Kelas',
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
                                  'en': 'Manage and monitor classes',
                                  'id': 'Kelola dan pantau kelas',
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
                                  'en': 'Search classes...',
                                  'id': 'Cari kelas...',
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
                      SizedBox(
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
                child: filteredClasses.isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No classes',
                          'id': 'Tidak ada kelas',
                        }),
                        subtitle:
                            _searchController.text.isEmpty && !_hasActiveFilter
                            ? languageProvider.getTranslatedText({
                                'en': 'Tap + to add a class',
                                'id': 'Tap + untuk menambah kelas',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: Icons.school_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          itemCount:
                              filteredClasses.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index == filteredClasses.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            final classData = filteredClasses[index];
                            return _buildClassCard(classData, index);
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
