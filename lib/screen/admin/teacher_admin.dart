import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/excel_teacher_service.dart';
import 'package:provider/provider.dart';
import 'package:manajemensekolah/components/confirmation_dialog.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/screen/admin/teacher_detail_screen.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';

class TeacherAdminScreen extends StatefulWidget {
  const TeacherAdminScreen({super.key});

  @override
  TeacherAdminScreenState createState() => TeacherAdminScreenState();
}

class TeacherAdminScreenState extends State<TeacherAdminScreen>
    with SingleTickerProviderStateMixin {
  final ApiTeacherService _teacherService = ApiTeacherService();
  final ApiClassService _classService = ApiClassService();
  final ApiSubjectService _subjectService = ApiSubjectService();
  List<dynamic> _teachers = [];
  List<dynamic> _subjects = [];
  List<dynamic> _classes = [];
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
  int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _paginationMeta;

  // Filter States (Backend filtering)
  String? _selectedKelasId; // Filter by class
  String? _selectedHomeroomFilter; // 'wali_kelas', 'guru_biasa', atau null untuk semua
  List<String> _selectedSubjectIds = [];
  String? _selectedGenderFilter; // 'L', 'P', atau null untuk semua
  bool _hasActiveFilter = false;

  // Filter Options (from backend)
  List<dynamic> _availableKelas = [];

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
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
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
      final response = await ApiTeacherService.getTeacherFilterOptions();
      
      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _availableKelas = response['data']['kelas'] ?? [];
        });
        print('✅ Filter options loaded: ${_availableKelas.length} kelas');
      }
    } catch (e) {
      print('Error loading filter options: $e');
      // Continue with empty options - not critical error
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = _selectedHomeroomFilter != null || 
                         _selectedSubjectIds.isNotEmpty || 
                         _selectedGenderFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedKelasId = null;
      _selectedHomeroomFilter = null;
      _selectedSubjectIds.clear();
      _selectedGenderFilter = null;
      _searchController.clear();
      _currentPage = 1;
      _hasActiveFilter = false;
    });
    _loadData(); // Reload data setelah clear filters
  }

  List<Map<String, dynamic>> _buildFilterChips(LanguageProvider languageProvider) {
    List<Map<String, dynamic>> filterChips = [];
    
    if (_selectedHomeroomFilter != null) {
      final statusText = _selectedHomeroomFilter == 'wali_kelas'
          ? languageProvider.getTranslatedText({'en': 'Homeroom Teacher', 'id': 'Wali Kelas'})
          : languageProvider.getTranslatedText({'en': 'Regular Teacher', 'id': 'Guru Biasa'});
      filterChips.add({
        'label': '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedHomeroomFilter = null;
          });
          _checkActiveFilter();
          _loadData(); // Reload data setelah remove filter
        },
      });
    }
    
    if (_selectedSubjectIds.isNotEmpty) {
      for (var subjectId in _selectedSubjectIds) {
        final subject = _subjects.firstWhere(
          (s) => s['id'].toString() == subjectId,
          orElse: () => {'nama': subjectId},
        );
        filterChips.add({
          'label': '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mata Pelajaran'})}: ${subject['nama']}',
          'onRemove': () {
            setState(() {
              _selectedSubjectIds.remove(subjectId);
            });
            _checkActiveFilter();
            _loadData(); // Reload data setelah remove filter
          },
        });
      }
    }
    
    if (_selectedGenderFilter != null) {
      final genderText = _selectedGenderFilter == 'L' 
          ? languageProvider.getTranslatedText({'en': 'Male', 'id': 'Laki-laki'})
          : languageProvider.getTranslatedText({'en': 'Female', 'id': 'Perempuan'});
      filterChips.add({
        'label': '${languageProvider.getTranslatedText({'en': 'Gender', 'id': 'Jenis Kelamin'})}: $genderText',
        'onRemove': () {
          setState(() {
            _selectedGenderFilter = null;
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
    String? tempSelectedHomeroom = _selectedHomeroomFilter;
    List<String> tempSelectedSubjects = List.from(_selectedSubjectIds);
    String? tempSelectedGender = _selectedGenderFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(20),
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
                            tempSelectedHomeroom = null;
                            tempSelectedSubjects.clear();
                            tempSelectedGender = null;
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

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Wali Kelas Filter
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Status',
                            'id': 'Status',
                          }),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildStatusChip(
                              label: languageProvider.getTranslatedText({
                                'en': 'All',
                                'id': 'Semua',
                              }),
                              value: null,
                              selectedValue: tempSelectedHomeroom,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedHomeroom = null;
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: languageProvider.getTranslatedText({
                                'en': 'Homeroom Teacher',
                                'id': 'Wali Kelas',
                              }),
                              value: 'wali_kelas',
                              selectedValue: tempSelectedHomeroom,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedHomeroom = 'wali_kelas';
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: languageProvider.getTranslatedText({
                                'en': 'Regular Teacher',
                                'id': 'Guru Biasa',
                              }),
                              value: 'guru_biasa',
                              selectedValue: tempSelectedHomeroom,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedHomeroom = 'guru_biasa';
                                });
                              },
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Mata Pelajaran Filter
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Subject',
                            'id': 'Mata Pelajaran',
                          }),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _subjects.map((subject) {
                            final subjectId = subject['id'].toString();
                            final isSelected = tempSelectedSubjects.contains(subjectId);
                            
                            return FilterChip(
                              label: Text(subject['nama'] ?? 'Unknown'),
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
                              selectedColor: _getPrimaryColor().withOpacity(0.2),
                              checkmarkColor: _getPrimaryColor(),
                              labelStyle: TextStyle(
                                color: isSelected ? _getPrimaryColor() : Colors.grey.shade700,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              side: BorderSide(
                                color: isSelected ? _getPrimaryColor() : Colors.grey.shade300,
                              ),
                            );
                          }).toList(),
                        ),

                        SizedBox(height: 24),

                        // Jenis Kelamin Filter
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Gender',
                            'id': 'Jenis Kelamin',
                          }),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildGenderChip(
                              label: languageProvider.getTranslatedText({
                                'en': 'All',
                                'id': 'Semua',
                              }),
                              value: null,
                              selectedValue: tempSelectedGender,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedGender = null;
                                });
                              },
                            ),
                            _buildGenderChip(
                              label: languageProvider.getTranslatedText({
                                'en': 'Male',
                                'id': 'Laki-laki',
                              }),
                              value: 'L',
                              selectedValue: tempSelectedGender,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedGender = 'L';
                                });
                              },
                            ),
                            _buildGenderChip(
                              label: languageProvider.getTranslatedText({
                                'en': 'Female',
                                'id': 'Perempuan',
                              }),
                              value: 'P',
                              selectedValue: tempSelectedGender,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedGender = 'P';
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Buttons
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        offset: Offset(0, -2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: _getPrimaryColor()),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                            setState(() {
                              _selectedHomeroomFilter = tempSelectedHomeroom;
                              _selectedSubjectIds = tempSelectedSubjects;
                              _selectedGenderFilter = tempSelectedGender;
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
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required String? value,
    required String? selectedValue,
    required VoidCallback onSelected,
  }) {
    final isSelected = selectedValue == value;
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: _getPrimaryColor().withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? _getPrimaryColor() : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? _getPrimaryColor() : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildGenderChip({
    required String label,
    required String? value,
    required String? selectedValue,
    required VoidCallback onSelected,
  }) {
    final isSelected = selectedValue == value;
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: _getPrimaryColor().withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? _getPrimaryColor() : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? _getPrimaryColor() : Colors.grey.shade300,
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
          _teachers = []; // Reset list
        });
      }

      // Load subjects and classes (untuk dropdown/reference)
      final subjectData = await _subjectService.getSubject();
      final classData = await _classService.getClass();

      // Load with pagination and backend filtering
      final response = await ApiTeacherService.getTeachersPaginated(
        page: _currentPage,
        limit: _perPage,
        kelasId: _selectedKelasId,
        jenisKelamin: _selectedGenderFilter,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _teachers = response['data'] ?? [];
        _subjects = subjectData;
        _classes = classData;
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
              'en': 'Failed to load data: $e',
              'id': 'Gagal memuat data: $e',
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

      // Load next page
      final response = await ApiTeacherService.getTeachersPaginated(
        page: _currentPage,
        limit: _perPage,
        kelasId: _selectedKelasId,
        jenisKelamin: _selectedGenderFilter,
        search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        // Append new data to existing list
        _teachers.addAll(response['data'] ?? []);
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      print('✅ Loaded more data: Page $_currentPage, Total items: ${_teachers.length}');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });

      print('Error loading more data: $e');
    }
  }

  // Export teachers to Excel
  Future<void> _exportToExcel() async {
    await ExcelTeacherService.exportTeachersToExcel(
      teachers: _teachers,
      context: context,
    );
  }

  // Import teachers from Excel
  Future<void> _importFromExcel() async {
    final languageProvider = context.read<LanguageProvider>();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await ApiTeacherService.importTeachersFromExcel(
          File(result.files.single.path!)
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
    await ExcelTeacherService.downloadTemplate(context);
  }

  // Import teacher from Excel (API call)
  Future<Map<String, dynamic>> importTeachersFromExcelAPI(
    String base64File,
  ) async {
    try {
      final response = await ApiService().post('/guru/import', {
        'file_data': base64File,
      });
      return response;
    } catch (e) {
      debugPrint('Error importing teachers from Excel: $e');
      rethrow;
    }
  }

  // Download teacher template (API call)
  Future<String> downloadTeacherTemplateAPI() async {
    try {
      final response = await ApiService().get('/guru/template');
      return response['file_data'];
    } catch (e) {
      debugPrint('Error downloading teacher template: $e');
      rethrow;
    }
  }

  // Import teacher from Excel
  Future<Map<String, dynamic>> importTeachersFromExcel(
    String base64File,
  ) async {
    try {
      final response = await ApiService().post('/guru/import', {
        'file_data': base64File,
      });
      return response;
    } catch (e) {
      debugPrint('Error importing teachers from Excel: $e');
      rethrow;
    }
  }

  // Download teacher template
  Future<String> downloadTeacherTemplate() async {
    try {
      final response = await ApiService().get('/guru/template');
      return response['file_data'];
    } catch (e) {
      debugPrint('Error downloading teacher template: $e');
      rethrow;
    }
  }

  Future<void> _manageTeacherSubject(
    String teacherId,
    List<String> selectedSubjectIds,
  ) async {
    try {
      final currentSubjects = await _teacherService.getSubjectByTeacher(
        teacherId,
      );
      final currentIds = currentSubjects
          .map((subject) => subject['id'] as String)
          .toList();

      for (final subjectId in selectedSubjectIds) {
        if (!currentIds.contains(subjectId)) {
          await _teacherService.addSubjectToTeacher(teacherId, subjectId);
        }
      }

      for (final currentId in currentIds) {
        if (!selectedSubjectIds.contains(currentId)) {
          await _teacherService.removeSubjectFromTeacher(teacherId, currentId);
        }
      }
    } catch (error) {
      debugPrint('Error handling teacher subjects: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': 'Failed to update teacher subjects: $error',
              'id': 'Gagal mengupdate mata pelajaran guru: $error',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? teacher}) {
    final nameController = TextEditingController(
      text: teacher?['nama']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: teacher?['email']?.toString() ?? '',
    );
    final nipController = TextEditingController(
      text: teacher?['nip']?.toString() ?? '',
    );

    String? selectedClassId = teacher?['class_id']?.toString();
    bool isHomeroomTeacher =
        teacher?['is_wali_kelas'] == 1 || teacher?['is_wali_kelas'] == true;

    List<String> selectedSubjectIds = [];

    Future<void> showDialogWithSubjects(List<String> subjectIds) async {
      selectedSubjectIds = subjectIds;
      selectedSubjectIds = selectedSubjectIds.toSet().toList();
      await showDialog(
        context: context,
        builder: (context) => Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            return StatefulBuilder(
              builder: (context, setState) {
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
                                  teacher == null
                                      ? Icons.person_add
                                      : Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  teacher == null
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Add Teacher',
                                          'id': 'Tambah Guru',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Edit Teacher',
                                          'id': 'Edit Guru',
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
                                  'en': 'Teacher Name',
                                  'id': 'Nama Guru',
                                }),
                                icon: Icons.person,
                              ),
                              SizedBox(height: 12),
                              _buildDialogTextField(
                                controller: emailController,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Email',
                                  'id': 'Email',
                                }),
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              SizedBox(height: 12),
                              _buildDialogTextField(
                                controller: nipController,
                                label: 'NIP',
                                icon: Icons.badge,
                              ),
                              SizedBox(height: 12),
                              _buildDialogDropdown(
                                value: selectedClassId,
                                label: languageProvider.getTranslatedText({
                                  'en': 'Class (Optional)',
                                  'id': 'Kelas (Opsional)',
                                }),
                                icon: Icons.school,
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'None',
                                        'id': 'Tidak ada',
                                      }),
                                    ),
                                  ),
                                  ..._classes
                                      .where(
                                        (classItem) =>
                                            classItem['id'] != null &&
                                            classItem['name'] != null,
                                      )
                                      .map(
                                        (classItem) => DropdownMenuItem<String>(
                                          value: classItem['id'].toString(),
                                          child: Text(
                                            classItem['name']?.toString() ??
                                                'Unknown Class',
                                          ),
                                        ),
                                      ),
                                ],
                                onChanged: (value) {
                                  setState(() => selectedClassId = value);
                                },
                              ),
                              SizedBox(height: 16),

                              // Subjects Section
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Subjects:',
                                        'id': 'Mata Pelajaran:',
                                      }),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    ..._subjects
                                        .where(
                                          (subject) =>
                                              subject['id'] != null &&
                                              subject['nama'] != null,
                                        )
                                        .map(
                                          (subject) => CheckboxListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(
                                              subject['nama']?.toString() ??
                                                  'Unknown Subject',
                                              style: TextStyle(fontSize: 14),
                                            ),
                                            value: selectedSubjectIds.contains(
                                              subject['id']?.toString(),
                                            ),
                                            onChanged: (value) {
                                              final subjectId = subject['id']
                                                  ?.toString();
                                              if (subjectId == null) return;

                                              setState(() {
                                                if (value == true) {
                                                  selectedSubjectIds.add(
                                                    subjectId,
                                                  );
                                                } else {
                                                  selectedSubjectIds.remove(
                                                    subjectId,
                                                  );
                                                }
                                              });
                                            },
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12),

                              // Homeroom Teacher Checkbox
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Homeroom Teacher',
                                      'id': 'Wali Kelas',
                                    }),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  value: isHomeroomTeacher,
                                  onChanged: (value) {
                                    setState(
                                      () => isHomeroomTeacher = value ?? false,
                                    );
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
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
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    AppLocalizations.cancel.tr,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final name = nameController.text.trim();
                                    final email = emailController.text.trim();
                                    final nip = nipController.text.trim();

                                    if (name.isEmpty ||
                                        email.isEmpty ||
                                        nip.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            languageProvider.getTranslatedText({
                                              'en':
                                                  'Name, email, and NIP must be filled',
                                              'id':
                                                  'Nama, email, dan NIP harus diisi',
                                            }),
                                          ),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }

                                    try {
                                      final data = {
                                        'nama': name,
                                        'email': email,
                                        'kelas_id': selectedClassId,
                                        'nip': nip,
                                        'is_wali_kelas':
                                            isHomeroomTeacher,
                                      };

                                      String teacherId;
                                      if (teacher == null) {
                                        final result = await _teacherService
                                            .addTeacher(data);
                                        teacherId =
                                            result['id']?.toString() ?? '';
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                languageProvider.getTranslatedText({
                                                  'en':
                                                      'Teacher added successfully. Default password: password123',
                                                  'id':
                                                      'Guru berhasil ditambahkan. Password default: password123',
                                                }),
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      } else {
                                        teacherId =
                                            teacher['id']?.toString() ?? '';
                                        await _teacherService.updateTeacher(
                                          teacherId,
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
                                                      'Teacher updated successfully',
                                                  'id':
                                                      'Guru berhasil diupdate',
                                                }),
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        }
                                      }

                                      if (teacherId.isNotEmpty) {
                                        await _manageTeacherSubject(
                                          teacherId,
                                          selectedSubjectIds,
                                        );
                                      }

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                      _loadData();
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              languageProvider.getTranslatedText({
                                                'en':
                                                    'Failed to save data: $error',
                                                'id':
                                                    'Gagal menyimpan data: $error',
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
            );
          },
        ),
      );
    }

    if (teacher == null) {
      showDialogWithSubjects([]);
    } else {
      _teacherService
          .getSubjectByTeacher(teacher['id']?.toString() ?? '')
          .then((list) {
            final ids = list
                .where((subject) => subject['id'] != null)
                .map((subject) => subject['id'].toString())
                .toList();
            showDialogWithSubjects(ids);
          })
          .catchError((error) {
            showDialogWithSubjects([]);
          });
    }
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
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
        keyboardType: keyboardType,
      ),
    );
  }

  Widget _buildDialogDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: items,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
    );
  }

  Future<void> _deleteTeacher(Map<String, dynamic> teacher) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Delete Teacher',
          'id': 'Hapus Guru',
        }),
        content: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Are you sure you want to delete this teacher?',
          'id': 'Apakah Anda yakin ingin menghapus guru ini?',
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
        final teacherId = teacher['id']?.toString();
        if (teacherId != null && teacherId.isNotEmpty) {
          await _teacherService.deleteTeacher(teacherId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.read<LanguageProvider>().getTranslatedText({
                    'en': 'Teacher successfully deleted',
                    'id': 'Guru berhasil dihapus',
                  }),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
          _loadData();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<LanguageProvider>().getTranslatedText({
                  'en': 'Failed to delete teacher: $error',
                  'id': 'Gagal menghapus guru: $error',
                }),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _navigateToDetail(Map<String, dynamic> teacher) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherDetailScreen(guru: teacher),
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher, int index) {
    final languageProvider = context.read<LanguageProvider>();
    final isHomeroomTeacher = teacher['is_wali_kelas'] == 1 || teacher['is_wali_kelas'] == true;
    final className = teacher['class_name'] ?? '-';
    
    return GestureDetector(
      onTap: () => _navigateToDetail(teacher),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToDetail(teacher),
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
                        // Header dengan nama dan NIP
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    teacher['nama'] ?? 'No Name',
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
                                    'NIP: ${teacher['nip'] ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isHomeroomTeacher)
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
                                  languageProvider.getTranslatedText({
                                    'en': 'Homeroom',
                                    'id': 'Wali Kelas',
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

                        // Informasi email
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
                                Icons.email,
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
                                    'Email',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    teacher['email'] ?? '-',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Informasi kelas (jika wali kelas)
                        if (isHomeroomTeacher && className != '-') ...[
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
                                  Icons.class_,
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
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      className,
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
                              onPressed: () => _showAddEditDialog(teacher: teacher),
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
                              onPressed: () => _deleteTeacher(teacher),
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
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor ?? color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor ?? color,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
              'en': 'Loading teacher data...',
              'id': 'Memuat data guru...',
            }),
          );
        }

        if (_errorMessage != null) {
          return ErrorScreen(errorMessage: _errorMessage!, onRetry: _loadData);
        }

        final filteredTeachers = _teachers.where((teacher) {
          final searchTerm = _searchController.text.toLowerCase();
          final name = teacher['nama']?.toString().toLowerCase() ?? '';
          final nip = teacher['nip']?.toString().toLowerCase() ?? '';

          final matchesSearch =
              searchTerm.isEmpty ||
              name.contains(searchTerm) ||
              nip.contains(searchTerm);

          // Homeroom filter
          final isHomeroom = teacher['is_wali_kelas'] == 1 || teacher['is_wali_kelas'] == true;
          final matchesHomeroomFilter =
              _selectedHomeroomFilter == null ||
              (_selectedHomeroomFilter == 'wali_kelas' && isHomeroom) ||
              (_selectedHomeroomFilter == 'guru_biasa' && !isHomeroom);

          // Subject filter
          final teacherSubjectId = teacher['mata_pelajaran_id']?.toString();
          final matchesSubjectFilter =
              _selectedSubjectIds.isEmpty ||
              (teacherSubjectId != null && _selectedSubjectIds.contains(teacherSubjectId));

          // Gender filter
          final matchesGenderFilter =
              _selectedGenderFilter == null ||
              teacher['jenis_kelamin'] == _selectedGenderFilter;

          return matchesSearch && matchesHomeroomFilter && matchesSubjectFilter && matchesGenderFilter;
        }).toList();

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
                                  'en': 'Teacher Management',
                                  'id': 'Manajemen Guru',
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
                                  'en': 'Manage and monitor teachers',
                                  'id': 'Kelola dan pantau guru',
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
                                  'en': 'Search teachers...',
                                  'id': 'Cari guru...',
                                }),
                                hintStyle: TextStyle(color: Colors.grey),
                                prefixIcon: Icon(Icons.search, color: Colors.grey),
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
                                  ..._buildFilterChips(languageProvider).map((filter) {
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
                                  backgroundColor: _getPrimaryColor().withOpacity(0.1),
                                  side: BorderSide(
                                    color: _getPrimaryColor().withOpacity(0.3),
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

              if (filteredTeachers.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${filteredTeachers.length} ${languageProvider.getTranslatedText({'en': 'teachers found', 'id': 'guru ditemukan'})}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 4),
              Expanded(
                child: filteredTeachers.isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No teachers',
                          'id': 'Tidak ada guru',
                        }),
                        subtitle:
                            _searchController.text.isEmpty &&
                                !_hasActiveFilter
                            ? languageProvider.getTranslatedText({
                                'en': 'Tap + to add a teacher',
                                'id': 'Tap + untuk menambah guru',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: Icons.person_outline,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: filteredTeachers.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index == filteredTeachers.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }
                            
                            final teacher = filteredTeachers[index];
                            return AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                final delay = index * 0.1;
                                final animation = CurvedAnimation(
                                  parent: _animationController,
                                  curve: Interval(
                                    delay,
                                    1.0,
                                    curve: Curves.easeOut,
                                  ),
                                );

                                return FadeTransition(
                                  opacity: animation,
                                  child: Transform.translate(
                                    offset: Offset(0, 50 * (1 - animation.value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: _buildTeacherCard(teacher, index),
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
