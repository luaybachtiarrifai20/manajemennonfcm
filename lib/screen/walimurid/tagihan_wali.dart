// tagihan_wali.dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/enhanced_search_bar.dart';
import 'package:manajemensekolah/components/error_screen.dart';
import 'package:manajemensekolah/components/loading_screen.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class TagihanWaliScreen extends StatefulWidget {
  const TagihanWaliScreen({super.key});

  @override
  TagihanWaliScreenState createState() => TagihanWaliScreenState();
}

class TagihanWaliScreenState extends State<TagihanWaliScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _tagihanList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Search dan filter
  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterOptions = [
    'Semua',
    'Belum Bayar',
    'Pending',
    'Lunas',
  ];
  String _selectedFilter = 'Semua';

  // Animations
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  File? selectedFile;

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
        _errorMessage = '';
      });

      await _loadTagihan();

      setState(() {
        _isLoading = false;
      });

      _animationController.forward();
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load tagihan data';
      });
    }
  }

  Future<void> _loadTagihan() async {
    try {
      final response = await _apiService.get('/tagihan/wali');
      setState(() {
        _tagihanList = response is List ? response : [];
      });
    } catch (error) {
      print('Error loading tagihan: $error');
    }
  }

  // Dalam tagihan_wali.dart - Perbaiki _pickImage
  Future<void> _pickImage(StateSetter setDialogState) async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show option to choose from gallery or camera
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pilih Sumber'),
          content: Text('Pilih sumber gambar'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: Text('Galeri'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: Text('Kamera'),
            ),
          ],
        ),
      );

      if (source != null) {
        final XFile? file = await picker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (file != null && context.mounted) {
          // Validasi yang lebih ketat
          final allowedExtensions = ['.jpg', '.jpeg', '.png'];
          final filePath = file.path.toLowerCase();
          final fileExtension = filePath.split('.').last;

          bool isValidFile = allowedExtensions.any(
            (ext) => filePath.endsWith(ext),
          );

          if (!isValidFile) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Format file tidak didukung. Hanya JPG, JPEG, dan PNG yang diizinkan.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          setDialogState(() {
            selectedFile = File(file.path);
          });

          print('File selected: ${file.path}');
          print('File extension: $fileExtension');
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Tambahkan method ini di tagihan_wali.dart
  Future<void> _pickPDF(StateSetter setDialogState) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        setDialogState(() {
          selectedFile = file;
        });

        print('PDF selected: ${file.path}');
      }
    } catch (e) {
      print('Error picking PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickFile(StateSetter setDialogState) async {
    try {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pilih Jenis File'),
          content: Text('Pilih jenis bukti pembayaran'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'image'),
              child: Text('Gambar (Kamera/Galeri)'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'pdf'),
              child: Text('Dokumen PDF'),
            ),
          ],
        ),
      );

      if (action == 'image') {
        await _pickImage(setDialogState);
      } else if (action == 'pdf') {
        await _pickPDF(setDialogState);
      }
    } catch (e) {
      print('Error picking file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<dynamic> _getFilteredTagihan() {
    return _tagihanList.where((item) {
      final searchTerm = _searchController.text.toLowerCase();
      final nama =
          item['jenis_pembayaran_nama']?.toString().toLowerCase() ?? '';
      final deskripsi =
          item['jenis_pembayaran_deskripsi']?.toString().toLowerCase() ?? '';

      final matchesSearch =
          searchTerm.isEmpty ||
          nama.contains(searchTerm) ||
          deskripsi.contains(searchTerm);

      final matchesFilter =
          _selectedFilter == 'Semua' ||
          (_selectedFilter == 'Belum Bayar' && item['status'] == 'unpaid') ||
          (_selectedFilter == 'Pending' && item['status'] == 'pending') ||
          (_selectedFilter == 'Lunas' &&
              (item['status'] == 'verified' ||
                  item['pembayaran_status'] == 'verified'));

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(Map<String, dynamic> tagihan) {
    if (tagihan['pembayaran_status'] == 'verified') {
      return 'Lunas';
    } else if (tagihan['pembayaran_status'] == 'pending') {
      return 'Menunggu Verifikasi';
    } else if (tagihan['pembayaran_status'] == 'rejected') {
      return 'Ditolak';
    } else {
      return 'Belum Bayar';
    }
  }

  String _getFileTypeText(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'Gambar JPEG';
      case 'png':
        return 'Gambar PNG';
      case 'pdf':
        return 'Dokumen PDF';
      default:
        return 'File $extension';
    }
  }

  void _showUploadBuktiDialog(Map<String, dynamic> tagihan) {
    final metodeBayarController = TextEditingController();
    final jumlahBayarController = TextEditingController(
      text: tagihan['jumlah']?.toString(),
    );
    final tanggalBayarController = TextEditingController(
      text: DateTime.now().toString().split(' ')[0],
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
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
                            Icons.upload,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Upload Bukti Pembayaran',
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
                        // Info Tagihan
                        _buildInfoItem(
                          'Jenis Pembayaran',
                          tagihan['jenis_pembayaran_nama'] ?? '-',
                        ),
                        _buildInfoItem(
                          'Jumlah Tagihan',
                          'Rp ${tagihan['jumlah'] ?? '-'}',
                        ),
                        _buildInfoItem('Siswa', tagihan['siswa_nama'] ?? '-'),
                        _buildInfoItem('Kelas', tagihan['kelas_nama'] ?? '-'),

                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 16),

                        // Form Pembayaran
                        _buildDialogTextField(
                          controller: metodeBayarController,
                          label: 'Metode Pembayaran',
                          icon: Icons.payment,
                          hint: 'Transfer Bank, Tunai, dll.',
                        ),
                        SizedBox(height: 12),
                        _buildDialogTextField(
                          controller: jumlahBayarController,
                          label: 'Jumlah Bayar',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                        ),
                        SizedBox(height: 12),
                        _buildDialogTextField(
                          controller: tanggalBayarController,
                          label: 'Tanggal Bayar',
                          icon: Icons.calendar_today,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (date != null) {
                              tanggalBayarController.text = date
                                  .toString()
                                  .split(' ')[0];
                            }
                          },
                        ),
                        SizedBox(height: 12),

                        // Upload File
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedFile != null
                                  ? Colors.green
                                  : Colors.grey.shade200,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.upload_file,
                                color: selectedFile != null
                                    ? Colors.green
                                    : Colors.grey,
                                size: 40,
                              ),
                              SizedBox(height: 8),
                              Text(
                                selectedFile != null
                                    ? 'File terpilih: ${selectedFile!.path.split('/').last}'
                                    : 'Pilih bukti pembayaran',
                                style: TextStyle(
                                  color: selectedFile != null
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                              SizedBox(height: 4),
                              if (selectedFile != null)
                                Text(
                                  _getFileTypeText(selectedFile!.path),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => _pickFile(setDialogState),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getPrimaryColor(),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Pilih File',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Format: JPG, JPEG, PNG, PDF',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
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
                            onPressed:
                                selectedFile == null ||
                                    metodeBayarController.text.isEmpty ||
                                    jumlahBayarController.text.isEmpty ||
                                    tanggalBayarController.text.isEmpty
                                ? null
                                : () async {
                                    try {
                                      // Upload file dan data
                                      await _uploadPembayaran(
                                        tagihanId: tagihan['id'],
                                        metodeBayar: metodeBayarController.text,
                                        jumlahBayar: double.parse(
                                          jumlahBayarController.text,
                                        ),
                                        tanggalBayar:
                                            tanggalBayarController.text,
                                        file: selectedFile!,
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        _loadData();

                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Bukti pembayaran berhasil diupload',
                                            ),
                                            backgroundColor:
                                                Colors.green.shade400,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (error) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Gagal upload: $error',
                                            ),
                                            backgroundColor:
                                                Colors.red.shade400,
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
                              'Upload',
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

  Future<void> _uploadPembayaran({
    required String tagihanId,
    required String metodeBayar,
    required double jumlahBayar,
    required String tanggalBayar,
    required File file,
  }) async {
    try {
      // Validasi file type sebelum upload
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.pdf'];
      final filePath = file.path.toLowerCase();
      final fileExtension = filePath.split('.').last;

      if (!allowedExtensions.any((ext) => filePath.endsWith(ext))) {
        throw Exception(
          'Format file tidak didukung. Gunakan JPG, JPEG, PNG, atau PDF.',
        );
      }

      print('=== UPLOAD DEBUG INFO ===');
      print('File path: ${file.path}');
      print('File extension: $fileExtension');
      print('File size: ${await file.length()} bytes');
      print('Tagihan ID: $tagihanId');
      print('Metode Bayar: $metodeBayar');
      print('Jumlah Bayar: $jumlahBayar');
      print('Tanggal Bayar: $tanggalBayar');
      print('========================');

      // Upload file menggunakan multipart
      await _apiService.uploadFile(
        '/pembayaran/upload',
        file,
        data: {
          'tagihan_id': tagihanId,
          'metode_bayar': metodeBayar,
          'jumlah_bayar': jumlahBayar.toString(),
          'tanggal_bayar': tanggalBayar,
        },
      );
    } catch (error) {
      print('Error upload pembayaran: $error');
      rethrow;
    }
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onTap: onTap,
        readOnly: onTap != null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
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

  Widget _buildTagihanCard(Map<String, dynamic> tagihan, int index) {
    final status = _getStatusText(tagihan);
    final statusColor = _getStatusColor(
      tagihan['pembayaran_status'] ?? tagihan['status'],
    );

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

                  // Status badge positioned
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Content
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Judul tagihan
                        Padding(
                          padding: EdgeInsets.only(right: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tagihan['jenis_pembayaran_nama'] ?? 'No Name',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Rp ${tagihan['jumlah']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                  SizedBox(height: 8),

                  if (tagihan['jenis_pembayaran_deskripsi'] != null &&
                      tagihan['jenis_pembayaran_deskripsi'].isNotEmpty)
                    Text(
                      tagihan['jenis_pembayaran_deskripsi'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.person, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        tagihan['siswa_nama'] ?? '-',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.school, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        tagihan['kelas_nama'] ?? '-',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),

                  SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        'Jatuh Tempo: ${tagihan['jatuh_tempo']?.split('T')[0] ?? '-'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),

                  if (tagihan['pembayaran_status'] == 'rejected' &&
                      tagihan['admin_notes'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, size: 12, color: Colors.red),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Catatan: ${tagihan['admin_notes']}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  SizedBox(height: 12),

                  if (tagihan['status'] == 'unpaid' ||
                      tagihan['pembayaran_status'] == 'rejected')
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => _showUploadBuktiDialog(tagihan),
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
                          'Bayar Sekarang',
                          style: TextStyle(color: Colors.white, fontSize: 12),
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

  Color _getPrimaryColor() {
    return Color(0xFF9333EA); // Warna purple untuk wali murid
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withOpacity(0.7)],
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
                      'Tagihan Saya',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kelola pembayaran tagihan',
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
                onPressed: _loadData,
              ),
            ],
          ),
          SizedBox(height: 12),
          EnhancedSearchBar(
            controller: _searchController,
            hintText: 'Cari tagihan...',
            onChanged: (value) {
              setState(() {});
            },
            filterOptions: _filterOptions,
            selectedFilter: _selectedFilter,
            onFilterChanged: (filter) {
              setState(() {
                _selectedFilter = filter;
              });
            },
            showFilter: true,
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
          return LoadingScreen(message: 'Memuat data tagihan...');
        }

        if (_errorMessage.isNotEmpty) {
          return ErrorScreen(errorMessage: _errorMessage, onRetry: _loadData);
        }

        final filteredTagihan = _getFilteredTagihan();

        return Scaffold(
          backgroundColor: Color(0xFFF8F9FA),
          body: Column(
            children: [
              _buildHeader(languageProvider),
              if (filteredTagihan.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${filteredTagihan.length} tagihan ditemukan',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              SizedBox(height: 4),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: filteredTagihan.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: 100),
                            EmptyState(
                              title: 'Tidak ada tagihan',
                              subtitle:
                                  _searchController.text.isEmpty &&
                                      _selectedFilter == 'Semua'
                                  ? 'Semua tagihan telah lunas'
                                  : 'Tidak ditemukan hasil pencarian',
                              icon: Icons.receipt,
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: filteredTagihan.length,
                          itemBuilder: (context, index) {
                            return _buildTagihanCard(
                              filteredTagihan[index],
                              index,
                            );
                          },
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
