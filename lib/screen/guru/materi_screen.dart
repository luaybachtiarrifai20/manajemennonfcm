import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/enhanced_search_bar.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/screen/guru/class_activity.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class MateriPage extends StatefulWidget {
  final Map<String, dynamic> guru;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;

  const MateriPage({
    super.key,
    required this.guru,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
  });

  @override
  MateriPageState createState() => MateriPageState();
}

class MateriPageState extends State<MateriPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();

  String? _selectedMataPelajaran;
  List<dynamic> _mataPelajaranList = [];
  List<dynamic> _materiList = [];
  List<dynamic> _babMateriList = [];
  List<dynamic> _subBabMateriList = [];
  List<dynamic> _kontenMateriList = [];

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterOptions = ['All', 'Today', 'This Week'];
  String _selectedFilter = 'All';

  // State untuk expanded/collapsed
  final Map<String, bool> _expandedBab = {};

  // State untuk ceklis
  final Map<String, bool> _checkedBab = {};
  final Map<String, bool> _checkedSubBab = {};
  
  // State untuk generated (sudah pernah di-generate)
  final Map<String, bool> _generatedBab = {};
  final Map<String, bool> _generatedSubBab = {};

  List<Map<String, dynamic>> _getCheckedBab() {
    return _babMateriList
        .where((bab) => _checkedBab[bab['id']] == true)
        .toList()
        .cast<Map<String, dynamic>>();
  }

  // Fungsi untuk mendapatkan sub bab yang dicentang
  List<Map<String, dynamic>> _getCheckedSubBab() {
    return _subBabMateriList
        .where((subBab) => _checkedSubBab[subBab['id']] == true)
        .toList()
        .cast<Map<String, dynamic>>();
  }
  
  // Fungsi untuk mendapatkan bab yang dicentang tapi belum di-generate
  List<Map<String, dynamic>> _getCheckedNotGeneratedBab() {
    return _babMateriList
        .where((bab) => 
          _checkedBab[bab['id']] == true && 
          _generatedBab[bab['id']] != true)
        .toList()
        .cast<Map<String, dynamic>>();
  }

  // Fungsi untuk mendapatkan sub bab yang dicentang tapi belum di-generate
  List<Map<String, dynamic>> _getCheckedNotGeneratedSubBab() {
    return _subBabMateriList
        .where((subBab) => 
          _checkedSubBab[subBab['id']] == true && 
          _generatedSubBab[subBab['id']] != true)
        .toList()
        .cast<Map<String, dynamic>>();
  }

  // Fungsi untuk navigate ke halaman class activity dengan bab yang dipilih
  void _navigateToGenerateRPP({bool allowRegenerate = false}) async {
    // Gunakan yang belum di-generate, atau semua yang checked jika allowRegenerate = true
    final checkedBab = allowRegenerate ? _getCheckedBab() : _getCheckedNotGeneratedBab();
    final checkedSubBab = allowRegenerate ? _getCheckedSubBab() : _getCheckedNotGeneratedSubBab();

    if (checkedBab.isEmpty && checkedSubBab.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(allowRegenerate 
            ? 'Pilih minimal 1 bab atau sub bab untuk regenerate'
            : 'Tidak ada materi baru yang bisa di-generate. Gunakan opsi "Regenerate" untuk materi yang sudah ada.'),
        ),
      );
      return;
    }

    String? selectedBabId;
    String? selectedSubBabId;

    // If sub bab is selected, get its parent bab and the sub bab itself
    if (checkedSubBab.isNotEmpty) {
      final firstSubBab = checkedSubBab.first;
      selectedSubBabId = firstSubBab['id']?.toString();
      selectedBabId = firstSubBab['bab_id']?.toString();
      
      if (kDebugMode) {
        print('Selected sub bab: $selectedSubBabId, parent bab: $selectedBabId');
      }
    } 
    // If only bab is selected (no sub bab)
    else if (checkedBab.isNotEmpty) {
      selectedBabId = checkedBab.first['id']?.toString();
      
      if (kDebugMode) {
        print('Selected bab only: $selectedBabId');
      }
    }

    // Mark as generated sebelum navigate
    await _markSelectedAsGenerated(checkedBab, checkedSubBab);

    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassActifityScreen(
          initialSubjectId: _selectedMataPelajaran,
          initialSubjectName: _getSelectedMataPelajaranName(),
          initialClassId: widget.initialClassId,
          initialClassName: widget.initialClassName,
          initialBabId: selectedBabId,
          initialSubBabId: selectedSubBabId,
          autoShowActivityDialog: true,
        ),
      ),
    );
  }
  
  // Mark selected materials as generated
  Future<void> _markSelectedAsGenerated(
    List<Map<String, dynamic>> babs,
    List<Map<String, dynamic>> subBabs,
  ) async {
    try {
      final String? guruId = widget.guru['id'];
      if (guruId == null || _selectedMataPelajaran == null) return;
      
      final List<Map<String, dynamic>> items = [];
      
      // Add babs
      for (var bab in babs) {
        items.add({
          'bab_id': bab['id'],
          'sub_bab_id': null,
        });
      }
      
      // Add sub-babs
      for (var subBab in subBabs) {
        items.add({
          'bab_id': subBab['bab_id'],
          'sub_bab_id': subBab['id'],
        });
      }
      
      if (items.isEmpty) return;
      
      await ApiSubjectService.markMateriGenerated({
        'guru_id': guruId,
        'mata_pelajaran_id': _selectedMataPelajaran,
        'items': items,
      });
      
      // Update local state
      setState(() {
        for (var bab in babs) {
          _generatedBab[bab['id']] = true;
        }
        for (var subBab in subBabs) {
          _generatedSubBab[subBab['id']] = true;
        }
      });
      
      if (kDebugMode) {
        print('Marked ${items.length} items as generated');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error marking as generated: $e');
      }
    }
  }

  bool _isLoading = false;
  String _debugInfo = '';

  // Color scheme matching teaching schedule
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

    if (kDebugMode) {
      print('Guru data received: ${widget.guru}');
    }
    if (kDebugMode) {
      print('Guru ID: ${widget.guru['id']}');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final String? guruId = widget.guru['id'];
      if (kDebugMode) {
        print('Loading data for guru ID: $guruId');
      }

      if (guruId == null || guruId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: ID guru tidak valid')),
        );
        return;
      }

      final ApiTeacherService apiTeacherService = ApiTeacherService();
      final mataPelajaran = await apiTeacherService.getSubjectByTeacher(guruId);

      if (kDebugMode) {
        print('Mata pelajaran found: ${mataPelajaran.length}');
      }

      // Jika guru tidak memiliki mata pelajaran, tampilkan pesan
      if (mataPelajaran.isEmpty) {
        setState(() {
          _isLoading = false;
          _mataPelajaranList = [];
          _debugInfo = 'Guru ini belum memiliki mata pelajaran yang ditugaskan';
        });
        return;
      }

      final materi = await ApiSubjectService.getMateri(guruId: guruId);

      setState(() {
        _mataPelajaranList = mataPelajaran;
        _materiList = materi;
        _isLoading = false;
        _debugInfo = '${mataPelajaran.length} mata pelajaran ditemukan';

        // Use initialSubjectId if provided, otherwise use first subject
        if (widget.initialSubjectId != null && 
            mataPelajaran.any((mp) => mp['id'] == widget.initialSubjectId)) {
          _selectedMataPelajaran = widget.initialSubjectId;
          _loadBabMateri(_selectedMataPelajaran!);
        } else if (mataPelajaran.isNotEmpty) {
          _selectedMataPelajaran = mataPelajaran[0]['id'];
          _loadBabMateri(_selectedMataPelajaran!);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _debugInfo = 'Error: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _loadBabMateri(String mataPelajaranId) async {
    try {
      final babMateri = await ApiSubjectService.getBabMateri(
        mataPelajaranId: mataPelajaranId,
      );

      setState(() {
        _babMateriList = babMateri;
        // Clear sub bab list when changing subject
        _subBabMateriList.clear();
        // Clear expanded, checked, and generated states
        _expandedBab.clear();
        _checkedBab.clear();
        _checkedSubBab.clear();
        _generatedBab.clear();
        _generatedSubBab.clear();
        // Inisialisasi state expanded dan checked untuk setiap bab
        for (var bab in babMateri) {
          _expandedBab[bab['id']] = false;
          _checkedBab[bab['id']] = false;
          _generatedBab[bab['id']] = false;
        }
        _debugInfo = '${babMateri.length} bab materi ditemukan';
      });
      
      // Load progress dari database
      await _loadMateriProgress(mataPelajaranId);
    } catch (e) {
      setState(() {
        _debugInfo = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _loadSubBabMateri(String babId) async {
    try {
      final subBabMateri = await ApiSubjectService.getSubBabMateri(
        babId: babId,
      );

      setState(() {
        // Filter sub bab yang sesuai dengan babId
        final newSubBabs = subBabMateri
            .where((subBab) => subBab['bab_id'] == babId)
            .toList();
        
        // Hapus sub bab lama dari bab ini jika ada
        _subBabMateriList.removeWhere((subBab) => subBab['bab_id'] == babId);
        
        // Tambahkan sub bab baru dari bab ini
        _subBabMateriList.addAll(newSubBabs);
        
        // Inisialisasi state checked untuk setiap sub-bab baru
        for (var subBab in newSubBabs) {
          if (!_checkedSubBab.containsKey(subBab['id'])) {
            _checkedSubBab[subBab['id']] = false;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Fungsi untuk menangani perubahan ceklis pada sub bab
  void _handleSubBabCheck(String subBabId, String babId, bool? value) {
    setState(() {
      _checkedSubBab[subBabId] = value ?? false;
      
      // Jika di-unceklis, reset is_generated juga
      if (!(value ?? false)) {
        _generatedSubBab[subBabId] = false;
      }

      // Cek apakah semua sub bab dalam bab ini sudah dicentang
      final allSubBabsChecked = _subBabMateriList
          .where((subBab) => subBab['bab_id'] == babId)
          .every((subBab) => _checkedSubBab[subBab['id']] == true);

      // Set status ceklis bab berdasarkan apakah semua sub bab sudah dicentang
      _checkedBab[babId] = allSubBabsChecked;
      
      // Jika bab menjadi unchecked, reset is_generated bab juga
      if (!allSubBabsChecked) {
        _generatedBab[babId] = false;
      }
    });
    
    // Save to database
    _saveProgress(babId, subBabId, value ?? false);
  }

  // Fungsi untuk menangani perubahan ceklis pada bab
  void _handleBabCheck(String babId, bool? value) {
    setState(() {
      _checkedBab[babId] = value ?? false;
      
      // Jika di-unceklis, reset is_generated juga
      if (!(value ?? false)) {
        _generatedBab[babId] = false;
      }

      // Jika bab dicentang/tidak dicentang, set semua sub bab dalam bab tersebut
      // dengan nilai yang sama
      for (var subBab in _subBabMateriList.where(
        (subBab) => subBab['bab_id'] == babId,
      )) {
        _checkedSubBab[subBab['id']] = value ?? false;
        
        // Jika di-unceklis, reset is_generated sub bab juga
        if (!(value ?? false)) {
          _generatedSubBab[subBab['id']] = false;
        }
      }
    });
    
    // Save to database (bab and all its sub-babs)
    _saveBabAndSubBabsProgress(babId, value ?? false);
  }

  // Load materi progress from database
  Future<void> _loadMateriProgress(String mataPelajaranId) async {
    try {
      final String? guruId = widget.guru['id'];
      if (guruId == null) return;
      
      final progress = await ApiSubjectService.getMateriProgress(
        guruId: guruId,
        mataPelajaranId: mataPelajaranId,
      );
      
      if (kDebugMode) {
        print('Loaded progress: ${progress.length} items');
      }
      
      setState(() {
        // Apply checked and generated state from database
        for (var item in progress) {
          final babId = item['bab_id'];
          final subBabId = item['sub_bab_id'];
          final isChecked = item['is_checked'] == 1 || item['is_checked'] == true;
          final isGenerated = item['is_generated'] == 1 || item['is_generated'] == true;
          
          if (subBabId != null) {
            // Sub bab checked and generated status
            _checkedSubBab[subBabId.toString()] = isChecked;
            _generatedSubBab[subBabId.toString()] = isGenerated;
          } else if (babId != null) {
            // Bab checked and generated status (no specific sub bab)
            _checkedBab[babId.toString()] = isChecked;
            _generatedBab[babId.toString()] = isGenerated;
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading progress: $e');
      }
    }
  }

  // Save single progress to database
  Future<void> _saveProgress(String babId, String? subBabId, bool isChecked) async {
    try {
      final String? guruId = widget.guru['id'];
      if (guruId == null || _selectedMataPelajaran == null) return;
      
      await ApiSubjectService.saveMateriProgress({
        'guru_id': guruId,
        'mata_pelajaran_id': _selectedMataPelajaran,
        'bab_id': babId,
        'sub_bab_id': subBabId,
        'is_checked': isChecked,
      });
      
      if (kDebugMode) {
        print('Progress saved: bab=$babId, sub_bab=$subBabId, checked=$isChecked');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving progress: $e');
      }
    }
  }

  // Save bab and all its sub-babs progress to database
  Future<void> _saveBabAndSubBabsProgress(String babId, bool isChecked) async {
    try {
      final String? guruId = widget.guru['id'];
      if (guruId == null || _selectedMataPelajaran == null) return;
      
      // Prepare batch items
      final List<Map<String, dynamic>> progressItems = [];
      
      // Add bab itself
      progressItems.add({
        'bab_id': babId,
        'sub_bab_id': null,
        'is_checked': isChecked,
      });
      
      // Add all sub-babs of this bab
      for (var subBab in _subBabMateriList.where((sb) => sb['bab_id'] == babId)) {
        progressItems.add({
          'bab_id': babId,
          'sub_bab_id': subBab['id'],
          'is_checked': isChecked,
        });
      }
      
      // Batch save
      await ApiSubjectService.batchSaveMateriProgress({
        'guru_id': guruId,
        'mata_pelajaran_id': _selectedMataPelajaran,
        'progress_items': progressItems,
      });
      
      if (kDebugMode) {
        print('Batch progress saved: ${progressItems.length} items');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error batch saving progress: $e');
      }
    }
  }

  // Navigasi ke halaman detail sub bab
  void _navigateToSubBabDetail(
    Map<String, dynamic> subBab,
    Map<String, dynamic> bab,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubBabDetailPage(
          subBab: subBab,
          bab: bab,
          checked: _checkedSubBab[subBab['id']] ?? false,
          onCheckChanged: (value) {
            _handleSubBabCheck(subBab['id'], bab['id'], value);
          },
        ),
      ),
    );
  }

  Color _getCardColor(int index) {
    final colors = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

  List<dynamic> _getFilteredBabMateri() {
    final searchTerm = _searchController.text.toLowerCase();

    if (searchTerm.isEmpty) {
      return _babMateriList;
    }

    return _babMateriList.where((bab) {
      final matchesBab =
          (bab['judul_bab']?.toString().toLowerCase().contains(searchTerm) ??
          false);

      // Cari juga di sub bab yang terkait
      final subBabMatches = _subBabMateriList
          .where((subBab) => subBab['bab_id'] == bab['id'])
          .any(
            (subBab) =>
                subBab['judul_sub_bab']?.toString().toLowerCase().contains(
                  searchTerm,
                ) ??
                false,
          );

      return matchesBab || subBabMatches;
    }).toList();
  }

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
                        'en': 'Learning Materials',
                        'id': 'Materi Pembelajaran',
                      }),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      AppLocalizations.selectAndOrganizeMaterials.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.auto_awesome, color: Colors.white),
                onPressed: _navigateToGenerateRPP,
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Generate RPP',
                  'id': 'Generate RPP',
                }),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadData,
                tooltip: languageProvider.getTranslatedText({
                  'en': 'Refresh',
                  'id': 'Muat Ulang',
                }),
              ),
            ],
          ),
        ],
      ),
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
              // Header dengan gradient seperti presence_teacher
              _buildHeader(languageProvider),

              // Filter Section
              _buildFilterSection(languageProvider),

              // Search Bar
              Consumer<LanguageProvider>(
                builder: (context, languageProvider, child) {
                  final translatedFilterOptions = [
                    languageProvider.getTranslatedText({
                      'en': 'All',
                      'id': 'Semua',
                    }),
                    languageProvider.getTranslatedText({
                      'en': 'Today',
                      'id': 'Hari Ini',
                    }),
                    languageProvider.getTranslatedText({
                      'en': 'This Week',
                      'id': 'Minggu Ini',
                    }),
                  ];

                  return EnhancedSearchBar(
                    controller: _searchController,
                    hintText: languageProvider.getTranslatedText({
                      'en': 'Search materials...',
                      'id': 'Cari materi...',
                    }),
                    onChanged: (value) {
                      setState(() {});
                    },
                    filterOptions: translatedFilterOptions,
                    selectedFilter:
                        translatedFilterOptions[_selectedFilter == 'All'
                            ? 0
                            : _selectedFilter == 'Today'
                            ? 1
                            : 2],
                    onFilterChanged: (filter) {
                      final index = translatedFilterOptions.indexOf(filter);
                      setState(() {
                        _selectedFilter = index == 0
                            ? 'All'
                            : index == 1
                            ? 'Today'
                            : 'This Week';
                      });
                    },
                    showFilter: true,
                  );
                },
              ),

              // Search Results Info
              if (_searchController.text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${_getFilteredBabMateri().length} ${languageProvider.getTranslatedText({'en': 'materials found', 'id': 'materi ditemukan'})}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 8),

              // Content Section
              Expanded(
                child: _isLoading
                    ? LoadingScreen(
                        message: languageProvider.getTranslatedText({
                          'en': 'Loading materials...',
                          'id': 'Memuat materi...',
                        }),
                      )
                    : _selectedMataPelajaran == null
                    ? _buildEmptyState(
                        languageProvider.getTranslatedText({
                          'en': 'Select subject to view materials',
                          'id': 'Pilih mata pelajaran untuk melihat materi',
                        }),
                        languageProvider,
                      )
                    : _babMateriList.isEmpty
                    ? _buildEmptyState(
                        languageProvider.getTranslatedText({
                          'en': 'No materials available for this subject',
                          'id': 'Tidak ada materi untuk mata pelajaran ini',
                        }),
                        languageProvider,
                      )
                    : _getFilteredBabMateri().isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No Materials Found',
                          'id': 'Materi Tidak Ditemukan',
                        }),
                        subtitle: languageProvider.getTranslatedText({
                          'en':
                              'No search results found for "${_searchController.text}"',
                          'id':
                              'Tidak ditemukan hasil pencarian untuk "${_searchController.text}"',
                        }),
                        icon: Icons.search,
                      )
                    : _buildMateriList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // Update Filter Section untuk tambah info dan tombol
  Widget _buildFilterSection(LanguageProvider languageProvider) {
    final totalChecked = _getCheckedCount();

    return Container(
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // Info Filter Aktif
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _mataPelajaranList.isEmpty
                        ? languageProvider.getTranslatedText({
                            'en': 'No subjects available',
                            'id': 'Tidak ada mata pelajaran',
                          })
                        : '${_babMateriList.length} ${languageProvider.getTranslatedText({'en': 'materials', 'id': 'bab materi'})} • ${_getSelectedMataPelajaranName()}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                  ),
                ),
                Text(
                  '$totalChecked ${languageProvider.getTranslatedText({'en': 'checked', 'id': 'dicentang'})}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Tombol Generate RPP jika ada yang dicentang
          if (totalChecked > 0) ...[
            Row(
              children: [
                // Tombol Generate (untuk yang baru / belum di-generate)
                Expanded(
                  flex: _getCheckedNotGeneratedCount() > 0 ? 3 : 0,
                  child: _getCheckedNotGeneratedCount() > 0
                    ? ElevatedButton.icon(
                        onPressed: () => _navigateToGenerateRPP(allowRegenerate: false),
                        icon: Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          'Generate (${_getCheckedNotGeneratedCount()})',
                          style: TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    : SizedBox.shrink(),
                ),
                if (_getCheckedNotGeneratedCount() > 0) SizedBox(width: 8),
                // Tombol Regenerate (untuk semua yang checked)
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToGenerateRPP(allowRegenerate: true),
                    icon: Icon(Icons.refresh, size: 18),
                    label: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Regenerate',
                        'id': 'Regenerate',
                      }),
                      style: TextStyle(fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
          ],

          // Dropdown Mata Pelajaran
          _buildMataPelajaranDropdown(languageProvider),
        ],
      ),
    );
  }

  Widget _buildMataPelajaranDropdown(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'Subject',
            'id': 'Mata Pelajaran',
          }),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMataPelajaran,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
              items: _mataPelajaranList.map((mp) {
                return DropdownMenuItem<String>(
                  value: mp['id'],
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.subject,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text(mp['nama'] ?? 'Unknown')),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedMataPelajaran = newValue;
                    _babMateriList = [];
                    _subBabMateriList = [];
                    _kontenMateriList = [];
                    _searchController.clear();
                  });
                  _loadBabMateri(newValue);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, LanguageProvider languageProvider) {
    return EmptyState(
      title: languageProvider.getTranslatedText({
        'en': 'No Materials',
        'id': 'Tidak Ada Materi',
      }),
      subtitle: message,
      icon: Icons.menu_book,
    );
  }

  Widget _buildMateriList() {
    final filteredBabMateri = _getFilteredBabMateri();

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: filteredBabMateri.length,
      itemBuilder: (context, index) {
        final bab = filteredBabMateri[index];
        final cardColor = _getCardColor(index);
        final isExpanded = _expandedBab[bab['id']] ?? false;

        return Container(
          margin: EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _expandedBab[bab['id']] = !isExpanded;
                  if (!isExpanded) {
                    _loadSubBabMateri(bab['id']);
                  }
                });
              },
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
                          color: cardColor,
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

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Bab
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${bab['urutan']}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bab['judul_bab'] ?? 'Judul Bab',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Bab ${bab['urutan']}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Checkbox(
                                value: _checkedBab[bab['id']] ?? false,
                                onChanged: (value) {
                                  _handleBabCheck(bab['id'], value);
                                },
                                activeColor: _generatedBab[bab['id']] == true 
                                    ? Color(0xFF8B5CF6)
                                    : Color(0xFF10B981),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                        
                        // Sub Bab List (Expandable)
                        if (isExpanded) ...[
                          Divider(height: 1),
                          _buildSubBabList(bab),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubBabList(Map<String, dynamic> bab) {
    if (_subBabMateriList.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Tidak ada sub-bab',
          style: TextStyle(color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: _subBabMateriList
          .where((subBab) => subBab['bab_id'] == bab['id'])
          .map((subBab) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getCardColor(
                        int.parse(subBab['urutan']?.toString() ?? '0'),
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${subBab['urutan']}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  trailing: Checkbox(
                    value: _checkedSubBab[subBab['id']] ?? false,
                    onChanged: (value) {
                      _handleSubBabCheck(subBab['id'], bab['id'], value);
                    },
                    activeColor: _generatedSubBab[subBab['id']] == true 
                        ? Color(0xFF8B5CF6)
                        : Color(0xFF10B981),
                  ),
                  onTap: () {
                    _navigateToSubBabDetail(subBab, bab);
                  },
                ),
              ),
            );
          })
          .toList(),
    );
  }

  String _getSelectedMataPelajaranName() {
    if (_selectedMataPelajaran == null) return '-';
    final mp = _mataPelajaranList.firstWhere(
      (mp) => mp['id'] == _selectedMataPelajaran,
      orElse: () => {'nama': '-'},
    );
    return mp['nama'] ?? '-';
  }

  int _getCheckedCount() {
    final babChecked = _checkedBab.values.where((checked) => checked).length;
    final subBabChecked = _checkedSubBab.values
        .where((checked) => checked)
        .length;
    return babChecked + subBabChecked;
  }
  
  int _getCheckedNotGeneratedCount() {
    return _getCheckedNotGeneratedBab().length + _getCheckedNotGeneratedSubBab().length;
  }
}

