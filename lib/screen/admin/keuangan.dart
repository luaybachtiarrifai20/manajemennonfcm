// keuangan.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:provider/provider.dart';
import 'package:manajemensekolah/components/confirmation_dialog.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';

class KeuanganScreen extends StatefulWidget {
  const KeuanganScreen({super.key});

  @override
  KeuanganScreenState createState() => KeuanganScreenState();
}

class KeuanganScreenState extends State<KeuanganScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _jenisPembayaranList = [];
  List<dynamic> _tagihanList = [];
  List<dynamic> _pembayaranPendingList = [];
  List<dynamic> _kelasList = [];
  List<dynamic> _siswaList = [];
  Map<String, List<dynamic>> _siswaByKelas = {};
  Map<String, List<dynamic>> _tagihanBySiswa = {};
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentTabIndex = 0;

  // Search dan filter
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter; // 'aktif', 'non_aktif', atau null untuk semua
  String? _selectedPeriodeFilter; // 'bulanan', 'tahunan', atau null untuk semua
  bool _hasActiveFilter = false;

  // Variabel untuk modal pemilihan tujuan
  List<dynamic> _selectedKelas = [];
  Map<String, List<dynamic>> _selectedSiswaByKelas = {};
  List<dynamic> _allSiswaList = [];
  final TextEditingController _searchSiswaController = TextEditingController();

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
    _searchSiswaController.dispose();
    super.dispose();
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedStatusFilter != null || _selectedPeriodeFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedPeriodeFilter = null;
      _hasActiveFilter = false;
    });
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedStatusFilter != null) {
      final statusText = _selectedStatusFilter == 'aktif'
          ? languageProvider.getTranslatedText({'en': 'Active', 'id': 'Aktif'})
          : languageProvider.getTranslatedText({
              'en': 'Inactive',
              'id': 'Non-Aktif',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
        'onRemove': () {
          setState(() {
            _selectedStatusFilter = null;
            _checkActiveFilter();
          });
        },
      });
    }

    if (_selectedPeriodeFilter != null) {
      final periodeText = _selectedPeriodeFilter == 'bulanan'
          ? languageProvider.getTranslatedText({
              'en': 'Monthly',
              'id': 'Bulanan',
            })
          : languageProvider.getTranslatedText({
              'en': 'Yearly',
              'id': 'Tahunan',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Period', 'id': 'Periode'})}: $periodeText',
        'onRemove': () {
          setState(() {
            _selectedPeriodeFilter = null;
            _checkActiveFilter();
          });
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = context.read<LanguageProvider>();

    // Temporary state for bottom sheet
    String? tempSelectedStatus = _selectedStatusFilter;
    String? tempSelectedPeriode = _selectedPeriodeFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                          tempSelectedStatus = null;
                          tempSelectedPeriode = null;
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
                    crossAxisAlignment: CrossAxisAlignment
                        .start, // Ubah ke start agar konten lebih ke kiri
                    children: [
                      // Status Filter
                      Container(
                        width: double
                            .infinity, // Pastikan container memenuhi lebar
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment
                              .start, // Konten di dalam juga rata kiri
                          children: [
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
                              alignment: WrapAlignment
                                  .start, // Pastikan chip mulai dari kiri
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  [
                                    {
                                      'value': 'aktif',
                                      'label': languageProvider
                                          .getTranslatedText({
                                            'en': 'Active',
                                            'id': 'Aktif',
                                          }),
                                    },
                                    {
                                      'value': 'non_aktif',
                                      'label': languageProvider
                                          .getTranslatedText({
                                            'en': 'Inactive',
                                            'id': 'Non-Aktif',
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
                                      selectedColor: _getPrimaryColor()
                                          .withOpacity(0.2),
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
                      SizedBox(height: 24),

                      // Divider seperti pada gambar
                      Container(
                        height: 1,
                        color: Colors.grey.shade300,
                        margin: EdgeInsets.symmetric(vertical: 8),
                      ),

                      // Periode Filter
                      Container(
                        width: double
                            .infinity, // Pastikan container memenuhi lebar
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment
                              .start, // Konten di dalam juga rata kiri
                          children: [
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Payment Period',
                                'id': 'Periode Pembayaran',
                              }),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment
                                  .start, // Pastikan chip mulai dari kiri
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  [
                                    {
                                      'value': 'bulanan',
                                      'label': languageProvider
                                          .getTranslatedText({
                                            'en': 'Monthly',
                                            'id': 'Bulanan',
                                          }),
                                    },
                                    {
                                      'value': 'tahunan',
                                      'label': languageProvider
                                          .getTranslatedText({
                                            'en': 'Yearly',
                                            'id': 'Tahunan',
                                          }),
                                    },
                                  ].map((item) {
                                    final isSelected =
                                        tempSelectedPeriode == item['value'];
                                    return FilterChip(
                                      label: Text(item['label']!),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setModalState(() {
                                          tempSelectedPeriode = selected
                                              ? item['value']
                                              : null;
                                        });
                                      },
                                      backgroundColor: Colors.grey.shade100,
                                      selectedColor: _getPrimaryColor()
                                          .withOpacity(0.2),
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
                            _selectedStatusFilter = tempSelectedStatus;
                            _selectedPeriodeFilter = tempSelectedPeriode;
                            _checkActiveFilter();
                          });
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

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Load semua data sekaligus
      await Future.wait([
        _loadJenisPembayaran(),
        _loadTagihan(),
        _loadPembayaranPending(),
        _loadDashboardData(),
        _loadKelasData(),
      ]);

      setState(() {
        _isLoading = false;
      });

      _animationController.forward();
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load financial data';
      });
    }
  }

  // Tambahkan method baru untuk load data kelas dan siswa
  Future<void> _loadKelasData() async {
    try {
      // Load data kelas
      final kelasResponse = await _apiService.get('/kelas');
      setState(() {
        _kelasList = kelasResponse is List ? kelasResponse : [];
      });

      // Load data siswa
      final siswaResponse = await _apiService.get('/siswa');
      final List<dynamic> allSiswa = siswaResponse is List ? siswaResponse : [];

      // Kelompokkan siswa berdasarkan kelas
      Map<String, List<dynamic>> siswaByKelas = {};
      for (var siswa in allSiswa) {
        final kelasId = siswa['kelas_id']?.toString();
        if (kelasId != null) {
          if (!siswaByKelas.containsKey(kelasId)) {
            siswaByKelas[kelasId] = [];
          }
          siswaByKelas[kelasId]!.add(siswa);
        }
      }

      setState(() {
        _siswaByKelas = siswaByKelas;
        _siswaList = allSiswa;
      });

      // Load tagihan untuk setiap siswa
      await _loadTagihanForSiswa(allSiswa);
    } catch (error) {
      print('Error loading kelas data: $error');
    }
  }

  Future<void> _loadTagihanForSiswa(List<dynamic> siswaList) async {
    try {
      Map<String, List<dynamic>> tagihanBySiswa = {};

      for (var siswa in siswaList) {
        final siswaId = siswa['id']?.toString();
        if (siswaId != null) {
          final tagihanResponse = await _apiService.get(
            '/tagihan?siswa_id=$siswaId',
          );
          final List<dynamic> tagihanSiswa = tagihanResponse is List
              ? tagihanResponse
              : [];
          tagihanBySiswa[siswaId] = tagihanSiswa;
        }
      }

      setState(() {
        _tagihanBySiswa = tagihanBySiswa;
      });
    } catch (error) {
      print('Error loading tagihan for siswa: $error');
    }
  }

  // Method helper untuk parsing tujuan
  Map<String, dynamic> _parseTujuan(dynamic tujuanData) {
    if (tujuanData == null) {
      return {};
    }

    if (tujuanData is Map<String, dynamic>) {
      return tujuanData;
    }

    if (tujuanData is String) {
      try {
        return json.decode(tujuanData) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing tujuan JSON: $e');
        return {};
      }
    }

    return {};
  }

  String _getTujuanDescription(dynamic tujuanData) {
    final parsedTujuan = _parseTujuan(tujuanData);
    return parsedTujuan['description'] ?? 'Tujuan pembayaran';
  }

  void _showPemilihanTujuanModal({
    Map<String, dynamic>? jenisPembayaran,
    required Function(Map<String, dynamic>) onSave,
  }) {
    // Reset state
    _selectedKelas = [];
    _selectedSiswaByKelas = {};
    _searchSiswaController.clear();

    // Jika edit, load data tujuan yang sudah dipilih
    if (jenisPembayaran?['tujuan'] != null) {
      _loadExistingTujuan(jenisPembayaran!['tujuan']);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getPrimaryColor(),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.groups, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pilih Tujuan Pembayaran',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Search Siswa
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchSiswaController,
                      decoration: InputDecoration(
                        hintText: 'Cari siswa...',
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (value) {
                        setModalState(() {});
                      },
                    ),
                  ),
                ),

                // Quick Actions
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _selectAllKelas(setModalState),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: _getPrimaryColor()),
                          ),
                          child: Text(
                            'Pilih Semua Kelas',
                            style: TextStyle(
                              fontSize: 12,
                              color: _getPrimaryColor(),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _clearAllSelection(setModalState),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.red),
                          ),
                          child: Text(
                            'Hapus Semua',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // List Kelas
                Expanded(child: _buildKelasListForSelection(setModalState)),

                // Footer dengan summary
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border(
                      top: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSelectionSummary(),
                      SizedBox(height: 12),
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
                              ),
                              child: Text('Batal'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                final tujuan = _buildTujuanData();
                                onSave(tujuan);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getPrimaryColor(),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Simpan'),
                            ),
                          ),
                        ],
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

  void _loadExistingTujuan(dynamic tujuanData) {
    final tujuan = _parseTujuan(tujuanData);

    if (tujuan['type'] == 'all') {
      // Pilih semua kelas
      _selectedKelas = List.from(_kelasList);
      for (var kelas in _kelasList) {
        final kelasId = kelas['id'].toString();
        _selectedSiswaByKelas[kelasId] = List.from(
          _siswaByKelas[kelasId] ?? [],
        );
      }
    } else if (tujuan['type'] == 'custom') {
      // Load custom selection
      _selectedKelas = _kelasList.where((kelas) {
        return tujuan['kelas']?.contains(kelas['id'].toString()) == true;
      }).toList();

      for (var kelasId in tujuan['kelas'] ?? []) {
        _selectedSiswaByKelas[kelasId] = (tujuan['siswa']?[kelasId] ?? [])
            .map((siswaId) => _findSiswaById(siswaId))
            .where((siswa) => siswa != null)
            .cast<Map<String, dynamic>>()
            .toList();
      }
    }
  }

  dynamic _findSiswaById(String siswaId) {
    for (var siswaList in _siswaByKelas.values) {
      for (var siswa in siswaList) {
        if (siswa['id'].toString() == siswaId) {
          return siswa;
        }
      }
    }
    return null;
  }

  Widget _buildKelasListForSelection(StateSetter setModalState) {
    final searchTerm = _searchSiswaController.text.toLowerCase();

    return ListView.builder(
      itemCount: _kelasList.length,
      itemBuilder: (context, index) {
        final kelas = _kelasList[index];
        final kelasId = kelas['id'].toString();
        final isKelasSelected = _selectedKelas.any(
          (k) => k['id'].toString() == kelasId,
        );
        final siswaList = _siswaByKelas[kelasId] ?? [];

        // Filter siswa berdasarkan search
        final filteredSiswa = siswaList.where((siswa) {
          final nama = siswa['nama']?.toString().toLowerCase() ?? '';
          final nis = siswa['nis']?.toString().toLowerCase() ?? '';
          return searchTerm.isEmpty ||
              nama.contains(searchTerm) ||
              nis.contains(searchTerm);
        }).toList();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ExpansionTile(
            leading: Checkbox(
              value: isKelasSelected,
              onChanged: (value) {
                setModalState(() {
                  if (value == true) {
                    _selectedKelas.add(kelas);
                    _selectedSiswaByKelas[kelasId] = List.from(siswaList);
                  } else {
                    _selectedKelas.removeWhere(
                      (k) => k['id'].toString() == kelasId,
                    );
                    _selectedSiswaByKelas.remove(kelasId);
                  }
                });
              },
            ),
            title: Text(
              kelas['nama'] ?? 'Kelas',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isKelasSelected ? _getPrimaryColor() : Colors.black,
              ),
            ),
            subtitle: Text(
              '${siswaList.length} siswa',
              style: TextStyle(fontSize: 12),
            ),
            trailing: isKelasSelected
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedSiswaByKelas[kelasId]?.length ?? 0}/${siswaList.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _getPrimaryColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            children: [
              if (filteredSiswa.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tidak ada siswa yang cocok dengan pencarian',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                ...filteredSiswa
                    .map(
                      (siswa) => _buildSiswaCheckbox(
                        siswa: siswa,
                        kelasId: kelasId,
                        setModalState: setModalState,
                      ),
                    )
                    .toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSiswaCheckbox({
    required Map<String, dynamic> siswa,
    required String kelasId,
    required StateSetter setModalState,
  }) {
    final isSelected =
        _selectedSiswaByKelas[kelasId]?.any(
          (s) => s['id'].toString() == siswa['id'].toString(),
        ) ==
        true;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setModalState(() {
            final siswaList = _selectedSiswaByKelas[kelasId] ?? [];
            if (value == true) {
              siswaList.add(siswa);
            } else {
              siswaList.removeWhere(
                (s) => s['id'].toString() == siswa['id'].toString(),
              );
            }
            _selectedSiswaByKelas[kelasId] = siswaList;

            // Update kelas selection
            if (siswaList.isEmpty) {
              _selectedKelas.removeWhere((k) => k['id'].toString() == kelasId);
            } else if (!_selectedKelas.any(
              (k) => k['id'].toString() == kelasId,
            )) {
              _selectedKelas.add(
                _kelasList.firstWhere((k) => k['id'].toString() == kelasId),
              );
            }
          });
        },
        title: Text(siswa['nama'] ?? 'Siswa', style: TextStyle(fontSize: 14)),
        subtitle: Text(
          'NIS: ${siswa['nis'] ?? '-'}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildSelectionSummary() {
    int totalKelas = _selectedKelas.length;
    int totalSiswa = _selectedSiswaByKelas.values.fold(
      0,
      (sum, siswaList) => sum + siswaList.length,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Terpilih:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              '$totalKelas Kelas • $totalSiswa Siswa',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _getPrimaryColor(),
              ),
            ),
          ],
        ),
        if (totalKelas == _kelasList.length && totalSiswa == _getTotalSiswa())
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Semua Siswa',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  int _getTotalSiswa() {
    return _siswaByKelas.values.fold(
      0,
      (sum, siswaList) => sum + siswaList.length,
    );
  }

  void _selectAllKelas(StateSetter setModalState) {
    setModalState(() {
      _selectedKelas = List.from(_kelasList);
      for (var kelas in _kelasList) {
        final kelasId = kelas['id'].toString();
        _selectedSiswaByKelas[kelasId] = List.from(
          _siswaByKelas[kelasId] ?? [],
        );
      }
    });
  }

  void _clearAllSelection(StateSetter setModalState) {
    setModalState(() {
      _selectedKelas.clear();
      _selectedSiswaByKelas.clear();
    });
  }

  Map<String, dynamic> _buildTujuanData() {
    final totalKelas = _selectedKelas.length;
    final totalSiswa = _getTotalSiswa();
    final selectedSiswaCount = _selectedSiswaByKelas.values.fold(
      0,
      (sum, siswaList) => sum + siswaList.length,
    );

    // Jika semua kelas dan semua siswa terpilih
    if (totalKelas == _kelasList.length && selectedSiswaCount == totalSiswa) {
      return {'type': 'all', 'description': 'Semua siswa di semua kelas'};
    }

    // Custom selection
    final kelasIds = _selectedKelas.map((k) => k['id'].toString()).toList();
    final siswaMap = <String, List<String>>{};

    _selectedSiswaByKelas.forEach((kelasId, siswaList) {
      siswaMap[kelasId] = siswaList.map((s) => s['id'].toString()).toList();
    });

    return {
      'type': 'custom',
      'kelas': kelasIds,
      'siswa': siswaMap,
      'description': '$selectedSiswaCount siswa di $totalKelas kelas',
    };
  }

  // Widget untuk tab Laporan Kelas
  Widget _buildLaporanKelasTab() {
    if (_kelasList.isEmpty) {
      return EmptyState(
        title: 'Belum ada data kelas',
        subtitle: 'Data kelas akan muncul di sini',
        icon: Icons.class_,
      );
    }

    return ListView.builder(
      itemCount: _kelasList.length,
      itemBuilder: (context, index) {
        final kelas = _kelasList[index];
        final kelasId = kelas['id']?.toString();
        final siswaList = _siswaByKelas[kelasId] ?? [];

        return _buildKelasCard(kelas, siswaList, index);
      },
    );
  }

  Widget _buildKelasCard(
    Map<String, dynamic> kelas,
    List<dynamic> siswaList,
    int index,
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
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getPrimaryColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.class_, color: _getPrimaryColor()),
            ),
            title: Text(
              kelas['nama'] ?? 'Kelas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${siswaList.length} siswa',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            trailing: _buildKelasSummary(siswaList),
            children: [
              if (siswaList.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Tidak ada siswa di kelas ini',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...siswaList.map((siswa) => _buildSiswaCard(siswa)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKelasSummary(List<dynamic> siswaList) {
    int totalLunas = 0;
    int totalPending = 0;
    int totalBelumBayar = 0;

    for (var siswa in siswaList) {
      final siswaId = siswa['id']?.toString();
      final tagihanList = _tagihanBySiswa[siswaId] ?? [];

      for (var tagihan in tagihanList) {
        final status = tagihan['status'];
        if (status == 'verified') {
          totalLunas++;
        } else if (status == 'pending') {
          totalPending++;
        } else if (status == 'unpaid') {
          totalBelumBayar++;
        }
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (totalLunas > 0) _buildStatusIndicator(Colors.green, totalLunas),
        if (totalPending > 0)
          _buildStatusIndicator(Colors.orange, totalPending),
        if (totalBelumBayar > 0)
          _buildStatusIndicator(Colors.red, totalBelumBayar),
      ],
    );
  }

  Widget _buildStatusIndicator(Color color, int count) {
    return Container(
      margin: EdgeInsets.only(left: 4),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSiswaCard(Map<String, dynamic> siswa) {
    final siswaId = siswa['id']?.toString();
    final tagihanList = _tagihanBySiswa[siswaId] ?? [];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getPrimaryColor().withOpacity(0.1),
          child: Text(
            siswa['nama']?.toString().substring(0, 1).toUpperCase() ?? 'S',
            style: TextStyle(color: _getPrimaryColor(), fontSize: 12),
          ),
        ),
        title: Text(
          siswa['nama'] ?? 'Siswa',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'NIS: ${siswa['nis'] ?? '-'}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: _buildSiswaSummary(tagihanList),
        children: [
          if (tagihanList.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tidak ada tagihan untuk siswa ini',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            )
          else
            ...tagihanList
                .map((tagihan) => _buildTagihanItem(tagihan))
                .toList(),
        ],
      ),
    );
  }

  Widget _buildSiswaSummary(List<dynamic> tagihanList) {
    int totalLunas = tagihanList.where((t) => t['status'] == 'verified').length;
    int totalPending = tagihanList
        .where((t) => t['status'] == 'pending')
        .length;
    int totalBelumBayar = tagihanList
        .where((t) => t['status'] == 'unpaid')
        .length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (totalLunas > 0) _buildMiniIndicator(Colors.green, totalLunas),
        if (totalPending > 0) _buildMiniIndicator(Colors.orange, totalPending),
        if (totalBelumBayar > 0)
          _buildMiniIndicator(Colors.red, totalBelumBayar),
      ],
    );
  }

  Widget _buildMiniIndicator(Color color, int count) {
    return Container(
      margin: EdgeInsets.only(left: 2),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          count.toString(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTagihanItem(Map<String, dynamic> tagihan) {
    final status = tagihan['status'];
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'verified':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'LUNAS';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'MENUNGGU';
        break;
      case 'unpaid':
      default:
        statusColor = Colors.red;
        statusIcon = Icons.pending_actions;
        statusText = 'BELUM BAYAR';
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Stack(
        children: [
          // Status badge di pojok kanan atas
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Content utama
          Padding(
            padding: EdgeInsets.only(right: 100, bottom: status == 'unpaid' ? 35 : 0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 16),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tagihan['jenis_pembayaran_nama'] ?? 'Tagihan',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Rp ${tagihan['jumlah']}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      if (tagihan['jatuh_tempo'] != null)
                        Text(
                          'Jatuh tempo: ${tagihan['jatuh_tempo']?.split('T')[0] ?? '-'}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tombol bayar di pojok kanan bawah untuk status unpaid
          if (status == 'unpaid')
            Positioned(
              bottom: 0,
              right: 0,
              child: ElevatedButton.icon(
                onPressed: () => _showManualPaymentDialog(tagihan),
                icon: Icon(Icons.payment, size: 14),
                label: Text(
                  'Bayar',
                  style: TextStyle(fontSize: 10),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size(0, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Dialog untuk input pembayaran manual
  void _showManualPaymentDialog(Map<String, dynamic> tagihan) {
    final TextEditingController jumlahController = TextEditingController(
      text: tagihan['jumlah']?.toString() ?? '',
    );
    final TextEditingController tanggalController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );
    String metodeBayar = 'cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.payment, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Input Pembayaran Manual',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Tagihan
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detail Tagihan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Jenis: ${tagihan['jenis_pembayaran_nama'] ?? '-'}',
                        style: TextStyle(fontSize: 11),
                      ),
                      Text(
                        'Siswa: ${tagihan['siswa_nama'] ?? '-'}',
                        style: TextStyle(fontSize: 11),
                      ),
                      Text(
                        'Kelas: ${tagihan['kelas_nama'] ?? '-'}',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                
                // Metode Pembayaran
                Text(
                  'Metode Pembayaran',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: metodeBayar,
                      isExpanded: true,
                      items: [
                        DropdownMenuItem(
                          value: 'cash',
                          child: Row(
                            children: [
                              Icon(Icons.money, size: 16, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Tunai'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'transfer',
                          child: Row(
                            children: [
                              Icon(Icons.account_balance, size: 16, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Transfer Bank'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          metodeBayar = value!;
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // Jumlah Bayar
                Text(
                  'Jumlah Bayar (Rp)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: jumlahController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Masukkan jumlah bayar',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                
                // Tanggal Bayar
                Text(
                  'Tanggal Bayar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: tanggalController,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Pilih tanggal',
                    suffixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() {
                        tanggalController.text = date.toString().split(' ')[0];
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (jumlahController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Jumlah bayar harus diisi')),
                  );
                  return;
                }
                
                try {
                  await _apiService.inputPembayaranManual({
                    'tagihan_id': tagihan['id'],
                    'metode_bayar': metodeBayar,
                    'jumlah_bayar': int.parse(jumlahController.text),
                    'tanggal_bayar': tanggalController.text,
                  });
                  
                  if (!mounted) return;
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pembayaran berhasil dicatat'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Reload data
                  _loadData();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal mencatat pembayaran: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              icon: Icon(Icons.save),
              label: Text('Simpan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadJenisPembayaran() async {
    try {
      final response = await _apiService.get('/jenis-pembayaran');
      setState(() {
        _jenisPembayaranList = response is List ? response : [];
      });
    } catch (error) {
      print('Error loading jenis pembayaran: $error');
    }
  }

  Future<void> _loadTagihan() async {
    try {
      final response = await _apiService.get('/tagihan');
      setState(() {
        _tagihanList = response is List ? response : [];
      });
    } catch (error) {
      print('Error loading tagihan: $error');
    }
  }

  Future<void> _loadPembayaranPending() async {
    try {
      final response = await _apiService.get('/pembayaran/pending');
      setState(() {
        _pembayaranPendingList = response is List ? response : [];
      });
    } catch (error) {
      print('Error loading pembayaran pending: $error');
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final response = await _apiService.get('/dashboard-keuangan');
      setState(() {
        _dashboardData = (response as Map).cast<String, dynamic>();
      });
    } catch (error) {
      print('Error loading dashboard data: $error');
    }
  }

  // Dalam KeuanganScreenState, tambahkan method ini:
  void _showBuktiPembayaran(Map<String, dynamic> pembayaran) {
    if (pembayaran['bukti_bayar'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak ada bukti pembayaran'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: _getCardGradient(),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.photo_library, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Bukti Pembayaran',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Image
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      '${_getImageUrl(pembayaran['bukti_bayar'])}',
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Gagal memuat gambar',
                              style: TextStyle(color: Colors.red),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'File: ${pembayaran['bukti_bayar']}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Info
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Pembayaran',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildInfoItem('Siswa', pembayaran['siswa_nama'] ?? '-'),
                    _buildInfoItem('Kelas', pembayaran['kelas_nama'] ?? '-'),
                    _buildInfoItem(
                      'Jenis',
                      pembayaran['jenis_pembayaran_nama'] ?? '-',
                    ),
                    _buildInfoItem(
                      'Jumlah',
                      'Rp ${pembayaran['jumlah_bayar']}',
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

  String _getImageUrl(String? filename) {
    if (filename == null) return '';

    // Sesuaikan dengan base URL Anda
    // Contoh: http://localhost:3000/uploads/nama_file.jpg
    return '${ApiService.baseUrl.replaceFirst('/api', '')}/uploads/bukti-pembayaran/$filename';
    // return 'http://localhost:3000/uploads/bukti-pembayaran/$filename';
  }

  void _showAddEditJenisPembayaran({Map<String, dynamic>? jenisPembayaran}) {
    final namaController = TextEditingController(
      text: jenisPembayaran?['nama'],
    );
    final deskripsiController = TextEditingController(
      text: jenisPembayaran?['deskripsi'],
    );
    final jumlahController = TextEditingController(
      text: jenisPembayaran?['jumlah']?.toString(),
    );
    final periodeController = TextEditingController(
      text: jenisPembayaran?['periode'],
    );

    Map<String, dynamic>? tujuanData = jenisPembayaran != null
        ? _parseTujuan(jenisPembayaran['tujuan'])
        : null;
    String? status = jenisPembayaran?['status'] ?? 'aktif';

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
                            jenisPembayaran == null ? Icons.add : Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            jenisPembayaran == null
                                ? 'Tambah Jenis Pembayaran'
                                : 'Edit Jenis Pembayaran',
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
                          controller: namaController,
                          label: 'Nama Pembayaran',
                          icon: Icons.payment,
                        ),
                        SizedBox(height: 12),
                        _buildDialogTextField(
                          controller: deskripsiController,
                          label: 'Deskripsi',
                          icon: Icons.description,
                          maxLines: 3,
                        ),
                        SizedBox(height: 12),
                        _buildDialogTextField(
                          controller: jumlahController,
                          label: 'Jumlah',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 12),
                        _buildDropdownField(
                          value: periodeController.text.isEmpty
                              ? 'bulanan'
                              : periodeController.text,
                          label: 'Periode',
                          icon: Icons.calendar_today,
                          items: ['bulanan', 'semester', 'tahunan'],
                          onChanged: (value) {
                            periodeController.text = value!;
                          },
                        ),

                        // Tujuan Pembayaran
                        SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.groups,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tujuan Pembayaran',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                _getTujuanDescription(tujuanData),
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      tujuanData != null &&
                                          tujuanData!.isNotEmpty
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  _showPemilihanTujuanModal(
                                    jenisPembayaran: jenisPembayaran,
                                    onSave: (tujuan) {
                                      setState(() {
                                        tujuanData = tujuan;
                                      });
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: Size(double.infinity, 36),
                                ),
                                child: Text(
                                  'Pilih Tujuan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 12),
                        _buildDropdownField(
                          value: status ?? 'aktif',
                          label: 'Status',
                          icon: Icons.check_circle,
                          items: ['aktif', 'non-aktif'],
                          onChanged: (value) {
                            status = value;
                          },
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
                            onPressed: () async {
                              if (namaController.text.isEmpty ||
                                  jumlahController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Nama dan jumlah harus diisi',
                                    ),
                                    backgroundColor: Colors.red.shade400,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              if (tujuanData == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Tujuan pembayaran harus dipilih',
                                    ),
                                    backgroundColor: Colors.red.shade400,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }

                              try {
                                final data = {
                                  'nama': namaController.text,
                                  'deskripsi': deskripsiController.text,
                                  'jumlah': double.parse(jumlahController.text),
                                  'periode': periodeController.text,
                                  'status': status,
                                  'tujuan': tujuanData,
                                };

                                if (jenisPembayaran == null) {
                                  await _apiService.post(
                                    '/jenis-pembayaran',
                                    data,
                                  );
                                } else {
                                  await _apiService.put(
                                    '/jenis-pembayaran/${jenisPembayaran['id']}',
                                    data,
                                  );
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                                _loadData();

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Data berhasil disimpan'),
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
                                        'Gagal menyimpan data: $error',
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
                              'Simpan',
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
    TextInputType keyboardType = TextInputType.text,
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
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required String label,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    // Pastikan value yang diberikan ada dalam items
    String selectedValue = items.contains(value) ? value : items.first;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonFormField<String>(
          value: selectedValue, // Gunakan value yang sudah divalidasi
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
            border: InputBorder.none,
          ),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item == 'aktif'
                    ? 'Aktif'
                    : item == 'non-aktif'
                    ? 'Non-Aktif'
                    : item == 'bulanan'
                    ? 'Bulanan'
                    : item == 'semester'
                    ? 'Semester'
                    : item == 'tahunan'
                    ? 'Tahunan'
                    : item == 'verified'
                    ? 'Terverifikasi'
                    : item == 'rejected'
                    ? 'Ditolak'
                    : item,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _deleteJenisPembayaran(
    Map<String, dynamic> jenisPembayaran,
  ) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Hapus Jenis Pembayaran',
        content:
            'Yakin ingin menghapus jenis pembayaran "${jenisPembayaran['nama']}"?',
        confirmText: 'Hapus',
        confirmColor: Colors.red,
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.delete('/jenis-pembayaran/${jenisPembayaran['id']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Jenis pembayaran berhasil dihapus'),
              backgroundColor: Colors.green.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _loadData();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus jenis pembayaran: $error'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showVerifikasiDialog(Map<String, dynamic> pembayaran) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final catatanController = TextEditingController();
          String status = 'verified';

          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                            Icons.verified,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Verifikasi Pembayaran',
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
                        // Info Pembayaran
                        _buildInfoItem(
                          'Siswa',
                          pembayaran['siswa_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          'Kelas',
                          pembayaran['kelas_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          'Jenis Pembayaran',
                          pembayaran['jenis_pembayaran_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          'Jumlah Bayar',
                          'Rp ${pembayaran['jumlah_bayar']}',
                        ),
                        _buildInfoItem(
                          'Metode Bayar',
                          pembayaran['metode_bayar'] ?? '-',
                        ),

                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 16),

                        if (pembayaran['bukti_bayar'] != null) ...[
                          SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _showBuktiPembayaran(pembayaran),
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.photo_library,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Bukti Pembayaran Tersedia',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade800,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Klik untuk melihat gambar',
                                          style: TextStyle(
                                            color: Colors.blue.shade600,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                        ],

                        // Status Verifikasi
                        _buildDropdownField(
                          value: status,
                          label: 'Status Verifikasi',
                          icon: Icons.check_circle,
                          items: ['verified', 'rejected'],
                          onChanged: (value) {
                            setDialogState(() {
                              status = value!;
                            });
                          },
                        ),

                        SizedBox(height: 12),

                        // Catatan
                        _buildDialogTextField(
                          controller: catatanController,
                          label: 'Catatan (Opsional)',
                          icon: Icons.note,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),

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
                            onPressed: () async {
                              try {
                                await _apiService.put(
                                  '/pembayaran/${pembayaran['id']}/verify',
                                  {
                                    'status': status,
                                    'admin_notes':
                                        catatanController.text.isEmpty
                                        ? null
                                        : catatanController.text,
                                  },
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  _loadData();

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Pembayaran berhasil ${status == 'verified' ? 'diverifikasi' : 'ditolak'}',
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
                                        'Gagal memverifikasi: $error',
                                      ),
                                      backgroundColor: Colors.red.shade400,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: status == 'verified'
                                  ? Colors.green
                                  : Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              status == 'verified' ? 'Terima' : 'Tolak',
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

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  List<dynamic> _getFilteredJenisPembayaran() {
    return _jenisPembayaranList.where((item) {
      final searchTerm = _searchController.text.toLowerCase();
      final nama = item['nama']?.toString().toLowerCase() ?? '';
      final deskripsi = item['deskripsi']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          nama.contains(searchTerm) ||
          deskripsi.contains(searchTerm);

      // Status filter
      final matchesStatus =
          _selectedStatusFilter == null ||
          (_selectedStatusFilter == 'aktif' && item['status'] == 'aktif') ||
          (_selectedStatusFilter == 'non_aktif' &&
              item['status'] == 'non-aktif');

      // Periode filter
      final matchesPeriode =
          _selectedPeriodeFilter == null ||
          (_selectedPeriodeFilter == 'bulanan' &&
              item['periode'] == 'bulanan') ||
          (_selectedPeriodeFilter == 'tahunan' && item['periode'] == 'tahunan');

      return matchesSearch && matchesStatus && matchesPeriode;
    }).toList();
  }

  Widget _buildJenisPembayaranCard(Map<String, dynamic> item, int index) {
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
            borderRadius: BorderRadius.circular(16),
            onTap: () {},
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['nama'] ?? 'No Name',
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
                                    'Rp ${item['jumlah']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
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
                                item['periode'] ?? '-',
                                style: TextStyle(
                                  color: _getPrimaryColor(),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 8),

                        if (item['deskripsi'] != null &&
                            item['deskripsi'].isNotEmpty)
                          Text(
                            item['deskripsi'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                        if (item['tujuan'] != null)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getPrimaryColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.groups,
                                  size: 10,
                                  color: _getPrimaryColor(),
                                ),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _getTujuanDescription(item['tujuan']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _getPrimaryColor(),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (item['status'] == 'aktif'
                                            ? Colors.green
                                            : Colors.red)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color:
                                      (item['status'] == 'aktif'
                                              ? Colors.green
                                              : Colors.red)
                                          .withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                item['status'] == 'aktif'
                                    ? 'Aktif'
                                    : 'Non-Aktif',
                                style: TextStyle(
                                  color: item['status'] == 'aktif'
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            Row(
                              children: [
                                _buildActionButton(
                                  icon: Icons.edit,
                                  label: 'Edit',
                                  color: _getPrimaryColor(),
                                  onPressed: () => _showAddEditJenisPembayaran(
                                    jenisPembayaran: item,
                                  ),
                                ),
                                SizedBox(width: 8),
                                _buildActionButton(
                                  icon: Icons.delete,
                                  label: 'Hapus',
                                  color: Colors.red,
                                  onPressed: () => _deleteJenisPembayaran(item),
                                ),
                              ],
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

  Widget _buildDashboardStats() {
    return Container(
      margin: EdgeInsets.all(16),
      child: Column(
        children: [
          // Statistik Utama
          Container(
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
                  icon: Icons.attach_money,
                  value: 'Rp ${_dashboardData['pendapatan_bulan_ini'] ?? '0'}',
                  label: 'Pendapatan Bulan Ini',
                  color: Colors.white,
                ),
                _buildStatItem(
                  icon: Icons.pending_actions,
                  value: '${_pembayaranPendingList.length}',
                  label: 'Menunggu Verifikasi',
                  color: Colors.white,
                ),
              ],
            ),
          ),
          SizedBox(height: 12),

          // Statistik Secondary
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt, color: Colors.orange, size: 20),
                      SizedBox(height: 4),
                      Text(
                        '${_tagihanList.where((t) => t['status'] == 'unpaid').length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        'Belum Bayar',
                        style: TextStyle(fontSize: 10, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.verified, color: Colors.green, size: 20),
                      SizedBox(height: 4),
                      Text(
                        '${_tagihanList.where((t) => t['status'] == 'verified').length}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Terverifikasi',
                        style: TextStyle(fontSize: 10, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
          textAlign: TextAlign.center,
        ),
      ],
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
          return LoadingScreen(message: 'Memuat data keuangan...');
        }

        if (_errorMessage.isNotEmpty) {
          return ErrorScreen(errorMessage: _errorMessage, onRetry: _loadData);
        }

        final filteredJenisPembayaran = _getFilteredJenisPembayaran();

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            appBar: AppBar(
              title: Text(
                'Manajemen Keuangan',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              backgroundColor: _getPrimaryColor(),
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: Colors.white),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(48.0),
                child: Container(
                  color: _getPrimaryColor(),
                  child: TabBar(
                    isScrollable: true, // INI YANG DITAMBAHKAN
                    indicatorColor: Colors.white,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                    onTap: (index) {
                      setState(() {
                        _currentTabIndex = index;
                      });
                    },
                    tabs: [
                      Tab(text: 'Dashboard'),
                      Tab(text: 'Jenis Pembayaran'),
                      Tab(
                        text: 'Verifikasi (${_pembayaranPendingList.length})',
                      ),
                      Tab(text: 'Laporan Kelas'),
                    ],
                  ),
                ),
              ),
              actions: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    switch (value) {
                      case 'refresh':
                        _loadData();
                        break;
                      case 'generate_tagihan':
                        _generateTagihan();
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'generate_tagihan',
                      child: Row(
                        children: [
                          Icon(Icons.autorenew, color: _getPrimaryColor()),
                          SizedBox(width: 8),
                          Text('Generate Tagihan'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: _getPrimaryColor()),
                          SizedBox(width: 8),
                          Text('Refresh'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: TabBarView(
              children: [
                // Tab Dashboard
                Column(
                  children: [
                    _buildDashboardStats(),
                    Expanded(
                      child: ListView(
                        children: [
                          if (_pembayaranPendingList.isNotEmpty)
                            _buildPendingSection(),
                        ],
                      ),
                    ),
                  ],
                ),

                // Tab Jenis Pembayaran
                Column(
                  children: [
                    // Search Bar and Filter
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'Cari jenis pembayaran...',
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
                                  ? _getPrimaryColor()
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _hasActiveFilter
                                    ? _getPrimaryColor()
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Stack(
                              children: [
                                IconButton(
                                  onPressed: _showFilterSheet,
                                  icon: Icon(
                                    Icons.tune,
                                    color: _hasActiveFilter
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                  tooltip: 'Filter',
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
                    ),

                    // Filter Chips
                    if (_hasActiveFilter) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 32,
                          child: Row(
                            children: [
                              Expanded(
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    ..._buildFilterChips(
                                      context.read<LanguageProvider>(),
                                    ).map((filter) {
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
                                            color: _getPrimaryColor()
                                                .withOpacity(0.3),
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
                                          labelPadding: EdgeInsets.only(
                                            left: 4,
                                          ),
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
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'Hapus Semua',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                    ],

                    if (filteredJenisPembayaran.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              '${filteredJenisPembayaran.length} jenis pembayaran ditemukan',
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
                      child: filteredJenisPembayaran.isEmpty
                          ? EmptyState(
                              title: 'Tidak ada jenis pembayaran',
                              subtitle:
                                  _searchController.text.isEmpty &&
                                      !_hasActiveFilter
                                  ? 'Tap + untuk menambah jenis pembayaran'
                                  : 'Tidak ditemukan hasil pencarian',
                              icon: Icons.payment,
                            )
                          : ListView.builder(
                              itemCount: filteredJenisPembayaran.length,
                              itemBuilder: (context, index) {
                                return _buildJenisPembayaranCard(
                                  filteredJenisPembayaran[index],
                                  index,
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // Tab Verifikasi
                _pembayaranPendingList.isEmpty
                    ? EmptyState(
                        title: 'Tidak ada pembayaran menunggu verifikasi',
                        subtitle: 'Semua pembayaran telah diverifikasi',
                        icon: Icons.verified_user,
                      )
                    : ListView.builder(
                        itemCount: _pembayaranPendingList.length,
                        itemBuilder: (context, index) {
                          return _buildPembayaranPendingCard(
                            _pembayaranPendingList[index],
                            index,
                          );
                        },
                      ),
                _buildLaporanKelasTab(),
              ],
            ),
            floatingActionButton: _getFloatingActionButton(),
          ),
        );
      },
    );
  }

  Widget _buildPendingSection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pending_actions, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'Pembayaran Menunggu Verifikasi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Ada ${_pembayaranPendingList.length} pembayaran yang perlu diverifikasi',
            style: TextStyle(color: Colors.orange.shade600, fontSize: 12),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              DefaultTabController.of(context)?.animateTo(2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Verifikasi Sekarang',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPembayaranPendingCard(
    Map<String, dynamic> pembayaran,
    int index,
  ) {
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
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showVerifikasiDialog(pembayaran),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pembayaran['siswa_nama'] ?? '-',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    'Kelas ${pembayaran['kelas_nama'] ?? '-'}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
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
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                'Menunggu',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 8),

                        Row(
                          children: [
                            Icon(Icons.payment, size: 12, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              pembayaran['jenis_pembayaran_nama'] ?? '-',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 4),

                        Row(
                          children: [
                            Icon(
                              Icons.attach_money,
                              size: 12,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Rp ${pembayaran['jumlah_bayar']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 4),

                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 4),
                            Text(
                              pembayaran['tanggal_bayar']?.split('T')[0] ?? '-',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),

                        // TAMPILKAN BUKTI PEMBAYARAN JIKA ADA
                        if (pembayaran['bukti_bayar'] != null) ...[
                          SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _showBuktiPembayaran(pembayaran),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.photo,
                                    size: 14,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Lihat Bukti Pembayaran',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.visibility,
                                    size: 12,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Tombol Lihat Bukti
                            if (pembayaran['bukti_bayar'] != null)
                              OutlinedButton(
                                onPressed: () =>
                                    _showBuktiPembayaran(pembayaran),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  side: BorderSide(color: Colors.blue),
                                ),
                                child: Text(
                                  'Lihat Bukti',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                            Spacer(),

                            // Tombol Verifikasi
                            ElevatedButton(
                              onPressed: () =>
                                  _showVerifikasiDialog(pembayaran),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getPrimaryColor(),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: Text(
                                'Verifikasi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
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
      ),
    );
  }

  Widget? _getFloatingActionButton() {
    if (_currentTabIndex == 1) {
      // Tab Jenis Pembayaran
      return FloatingActionButton(
        onPressed: () => _showAddEditJenisPembayaran(),
        backgroundColor: _getPrimaryColor(),
        child: Icon(Icons.add, color: Colors.white),
      );
    }

    return null;
  }

  Future<void> _generateTagihan() async {
    try {
      await _apiService.post('/generate-tagihan', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generate tagihan berhasil'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _loadData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal generate tagihan: $error'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
