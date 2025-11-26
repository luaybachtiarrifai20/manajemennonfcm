import 'package:flutter/material.dart';
import 'package:manajemensekolah/screen/guru/rpp_detail_screen.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/rpp_service.dart';

class RPPGeneratePage extends StatefulWidget {
  final Map<String, dynamic> guru;
  final String selectedMataPelajaran;
  final String mataPelajaranName;
  final List<Map<String, dynamic>> checkedBab;
  final List<Map<String, dynamic>> checkedSubBab;

  const RPPGeneratePage({
    super.key,
    required this.guru,
    required this.selectedMataPelajaran,
    required this.mataPelajaranName,
    required this.checkedBab,
    required this.checkedSubBab,
  });

  @override
  RPPGeneratePageState createState() => RPPGeneratePageState();
}

class RPPGeneratePageState extends State<RPPGeneratePage> {
  final TextEditingController _judulController = TextEditingController();
  final TextEditingController _tujuanController = TextEditingController();
  final TextEditingController _alatMediaController = TextEditingController();

  bool _isGenerating = false;
  String _statusMessage = '';
  double _progress = 0.0;

  // State untuk checkbox
  bool _titleChecked = true;
  bool _objectivesChecked = true;
  bool _mediaChecked = true;

  @override
  void initState() {
    super.initState();
    _generateAutoTitle();
  }

  void _generateAutoTitle() {
    final String autoTitle = _getLessonTitleFromSelection();
    _judulController.text = autoTitle;
  }

  String _getLessonTitleFromSelection() {
    List<String> titleParts = [];

    // Prioritaskan sub bab yang dicentang
    if (widget.checkedSubBab.isNotEmpty) {
      for (var subBab in widget.checkedSubBab) {
        final judul = subBab['judul_sub_bab'] ?? '';
        if (judul.isNotEmpty) {
          titleParts.add(judul);
        }
      }
    }
    
    // Jika tidak ada sub bab, ambil dari bab yang dicentang
    if (titleParts.isEmpty && widget.checkedBab.isNotEmpty) {
      for (var bab in widget.checkedBab) {
        final judul = bab['judul_bab'] ?? '';
        if (judul.isNotEmpty) {
          titleParts.add(judul);
        }
      }
    }

    // Format title dengan pemisah koma
    String formattedTitle = titleParts.join(', ');

    // Tambahkan prefix RPP jika belum ada dan title tidak kosong
    if (formattedTitle.isNotEmpty && !formattedTitle.toLowerCase().contains('rpp')) {
      formattedTitle = 'RPP $formattedTitle';
    }

    // Jika masih kosong, gunakan nama mata pelajaran
    if (formattedTitle.isEmpty) {
      formattedTitle = 'RPP ${widget.mataPelajaranName}';
    }

    return formattedTitle;
  }

  void _updateTitleFromSelection() {
    if (_titleChecked) {
      final newTitle = _getLessonTitleFromSelection();
      setState(() {
        _judulController.text = newTitle;
      });
    }
  }

  Future<void> _generateRPP() async {
    if (_judulController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Judul RPP harus diisi')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _statusMessage = 'Mempersiapkan data...';
    });

