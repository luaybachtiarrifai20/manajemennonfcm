import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class RppScreen extends StatefulWidget {
  final String guruId;
  final String guruName;

  const RppScreen({super.key, required this.guruId, required this.guruName});

  @override
  RppScreenState createState() => RppScreenState();
}

class RppScreenState extends State<RppScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _rppList = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  String? _selectedStatusFilter;
  bool _hasActiveFilter = false;

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

    _loadRpp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter = _selectedStatusFilter != null;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _hasActiveFilter = false;
    });
  }

  String _buildFilterSummary(LanguageProvider languageProvider) {
    List<String> filters = [];

    if (_selectedStatusFilter != null) {
      filters.add(
        '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $_selectedStatusFilter',
      );
    }

    return filters.join(' • ');
  }

  void _showFilterSheet() {
    final languageProvider = context.read<LanguageProvider>();

    // Temporary state for bottom sheet
    String? tempSelectedStatus = _selectedStatusFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.4,
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

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Filter
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
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = null;
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Menunggu',
                              value: 'Menunggu',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Menunggu';
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Disetujui',
                              value: 'Disetujui',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Disetujui';
                                });
                              },
                            ),
                            _buildStatusChip(
                              label: 'Ditolak',
                              value: 'Ditolak',
                              selectedValue: tempSelectedStatus,
                              onSelected: () {
                                setModalState(() {
                                  tempSelectedStatus = 'Ditolak';
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
                              _selectedStatusFilter = tempSelectedStatus;
                            });
                            _checkActiveFilter();
                            Navigator.pop(context);
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

  Future<void> _loadRpp() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final rppData = await ApiService.getRPP(guruId: widget.guruId);

      setState(() {
        _rppList = rppData;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _tambahRpp() {
    showDialog(
      context: context,
      builder: (context) =>
          RppFormDialog(guruId: widget.guruId, onSaved: _loadRpp),
    );
  }

  void _editRpp(Map<String, dynamic> rpp) {
    showDialog(
      context: context,
      builder: (context) =>
          RppFormDialog(guruId: widget.guruId, onSaved: _loadRpp, rppData: rpp),
    );
  }

  Future<void> _deleteRpp(Map<String, dynamic> rpp) async {
    final languageProvider = context.read<LanguageProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.confirmDelete.tr),
        content: Text(
          languageProvider.getTranslatedText({
            'en': 'Are you sure you want to delete RPP "${rpp['judul']}"?',
            'id': 'Apakah Anda yakin ingin menghapus RPP "${rpp['judul']}"?',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.cancel.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              AppLocalizations.delete.tr,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteRPP(rpp['id']);
        _loadRpp();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.getTranslatedText({
                  'en': 'RPP deleted successfully',
                  'id': 'RPP berhasil dihapus',
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
                languageProvider.getTranslatedText({
                  'en': 'Failed to delete RPP: $e',
                  'id': 'Gagal menghapus RPP: $e',
                }),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _lihatDetailRpp(Map<String, dynamic> rpp) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RppDetailPage(rpp: rpp)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Disetujui':
        return Colors.green;
      case 'Menunggu':
        return Colors.orange;
      case 'Ditolak':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Disetujui':
        return Icons.check_circle;
      case 'Menunggu':
        return Icons.access_time;
      case 'Ditolak':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor],
    );
  }

  Widget _buildRppCard(Map<String, dynamic> rpp, int index) {
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
            onTap: () => _lihatDetailRpp(rpp),
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
                        // Header dengan judul dan status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rpp['judul'] ?? 'No Title',
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
                                    '${rpp['mata_pelajaran_nama'] ?? 'No Subject'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
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
                                color: _getStatusColor(
                                  rpp['status'],
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _getStatusColor(
                                    rpp['status'],
                                  ).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                rpp['status'] == 'Menunggu'
                                    ? 'Menunggu'
                                    : rpp['status'] == 'Disetujui'
                                    ? 'Disetujui'
                                    : 'Ditolak',
                                style: TextStyle(
                                  color: _getStatusColor(rpp['status']),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12),

                        // Informasi kelas
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
                                    'Kelas',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    rpp['kelas_nama'] ?? 'No Class',
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
                              icon: Icons.visibility,
                              label: 'Detail',
                              color: _getPrimaryColor(),
                              onPressed: () => _lihatDetailRpp(rpp),
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.edit,
                              label: 'Edit',
                              color: _getPrimaryColor(),
                              onPressed: () => _editRpp(rpp),
                            ),
                            SizedBox(width: 8),
                            _buildActionButton(
                              icon: Icons.delete,
                              label: 'Hapus',
                              color: Colors.red,
                              onPressed: () => _deleteRpp(rpp),
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

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            AppLocalizations.noRppCreated.tr,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.clickPlusToCreate.tr,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${AppLocalizations.error.tr}: $_errorMessage'),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadRpp,
            child: Text(AppLocalizations.retry.tr),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getPrimaryColor(),
              foregroundColor: Colors.white,
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
        if (_isLoading) {
          return Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_getPrimaryColor()),
              ),
            ),
          );
        }

        final filteredRpp = _rppList.where((rpp) {
          final searchTerm = _searchController.text.toLowerCase();
          final matchesSearch =
              searchTerm.isEmpty ||
              (rpp['judul']?.toLowerCase().contains(searchTerm) ?? false) ||
              (rpp['mata_pelajaran_nama']?.toLowerCase().contains(searchTerm) ??
                  false) ||
              (rpp['kelas_nama']?.toLowerCase().contains(searchTerm) ?? false);

          // Status filter
          final matchesStatusFilter =
              _selectedStatusFilter == null ||
              rpp['status'] == _selectedStatusFilter;

          return matchesSearch && matchesStatusFilter;
        }).toList();

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
                                AppLocalizations.rppList.tr,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                AppLocalizations.viewAndManageRpp.tr,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: Colors.white),
                          onPressed: _loadRpp,
                          tooltip: AppLocalizations.refresh.tr,
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
                                  'en': 'Search RPP...',
                                  'id': 'Cari RPP...',
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
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _buildFilterSummary(languageProvider),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: _clearAllFilters,
                                          child: Icon(
                                            Icons.close,
                                            size: 16,
                                            color: Colors.white,
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
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _errorMessage != null
                    ? _buildErrorState()
                    : filteredRpp.isEmpty
                    ? _buildEmptyState(languageProvider)
                    : RefreshIndicator(
                        onRefresh: _loadRpp,
                        child: ListView.builder(
                          padding: EdgeInsets.only(
                            top: 16,
                            bottom: 16,
                            left: 5,
                            right: 5,
                          ),
                          itemCount: filteredRpp.length,
                          itemBuilder: (context, index) {
                            final rpp = filteredRpp[index];
                            return _buildRppCard(rpp, index);
                          },
                        ),
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _tambahRpp,
            backgroundColor: _getPrimaryColor(),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}

// RppFormDialog tetap sama seperti sebelumnya
class RppFormDialog extends StatefulWidget {
  final String guruId;
  final VoidCallback onSaved;
  final Map<String, dynamic>? rppData;

  const RppFormDialog({
    super.key,
    required this.guruId,
    required this.onSaved,
    this.rppData,
  });

  @override
  State<RppFormDialog> createState() => _RppFormDialogState();
}

class _RppFormDialogState extends State<RppFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _tahunAjaranController = TextEditingController();

  String? _selectedMataPelajaranId;
  String? _selectedClassId;
  String? _selectedSemester = 'Ganjil';
  String? _selectedFileName;
  File? _selectedFile;
  bool _isUploading = false;

  List<dynamic> _mataPelajaranList = [];
  List<dynamic> _kelasList = [];

  @override
  void initState() {
    super.initState();
    _loadMataPelajaranByGuru();

    // Jika mode edit, isi field dengan data RPP
    if (widget.rppData != null) {
      _judulController.text = widget.rppData!['judul'] ?? '';
      _tahunAjaranController.text = widget.rppData!['tahun_ajaran'] ?? '';
      _selectedMataPelajaranId = widget.rppData!['mata_pelajaran_id'];
      _selectedClassId = widget.rppData!['kelas_id'];
      _selectedSemester = widget.rppData!['semester'] ?? 'Ganjil';
      _selectedFileName = widget.rppData!['file_path'];
    } else {
      // Mode tambah baru: set default tahun ajaran
      _tahunAjaranController.text = DateTime.now().year.toString();
    }
  }

  Future<void> _loadMataPelajaranByGuru() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/guru/${widget.guruId}/mata-pelajaran',
      );
      setState(() {
        _mataPelajaranList = result is List ? result : [];
      });
    } catch (e) {
      print('Error loading mata pelajaran by guru: $e');
      _loadAllMataPelajaran();
    }
  }

  Future<void> _loadAllMataPelajaran() async {
    try {
      final apiService = ApiService();
      final result = await apiService.get('/mata-pelajaran');
      setState(() {
        _mataPelajaranList = result is List ? result : [];
      });
    } catch (e) {
      print('Error loading all mata pelajaran: $e');
    }
  }

  Future<void> _loadKelasByMataPelajaran(String mataPelajaranId) async {
    try {
      final apiService = ApiService();
      final result = await apiService.get(
        '/kelas-by-mata-pelajaran?mata_pelajaran_id=$mataPelajaranId',
      );
      setState(() {
        _kelasList = result is List ? result : [];
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading kelas by mata pelajaran: $e');
        setState(() {
          _kelasList = [];
        });
      }
    }
  }

  void _showFilePickerDialog() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        PlatformFile file = result.files.first;

        // Pastikan file benar-benar ada
        File selectedFile = File(file.path!);
        bool fileExists = await selectedFile.exists();

        print('File picked: ${file.name}');
        print('File path: ${file.path}');
        print('File exists: $fileExists');
        print('File size: ${file.size} bytes');

        if (fileExists) {
          setState(() {
            _selectedFileName = file.name;
            _selectedFile = selectedFile;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File dipilih: ${file.name} (${file.size} bytes)'),
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File tidak ditemukan di path tersebut'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('Pemilihan file dibatalkan atau path null');
      }
    } catch (e) {
      print('Error memilih file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error memilih file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setSelectedFile(String fileName) {
    setState(() {
      _selectedFileName = fileName;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      String? filePath;

      // Debug: Cek apakah file ada
      print('File selected: $_selectedFile');
      print('File name: $_selectedFileName');

      if (_selectedFile != null) {
        try {
          print('Starting file upload...');
          final uploadResult = await ApiService.uploadFileRPP(_selectedFile!);
          print('Upload result: $uploadResult');

          filePath = uploadResult['file_path'];
          print('File uploaded successfully: $filePath');
        } catch (uploadError) {
          print('Error during file upload: $uploadError');
          // Tetap lanjut tanpa file jika upload gagal
          filePath = null;
        }
      } else {
        print('No file selected for upload');
      }

      // Debug data yang akan dikirim
      print('Submitting RPP data:');
      print('- Guru ID: ${widget.guruId}');
      print('- Mata Pelajaran ID: $_selectedMataPelajaranId');
      print('- Kelas ID: $_selectedClassId');
      print('- Judul: ${_judulController.text}');
      print('- File Path: $filePath');

      final rppData = {
        'mata_pelajaran_id': _selectedMataPelajaranId,
        'kelas_id': _selectedClassId,
        'judul': _judulController.text,
        'semester': _selectedSemester,
        'tahun_ajaran': _tahunAjaranController.text,
        'file_path': filePath ?? _selectedFileName,
      };

      // Submit data RPP (mode edit atau tambah)
      if (widget.rppData != null) {
        // Mode edit
        await ApiService.updateRPP(widget.rppData!['id'], rppData);
        print('RPP updated successfully');
      } else {
        // Mode tambah baru
        rppData['guru_id'] = widget.guruId;
        await ApiService.tambahRPP(rppData);
        print('RPP created successfully');
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();

      final languageProvider = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.rppData != null
                ? languageProvider.getTranslatedText({
                    'en': 'RPP updated successfully',
                    'id': 'RPP berhasil diupdate',
                  })
                : AppLocalizations.rppCreatedSuccess.tr,
          ),
        ),
      );
    } catch (e) {
      print('Error creating RPP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.error.tr}: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    return AlertDialog(
      title: Text(
        widget.rppData != null
            ? languageProvider.getTranslatedText({
                'en': 'Edit RPP',
                'id': 'Edit RPP',
              })
            : AppLocalizations.createRpp.tr,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _judulController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.title.tr} *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.titleRequired.tr;
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              DropdownButtonFormField(
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.subject.tr} *',
                ),
                items: _mataPelajaranList.map((mp) {
                  return DropdownMenuItem(
                    value: mp['id'],
                    child: Text(mp['nama']),
                  );
                }).toList(),
                value: _selectedMataPelajaranId,
                onChanged: (value) {
                  setState(() {
                    _selectedMataPelajaranId = value.toString();
                    _selectedClassId = null;
                  });
                  _loadKelasByMataPelajaran(value.toString());
                },
                validator: (value) {
                  if (value == null) {
                    return AppLocalizations.subjectRequired.tr;
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              DropdownButtonFormField(
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.class_.tr} *',
                ),
                items: _kelasList.map((kelas) {
                  return DropdownMenuItem(
                    value: kelas['id'],
                    child: Text(kelas['nama']),
                  );
                }).toList(),
                value: _selectedClassId,
                onChanged: (value) {
                  setState(() {
                    _selectedClassId = value.toString();
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return AppLocalizations.classNameRequired.tr;
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              DropdownButtonFormField(
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.semester.tr} *',
                ),
                items: ['Ganjil', 'Genap'].map((semester) {
                  return DropdownMenuItem(
                    value: semester,
                    child: Text(semester),
                  );
                }).toList(),
                value: _selectedSemester,
                onChanged: (value) {
                  setState(() {
                    _selectedSemester = value;
                  });
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _tahunAjaranController,
                decoration: InputDecoration(
                  labelText: '${AppLocalizations.academicYear.tr} *',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.academicYearRequired.tr;
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File RPP',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    if (_selectedFileName != null)
                      Text(
                        _selectedFileName!,
                        style: TextStyle(color: Colors.green),
                      ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _showFilePickerDialog,
                      child: Text('Pilih File'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.cancel.tr),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _submitForm,
          child: _isUploading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(),
                )
              : Text(AppLocalizations.save.tr),
        ),
      ],
    );
  }
}

// RppDetailPage tetap sama seperti sebelumnya
class RppDetailPage extends StatelessWidget {
  final Map<String, dynamic> rpp;

  const RppDetailPage({super.key, required this.rpp});

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.rppDetails.tr)),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rpp['judul'] ?? 'No Title',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Mata Pelajaran: ${rpp['mata_pelajaran_nama']}'),
            Text('Kelas: ${rpp['kelas_nama']}'),
            Text('Semester: ${rpp['semester']}'),
            Text('Tahun Ajaran: ${rpp['tahun_ajaran']}'),
            Text('Status: ${rpp['status']}'),
            if (rpp['file_path'] != null) ...[
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // TODO: Implement file download
                },
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Download File',
                    'id': 'Unduh File',
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