// Halaman detail untuk sub bab (diperbarui dengan design yang sama)
class SubBabDetailPage extends StatefulWidget {
  final Map<String, dynamic> subBab;
  final Map<String, dynamic> bab;
  final bool checked;
  final ValueChanged<bool?> onCheckChanged;

  const SubBabDetailPage({
    super.key,
    required this.subBab,
    required this.bab,
    required this.checked,
    required this.onCheckChanged,
  });

  @override
  SubBabDetailPageState createState() => SubBabDetailPageState();
}

class SubBabDetailPageState extends State<SubBabDetailPage> {
  late bool _isChecked;
  List<dynamic> _kontenMateriList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isChecked = widget.checked;
    _loadKontenMateri();
  }

  Future<void> _loadKontenMateri() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final kontenMateri = await ApiSubjectService.getContentMateri(
        subBabId: widget.subBab['id'],
      );

      setState(() {
        _kontenMateriList = kontenMateri
            .where((konten) => konten['sub_bab_id'] == widget.subBab['id'])
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Color _getCardColor(int index) {
    final colors = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ];
    return colors[index % colors.length];
  }

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
                      'BAB ${widget.bab['urutan']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      widget.bab['judul_bab'] ?? 'Judul Bab',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Done',
                        'id': 'Selesai',
                      }),
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                    Checkbox(
                      value: _isChecked,
                      onChanged: (value) {
                        setState(() {
                          _isChecked = value ?? false;
                        });
                        widget.onCheckChanged(value);
                      },
                      fillColor: WidgetStateProperty.all(Colors.white),
                      checkColor: _getPrimaryColor(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.description, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sub Bab ${widget.subBab['urutan']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        widget.subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              // Header dengan gradient
              _buildHeader(languageProvider),

              // Content
              Expanded(
                child: _isLoading
                    ? LoadingScreen(
                        message: languageProvider.getTranslatedText({
                          'en': 'Loading content...',
                          'id': 'Memuat konten...',
                        }),
                      )
                    : _kontenMateriList.isEmpty
                    ? _buildEmptyContent(languageProvider)
                    : _buildContentList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyContent(LanguageProvider languageProvider) {
    return EmptyState(
      title: languageProvider.getTranslatedText({
        'en': 'No Content',
        'id': 'Tidak Ada Konten',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': 'Content for this sub-chapter is not available yet',
        'id': 'Konten untuk sub bab ini belum tersedia',
      }),
      icon: Icons.article,
    );
  }

  Widget _buildContentList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _kontenMateriList.length,
      itemBuilder: (context, index) {
        final konten = _kontenMateriList[index];
        final cardColor = _getCardColor(index);

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Number Section dengan background warna
                Container(
                  width: 60,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Konten',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Section
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          konten['judul_konten'] ?? 'Judul Konten',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Text(
                          konten['isi_konten'] ?? 'Isi konten tidak tersedia',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