    try {
      // Kumpulkan semua konten materi dari bab dan sub bab yang dipilih
      List<Map<String, dynamic>> allKontenMateri = [];

      // Ambil konten dari sub bab yang dicentang
      for (var subBab in widget.checkedSubBab) {
        setState(() {
          _statusMessage = 'Mengambil konten sub bab...';
        });

        final konten = await ApiSubjectService.getContentMateri(
          subBabId: subBab['id'],
        );

        for (var item in konten) {
          allKontenMateri.add({
            'type': 'sub_bab',
            'sub_bab': subBab['judul_sub_bab'],
            'judul': item['judul_konten'],
            'isi': item['isi_konten'],
          });
        }
        _progress += 0.2 / (widget.checkedSubBab.length + widget.checkedBab.length);
      }

      // Ambil konten dari bab yang dicentang (semua sub bab dalam bab)
      for (var bab in widget.checkedBab) {
        setState(() {
          _statusMessage = 'Mengambil konten bab...';
        });

        final subBabs = await ApiSubjectService.getSubBabMateri(babId: bab['id']);
        
        for (var subBab in subBabs) {
          final konten = await ApiSubjectService.getContentMateri(
            subBabId: subBab['id'],
          );

          for (var item in konten) {
            allKontenMateri.add({
              'type': 'bab',
              'bab': bab['judul_bab'],
              'sub_bab': subBab['judul_sub_bab'],
              'judul': item['judul_konten'],
              'isi': item['isi_konten'],
            });
          }
        }
        _progress += 0.3 / (widget.checkedSubBab.length + widget.checkedBab.length);
      }

      setState(() {
        _statusMessage = 'Generate RPP dengan AI...';
        _progress = 0.8;
      });

      // Generate RPP menggunakan AI service
      final RPPService rppService = RPPService();
      final generatedRPP = await rppService.generateRPP(
        judul: _judulController.text,
        mataPelajaranId: widget.selectedMataPelajaran,
        mataPelajaranName: widget.mataPelajaranName,
        kontenMateri: allKontenMateri,
        tujuanPembelajaran: _objectivesChecked ? _tujuanController.text : '',
        alatMedia: _mediaChecked ? _alatMediaController.text : '',
      );

      setState(() {
        _progress = 1.0;
        _statusMessage = 'RPP berhasil digenerate!';
      });

      // Navigate ke halaman detail RPP
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RPPDetailPage(
              rppData: generatedRPP,
              isNew: true,
            ),
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isGenerating = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal generate RPP: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Generate Lesson Plan'),
        backgroundColor: Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _updateTitleFromSelection,
            tooltip: 'Refresh Title dari Selection',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected Topics Section
            _buildSelectedTopics(),
            SizedBox(height: 32),
            
            // Lesson Details Section
            _buildLessonDetails(),
            SizedBox(height: 32),
            
            // Generate Button
            _buildGenerateButton(),
            SizedBox(height: 20),
            
            // Progress Indicator
            if (_isGenerating) _buildProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTopics() {
    final totalSelected = widget.checkedBab.length + widget.checkedSubBab.length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Topics:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF4F46E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalSelected selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // Display selected sub topics
          if (widget.checkedSubBab.isNotEmpty) ...[
            ...widget.checkedSubBab.map((subBab) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 8, color: Color(0xFF4F46E5)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sub ${subBab['urutan']}: ${subBab['judul_sub_bab'] ?? 'Judul Sub Bab'}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
          
          // Display selected chapters dengan sub bab-nya
          if (widget.checkedBab.isNotEmpty) ...[
            ...widget.checkedBab.map((bab) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: widget.checkedSubBab.isNotEmpty ? 16 : 0),
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.bookmark, size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text(
                        'Chapter ${bab['urutan']}: ${bab['judul_bab']}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tampilkan semua sub bab dalam chapter ini
                ..._getAllSubBabForBab(bab['id']).map((subBab) => Padding(
                  padding: EdgeInsets.only(left: 20, bottom: 6),
                  child: Row(
                    children: [
                      Text(
                        '${subBab['urutan']}.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subBab['judul_sub_bab'] ?? 'Judul Sub Bab',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                SizedBox(height: 12),
              ],
            )),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getAllSubBabForBab(String babId) {
    // Untuk implementasi nyata, Anda perlu mengambil data dari API
    // Saat ini mengembalikan list kosong - perlu diimplementasi sesuai struktur data Anda
    return [];
  }

  Widget _buildLessonDetails() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lesson Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 20),
          
          // Subject and Date Row
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.subject,
                  title: 'Subject',
                  content: widget.mataPelajaranName,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.calendar_today,
                  title: 'Date',
                  content: _getFormattedDate(),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Lesson Title - Editable dengan auto-suggestion
          _buildEditableFieldWithCheckbox(
            controller: _judulController,
            label: 'Lesson Title',
            hintText: 'Contoh: RPP Introduction to Forces, Newton\'s First Law',
            icon: Icons.title,
            isChecked: _titleChecked,
            onCheckedChanged: (value) {
              setState(() {
                _titleChecked = value;
                if (value) {
                  _updateTitleFromSelection();
                }
              });
            },
            maxLines: 2,
          ),
          SizedBox(height: 16),
          
          // Lesson Objectives - Editable
          _buildEditableFieldWithCheckbox(
            controller: _tujuanController,
            label: 'Lesson Objectives',
            hintText: 'Students will identify types of forces, understand Newton\'s laws of motion, and analyze real-world applications',
            icon: Icons.flag,
            isChecked: _objectivesChecked,
            onCheckedChanged: (value) {
              setState(() {
                _objectivesChecked = value;
              });
            },
            maxLines: 3,
          ),
          SizedBox(height: 16),
          
          // Media/Tools - Editable
          _buildEditableFieldWithCheckbox(
            controller: _alatMediaController,
            label: 'Media/Tools',
            hintText: 'Projector, white board, experiment kit (springs, weights, carts)',
            icon: Icons.computer,
            isChecked: _mediaChecked,
            onCheckedChanged: (value) {
              setState(() {
                _mediaChecked = value;
              });
            },
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableFieldWithCheckbox({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required bool isChecked,
    required Function(bool) onCheckedChanged,
    int maxLines = 1,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isChecked,
                onChanged: (value) {
                  onCheckedChanged(value ?? false);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              Icon(icon, size: 16, color: Colors.grey.shade600),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: controller,
            enabled: isChecked,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade500),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
            ),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
            onChanged: (value) {
              // User dapat mengedit manual
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateRPP,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF10B981),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, size: 24),
            SizedBox(width: 12),
            Text(
              _isGenerating ? 'Generating...' : 'Generate Lesson Plan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.grey.shade300,
            color: Color(0xFF10B981),
            borderRadius: BorderRadius.circular(4),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _statusMessage,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              Text(
                '${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}