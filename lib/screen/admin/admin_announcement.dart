import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/confirmation_dialog.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/services/api_announcement_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/date_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class AnnouncementManagementScreen extends StatefulWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  AnnouncementManagementScreenState createState() =>
      AnnouncementManagementScreenState();
}

class AnnouncementManagementScreenState
    extends State<AnnouncementManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _announcements = [];
  bool _isLoading = true;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Scroll Controller for Infinite Scroll
  final ScrollController _scrollController = ScrollController();

  // Search dan filter
  final TextEditingController _searchController = TextEditingController();

  // Pagination States (Infinite Scroll)
  int _currentPage = 1;
  final int _perPage = 10; // Fixed 10 items per load
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  Map<String, dynamic>? _paginationMeta;

  // Filter States (Backend filtering)
  String? _selectedPriorityFilter; // 'Important', 'Normal', or null for all
  String?
  _selectedTargetFilter; // 'Teacher', 'Student', 'Parent', 'All', or null
  String? _selectedStatusFilter; // 'Active', 'Scheduled', 'Expired', or null
  bool _hasActiveFilter = false;

  // Filter Options (from backend)
  List<dynamic> _availablePrioritasOptions = [];
  List<dynamic> _availableTargetOptions = [];
  List<dynamic> _availableStatusOptions = [];

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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        _loadMoreAnnouncements();
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
      final response =
          await ApiAnnouncementService.getAnnouncementFilterOptions();

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _availablePrioritasOptions =
              response['data']['prioritas_options'] ?? [];
          _availableTargetOptions = response['data']['target_options'] ?? [];
          _availableStatusOptions = response['data']['status_options'] ?? [];
        });
        if (kDebugMode) {
          print('✅ Announcement filter options loaded');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading announcement filter options: $e');
      }
      // Continue with empty options - not critical error
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedPriorityFilter != null ||
          _selectedTargetFilter != null ||
          _selectedStatusFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedPriorityFilter = null;
      _selectedTargetFilter = null;
      _selectedStatusFilter = null;
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

    if (_selectedPriorityFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Priority', 'id': 'Prioritas'})}: $_selectedPriorityFilter',
        'onRemove': () {
          setState(() {
            _selectedPriorityFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedTargetFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Target', 'id': 'Target'})}: $_selectedTargetFilter',
        'onRemove': () {
          setState(() {
            _selectedTargetFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    if (_selectedStatusFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $_selectedStatusFilter',
        'onRemove': () {
          setState(() {
            _selectedStatusFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = context.read<LanguageProvider>();

    // Temporary state for bottom sheet
    String? tempSelectedPrioritas = _selectedPriorityFilter;
    String? tempSelectedTarget = _selectedTargetFilter;
    String? tempSelectedStatus = _selectedStatusFilter;

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
                          tempSelectedPrioritas = null;
                          tempSelectedTarget = null;
                          tempSelectedStatus = null;
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
                      // Prioritas Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Priority',
                          'id': 'Prioritas',
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
                        children: ['Penting', 'Biasa'].map((prioritas) {
                          final isSelected = tempSelectedPrioritas == prioritas;
                          return FilterChip(
                            label: Text(prioritas),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedPrioritas = selected
                                    ? prioritas
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

                      // Target Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Target',
                          'id': 'Target',
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
                                'value': 'Semua',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'All',
                                  'id': 'Semua',
                                }),
                              },
                              {
                                'value': 'Guru',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Teachers',
                                  'id': 'Guru',
                                }),
                              },
                              {
                                'value': 'Siswa',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Students',
                                  'id': 'Siswa',
                                }),
                              },
                              {
                                'value': 'Orang Tua',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Parents',
                                  'id': 'Orang Tua',
                                }),
                              },
                            ].map((item) {
                              final isSelected =
                                  tempSelectedTarget == item['value'];
                              return FilterChip(
                                label: Text(item['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempSelectedTarget = selected
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

                      // Status Filter
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Status',
                          'id': 'Status',
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
                                'value': 'Aktif',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Active',
                                  'id': 'Aktif',
                                }),
                              },
                              {
                                'value': 'Terjadwal',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Scheduled',
                                  'id': 'Terjadwal',
                                }),
                              },
                              {
                                'value': 'Kedaluwarsa',
                                'label': languageProvider.getTranslatedText({
                                  'en': 'Expired',
                                  'id': 'Kedaluwarsa',
                                }),
                              },
                            ].map((item) {
                              final isSelected =
                                  tempSelectedStatus == item['value'];
                              return FilterChip(
                                label: Text(item['label']!),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempSelectedStatus = selected
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
                        _selectedPriorityFilter = tempSelectedPrioritas;
                        _selectedTargetFilter = tempSelectedTarget;
                        _selectedStatusFilter = tempSelectedStatus;
                      });
                      _checkActiveFilter();
                      Navigator.pop(context);
                      _loadData(); // Reload data setelah apply filter
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
          _currentPage = 1;
          _hasMoreData = true;
          _announcements = []; // Reset list
          _errorMessage = null;
        });
      }

      // Map display values to backend values
      String? mappedPrioritas;
      if (_selectedPriorityFilter != null) {
        if (_selectedPriorityFilter == 'Penting' ||
            _selectedPriorityFilter == 'Important') {
          mappedPrioritas = 'important';
        } else if (_selectedPriorityFilter == 'Biasa' ||
            _selectedPriorityFilter == 'Normal') {
          mappedPrioritas = 'normal';
        } else {
          mappedPrioritas = _selectedPriorityFilter!.toLowerCase();
        }
      }

      String? mappedRoleTarget;
      if (_selectedTargetFilter != null) {
        switch (_selectedTargetFilter) {
          case 'Semua':
          case 'All':
            mappedRoleTarget = 'all';
            break;
          case 'Guru':
          case 'Teachers':
            mappedRoleTarget = 'teacher';
            break;
          case 'Siswa':
          case 'Students':
            mappedRoleTarget = 'student';
            break;
          case 'Orang Tua':
          case 'Parents':
            mappedRoleTarget = 'parent';
            break;
          default:
            mappedRoleTarget = _selectedTargetFilter!.toLowerCase();
        }
      }

      String? mappedStatus;
      if (_selectedStatusFilter != null) {
        switch (_selectedStatusFilter) {
          case 'Aktif':
          case 'Active':
            mappedStatus = 'aktif';
            break;
          case 'Terjadwal':
          case 'Scheduled':
            mappedStatus = 'terjadwal';
            break;
          case 'Kedaluwarsa':
          case 'Expired':
            mappedStatus = 'kedaluwarsa';
            break;
          default:
            mappedStatus = _selectedStatusFilter!.toLowerCase();
        }
      }

      // Load with pagination and backend filtering
      final response = await ApiAnnouncementService.getAnnouncementsPaginated(
        page: _currentPage,
        limit: _perPage,
        prioritas: mappedPrioritas,
        roleTarget: mappedRoleTarget,
        status: mappedStatus,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      // Check if response has the expected structure
      if (response.containsKey('data') && response.containsKey('pagination')) {
        setState(() {
          _announcements = response['data'] ?? [];
          _paginationMeta = response['pagination'];
          _hasMoreData = response['pagination']?['has_next_page'] ?? false;
          _isLoading = false;
          // Clear error message on successful load
          _errorMessage = null;
        });
      } else {
        if (kDebugMode) {
          print('❌ Unexpected response structure');
        }
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unexpected response structure';
        });
      }

      _animationController.forward();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': 'Failed to load announcement data: $e',
              'id': 'Gagal memuat data pengumuman: $e',
            }),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadMoreAnnouncements() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      _currentPage++;

      // Map display values to backend values (same logic as _loadData)
      String? mappedPrioritas;
      if (_selectedPriorityFilter != null) {
        if (_selectedPriorityFilter == 'Penting' ||
            _selectedPriorityFilter == 'Important') {
          mappedPrioritas = 'important';
        } else if (_selectedPriorityFilter == 'Biasa' ||
            _selectedPriorityFilter == 'Normal') {
          mappedPrioritas = 'normal';
        } else {
          mappedPrioritas = _selectedPriorityFilter!.toLowerCase();
        }
      }

      String? mappedRoleTarget;
      if (_selectedTargetFilter != null) {
        switch (_selectedTargetFilter) {
          case 'Semua':
          case 'All':
            mappedRoleTarget = 'all';
            break;
          case 'Guru':
          case 'Teachers':
            mappedRoleTarget = 'teacher';
            break;
          case 'Siswa':
          case 'Students':
            mappedRoleTarget = 'student';
            break;
          case 'Orang Tua':
          case 'Parents':
            mappedRoleTarget = 'parent';
            break;
          default:
            mappedRoleTarget = _selectedTargetFilter!.toLowerCase();
        }
      }

      String? mappedStatus;
      if (_selectedStatusFilter != null) {
        switch (_selectedStatusFilter) {
          case 'Aktif':
          case 'Active':
            mappedStatus = 'aktif';
            break;
          case 'Terjadwal':
          case 'Scheduled':
            mappedStatus = 'terjadwal';
            break;
          case 'Kedaluwarsa':
          case 'Expired':
            mappedStatus = 'kedaluwarsa';
            break;
          default:
            mappedStatus = _selectedStatusFilter!.toLowerCase();
        }
      }

      final response = await ApiAnnouncementService.getAnnouncementsPaginated(
        page: _currentPage,
        limit: _perPage,
        prioritas: mappedPrioritas,
        roleTarget: mappedRoleTarget,
        status: mappedStatus,
        search: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        // Append new data to existing list
        _announcements.addAll(response['data'] ?? []);
        _paginationMeta = response['pagination'];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoadingMore = false;
      });

      if (kDebugMode) {
        print(
          '✅ Loaded more announcements: Page $_currentPage, Total: ${_announcements.length}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
        _currentPage--; // Revert page increment on error
      });

      if (kDebugMode) {
        print('Error loading more announcements: $e');
      }
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? announcementData}) {
    final judulController = TextEditingController(
      text: announcementData?['title'] ?? '',
    );
    final kontenController = TextEditingController(
      text: announcementData?['content'] ?? '',
    );
    String? selectedClassId = announcementData?['kelas_id'];
    String? selectedRole = announcementData?['target_role'] ?? 'all';
    String? selectedPrioritas = announcementData?['priority'] ?? 'normal';
    DateTime? tanggalAwal = announcementData?['start_date'] != null
        ? DateTime.parse(announcementData!['start_date'])
        : null;
    DateTime? tanggalAkhir = announcementData?['end_date'] != null
        ? DateTime.parse(announcementData!['end_date'])
        : null;

    final isEdit = announcementData != null;

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
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isEdit ? Icons.edit : Icons.announcement,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isEdit
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Edit Announcement',
                                        'id': 'Edit Pengumuman',
                                      })
                                    : languageProvider.getTranslatedText({
                                        'en': 'Add Announcement',
                                        'id': 'Tambah Pengumuman',
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
                              controller: judulController,
                              label: languageProvider.getTranslatedText({
                                'en': 'Title',
                                'id': 'Judul',
                              }),
                              icon: Icons.title,
                            ),
                            SizedBox(height: 12),
                            _buildDialogTextField(
                              controller: kontenController,
                              label: languageProvider.getTranslatedText({
                                'en': 'Content',
                                'id': 'Konten',
                              }),
                              icon: Icons.description,
                              maxLines: 4,
                            ),
                            SizedBox(height: 12),
                            _buildPrioritasDropdown(
                              value: selectedPrioritas,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedPrioritas = value;
                                });
                              },
                              languageProvider: languageProvider,
                            ),
                            SizedBox(height: 12),
                            _buildRoleTargetDropdown(
                              value: selectedRole,
                              onChanged: (value) {
                                setDialogState(() {
                                  selectedRole = value;
                                });
                              },
                              languageProvider: languageProvider,
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    label: languageProvider.getTranslatedText({
                                      'en': 'Start Date',
                                      'id': 'Tanggal Mulai',
                                    }),
                                    value: tanggalAwal,
                                    onTap: () =>
                                        _selectDate(context, true, (date) {
                                          setDialogState(() {
                                            tanggalAwal = date;
                                          });
                                        }),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: _buildDateField(
                                    label: languageProvider.getTranslatedText({
                                      'en': 'End Date',
                                      'id': 'Tanggal Berakhir',
                                    }),
                                    value: tanggalAkhir,
                                    onTap: () =>
                                        _selectDate(context, false, (date) {
                                          setDialogState(() {
                                            tanggalAkhir = date;
                                          });
                                        }),
                                  ),
                                ),
                              ],
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
                                  languageProvider.getTranslatedText({
                                    'en': 'Cancel',
                                    'id': 'Batal',
                                  }),
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final judul = judulController.text.trim();
                                  final konten = kontenController.text.trim();

                                  if (judul.isEmpty || konten.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          languageProvider.getTranslatedText({
                                            'en':
                                                'Title and content must be filled',
                                            'id':
                                                'Judul dan konten harus diisi',
                                          }),
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    return;
                                  }

                                  try {
                                    final data = {
                                      'title': judulController.text,
                                      'content': kontenController.text,
                                      'class_id': selectedClassId,
                                      'target_role': selectedRole,
                                      'priority': selectedPrioritas,
                                      'start_date': tanggalAwal
                                          ?.toIso8601String(),
                                      'end_date': tanggalAkhir
                                          ?.toIso8601String(),
                                    };

                                    if (isEdit) {
                                      await _apiService.put(
                                        '/announcement/${announcementData['id']}',
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
                                                    'Announcement successfully updated',
                                                'id':
                                                    'Pengumuman berhasil diperbarui',
                                              }),
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        Navigator.pop(context);
                                      }
                                    } else {
                                      await _apiService.post(
                                        '/announcement',
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
                                                    'Announcement successfully added',
                                                'id':
                                                    'Pengumuman berhasil ditambahkan',
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
                                              'en':
                                                  'Failed to save announcement: $e',
                                              'id':
                                                  'Gagal menyimpan pengumuman: $e',
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
                                      : languageProvider.getTranslatedText({
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

  Widget _buildPrioritasDropdown({
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
            'en': 'Priority',
            'id': 'Prioritas',
          }),
          prefixIcon: Icon(
            Icons.priority_high,
            color: _getPrimaryColor(),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          DropdownMenuItem(
            value: 'normal',
            child: Row(
              children: [
                Icon(Icons.circle, color: Colors.grey, size: 16),
                SizedBox(width: 8),
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Normal',
                    'id': 'Biasa',
                  }),
                ),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'important',
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Important',
                    'id': 'Penting',
                  }),
                ),
              ],
            ),
          ),
        ],
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildRoleTargetDropdown({
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
            'en': 'Target Role',
            'id': 'Role Target',
          }),
          prefixIcon: Icon(Icons.people, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'All Users',
                'id': 'Semua Pengguna',
              }),
            ),
          ),
          DropdownMenuItem(value: 'admin', child: Text('Admin')),
          DropdownMenuItem(value: 'teacher', child: Text('Guru')),
          DropdownMenuItem(value: 'student', child: Text('Siswa')),
          DropdownMenuItem(value: 'parent', child: Text('Wali')),
        ],
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: _getPrimaryColor(), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                value != null
                    ? '${value.day}/${value.month}/${value.year}'
                    : label,
                style: TextStyle(
                  color: value != null
                      ? Colors.grey.shade800
                      : Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    bool isStartDate,
    Function(DateTime) onDateSelected,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Future<void> _deleteAnnouncement(
    Map<String, dynamic> announcementData,
  ) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Delete Announcement',
          'id': 'Hapus Pengumuman',
        }),
        content: context.read<LanguageProvider>().getTranslatedText({
          'en': 'Are you sure you want to delete this announcement?',
          'id': 'Yakin ingin menghapus pengumuman ini?',
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
        await _apiService.delete('/announcement/${announcementData['id']}');
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<LanguageProvider>().getTranslatedText({
                  'en': 'Announcement successfully deleted',
                  'id': 'Pengumuman berhasil dihapus',
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
                  'en': 'Failed to delete announcement: $e',
                  'id': 'Gagal menghapus pengumuman: $e',
                }),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildAnnouncementCard(
    Map<String, dynamic> announcementData,
    int index,
  ) {
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
          _showAnnouncementDetail(announcementData);
        },
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showAnnouncementDetail(announcementData),
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

                    // Priority badge
                    if (announcementData['priority'] == 'penting')
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning,
                                size: 12,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'IMPORTANT',
                                  'id': 'PENTING',
                                }),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                                      announcementData['title'] ?? 'No Title',
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
                                      _formatDate(
                                        announcementData['created_at'],
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
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
                                        'en': 'Content',
                                        'id': 'Konten',
                                      }),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      announcementData['content'] ?? '',
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

                          // Informasi pembuat
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
                                        'en': 'Created by',
                                        'id': 'Dibuat oleh',
                                      }),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      announcementData['creator_name'] ??
                                          'Unknown',
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

                          // Target informasi
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
                                        'en': 'Target Audience',
                                        'id': 'Target Pengguna',
                                      }),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 1),
                                    Text(
                                      _getTargetText(
                                        announcementData,
                                        languageProvider,
                                      ),
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
                                onPressed: () => _showAddEditDialog(
                                  announcementData: announcementData,
                                ),
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
                                onPressed: () =>
                                    _deleteAnnouncement(announcementData),
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

  void _showAnnouncementDetail(Map<String, dynamic> announcementData) {
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.announcement,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            announcementData['title'] ?? 'No Title',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      _formatDate(announcementData['created_at']),
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
                    // Priority badge
                    if (announcementData['priority'] == 'penting')
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning, size: 14, color: Colors.orange),
                            SizedBox(width: 6),
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Important Announcement',
                                'id': 'Pengumuman Penting',
                              }),
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 16),

                    // Content text
                    Text(
                      announcementData['content'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.grey.shade800,
                      ),
                    ),

                    SizedBox(height: 20),

                    // Metadata
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow(
                            icon: Icons.person,
                            label: languageProvider.getTranslatedText({
                              'en': 'Created by',
                              'id': 'Dibuat oleh',
                            }),
                            value:
                                announcementData['creator_name'] ??
                                announcementData['pembuat_nama'] ??
                                'Unknown',
                          ),
                          SizedBox(height: 8),
                          _buildDetailRow(
                            icon: Icons.people,
                            label: languageProvider.getTranslatedText({
                              'en': 'Target Role',
                              'id': 'Role Target',
                            }),
                            value: _getTargetText(
                              announcementData,
                              languageProvider,
                            ),
                          ),
                          if (announcementData['start_date'] != null)
                            SizedBox(height: 8),
                          if (announcementData['start_date'] != null)
                            _buildDetailRow(
                              icon: Icons.calendar_today,
                              label: languageProvider.getTranslatedText({
                                'en': 'Start Date',
                                'id': 'Tanggal Mulai',
                              }),
                              value: _formatDate(
                                announcementData['start_date'],
                              ),
                            ),
                          if (announcementData['end_date'] != null)
                            SizedBox(height: 8),
                          if (announcementData['end_date'] != null)
                            _buildDetailRow(
                              icon: Icons.event_busy,
                              label: languageProvider.getTranslatedText({
                                'en': 'End Date',
                                'id': 'Tanggal Berakhir',
                              }),
                              value: _formatDate(announcementData['end_date']),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Close button
              Container(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getPrimaryColor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Close',
                            'id': 'Tutup',
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

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _getPrimaryColor()),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getTargetText(
    Map<String, dynamic> announcementData,
    LanguageProvider languageProvider,
  ) {
    final roleTarget = announcementData['target_role'] ?? 'all';
    final classNama = announcementData['class_name'];

    if (roleTarget == 'all' && classNama == null) {
      return languageProvider.getTranslatedText({
        'en': 'All Users',
        'id': 'Semua Pengguna',
      });
    } else if (classNama != null) {
      return '$classNama (${roleTarget.toUpperCase()})';
    } else {
      return roleTarget.toUpperCase();
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    // Use AppDateUtils for consistent date formatting with timezone handling
    final date = AppDateUtils.parseApiDate(dateString);
    if (date == null) return dateString;

    // Format as: dd/MM/yyyy HH:mm
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, ColorUtils.primaryColor],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
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
                  gradient: _getCardGradient(),
                  boxShadow: [
                    BoxShadow(
                      color: _getPrimaryColor().withValues(alpha: 0.3),
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
                              color: Colors.white.withValues(alpha: 0.2),
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
                                  'en': 'Announcement Management',
                                  'id': 'Manajemen Pengumuman',
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
                                  'en': 'Manage and create announcements',
                                  'id': 'Kelola dan buat pengumuman',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.announcement,
                            color: Colors.white,
                            size: 20,
                          ),
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
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) => setState(() {}),
                              style: TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: languageProvider.getTranslatedText({
                                  'en': 'Search announcements...',
                                  'id': 'Cari pengumuman...',
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
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
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
                                color: Colors.white.withValues(alpha: 0.2),
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
                                          color: Colors.red,
                                        ),
                                        onDeleted: filter['onRemove'],
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.2),
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.3,
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

              // Content
              Expanded(
                child: _isLoading
                    ? LoadingScreen(
                        message: languageProvider.getTranslatedText({
                          'en': 'Loading announcements...',
                          'id': 'Memuat pengumuman...',
                        }),
                      )
                    : _errorMessage != null
                    ? ErrorScreen(
                        errorMessage: _errorMessage!,
                        onRetry: _loadData,
                      )
                    : _announcements.isEmpty
                    ? EmptyState(
                        icon: Icons.announcement_outlined,
                        title: languageProvider.getTranslatedText({
                          'en': 'No Announcements',
                          'id': 'Tidak Ada Pengumuman',
                        }),
                        subtitle: languageProvider.getTranslatedText({
                          'en': _searchController.text.isNotEmpty
                              ? 'No announcements found for your search'
                              : 'Start creating announcements to share information',
                          'id': _searchController.text.isNotEmpty
                              ? 'Tidak ada pengumuman yang sesuai dengan pencarian'
                              : 'Mulai buat pengumuman untuk berbagi informasi',
                        }),
                        buttonText: languageProvider.getTranslatedText({
                          'en': 'Create Announcement',
                          'id': 'Buat Pengumuman',
                        }),
                        onPressed: () => _showAddEditDialog(),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        color: _getPrimaryColor(),
                        backgroundColor: Colors.white,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.only(top: 8, bottom: 16),
                          itemCount:
                              _announcements.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator at bottom
                            if (index == _announcements.length) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            return _buildAnnouncementCard(
                              _announcements[index],
                              index,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),

          // Floating Action Button
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddEditDialog(),
            backgroundColor: _getPrimaryColor(),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add),
          ),
        );
      },
    );
  }
}
