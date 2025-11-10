import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class RPPDetailPage extends StatefulWidget {
  final Map<String, dynamic> rppData;
  final bool isNew;

  const RPPDetailPage({super.key, required this.rppData, this.isNew = false});

  @override
  RPPDetailPageState createState() => RPPDetailPageState();
}

class RPPDetailPageState extends State<RPPDetailPage> {
  bool _isSaving = false;
  bool _isEditing = false;
  String _editedContent = '';

  @override
  void initState() {
    super.initState();
    _editedContent = _formatRPPContent();
  }

  String _formatRPPContent() {
    final buffer = StringBuffer();

    buffer.writeln('RENCANA PELAKSANAAN PEMBELAJARAN (RPP)');
    buffer.writeln('KURIKULUM 2013 (3 KOMPONEN)');
    buffer.writeln('(Sesuai Edaran Mendikbud Nomor 14 Tahun 2019)');
    buffer.writeln();

    // Informasi Header
    buffer.writeln(
      'Satuan Pendidikan\t: ${widget.rppData['satuan_pendidikan'] ?? 'SD/MI'}',
    );
    buffer.writeln(
      'Kelas / Semester\t: ${widget.rppData['kelas_semester'] ?? '1 / 1'}',
    );
    buffer.writeln(
      'Tema\t\t\t: ${widget.rppData['tema'] ?? 'Kegemaranku (Tema 2)'}',
    );
    buffer.writeln(
      'Sub Tema\t\t: ${widget.rppData['sub_tema'] ?? 'Gemar Berolahraga (Sub Tema 1)'}',
    );
    buffer.writeln(
      'Pembelajaran ke\t: ${widget.rppData['pembelajaran_ke'] ?? '1'}',
    );
    buffer.writeln(
      'Alokasi waktu\t: ${widget.rppData['alokasi_waktu'] ?? '1 Hari'}',
    );
    buffer.writeln();

    // A. TUJUAN PEMBELAJARAN
    buffer.writeln('A. TUJUAN PEMBELAJARAN');
    if (widget.rppData['tujuan_pembelajaran'] != null) {
      final tujuanLines = widget.rppData['tujuan_pembelajaran']
          .toString()
          .split('\n');
      for (int i = 0; i < tujuanLines.length; i++) {
        if (tujuanLines[i].trim().isNotEmpty) {
          buffer.writeln('${i + 1}. ${tujuanLines[i].trim()}');
        }
      }
    } else {
      // Default tujuan pembelajaran
      buffer.writeln(
        '1. Dengan mengamati gambar, siswa dapat memahami kosakata tentang cara memelihara kesehatan dengan tepat.',
      );
      buffer.writeln(
        '2. Dengan menirukan kata-kata yang dibacakan oleh guru, siswa dapat menambah kosakata tentang cara memelihara kesehatan dengan tepat dan percaya diri.',
      );
      buffer.writeln(
        '3. Melalui kegiatan membaca, siswa dapat menggunakan kosakata tentang olahraga sebagai cara memelihara kesehatan dengan tepat.',
      );
    }
    buffer.writeln();

    // B. KEGIATAN PEMBELAJARAN
    buffer.writeln('B. KEGIATAN PEMBELAJARAN');
    buffer.writeln();

    // Kegiatan Pendahuluan
    buffer.writeln(
      'Kegiatan Pendahuluan (${widget.rppData['waktu_pendahuluan'] ?? '15'} menit)',
    );
    if (widget.rppData['kegiatan_pendahuluan'] != null) {
      final pendahuluanLines = widget.rppData['kegiatan_pendahuluan']
          .toString()
          .split('\n');
      for (var line in pendahuluanLines) {
        if (line.trim().isNotEmpty) {
          buffer.writeln('• ${line.trim()}');
        }
      }
    } else {
      buffer.writeln('• Melakukan Pembukaan dengan Salam dan Membaca Doa');
      buffer.writeln(
        '• Mengaitkan Materi Sebelumnya dengan Materi yang akan dipelajari',
      );
      buffer.writeln(
        '• Memberikan gambaran tentang manfaat mempelajari pelajaran',
      );
    }
    buffer.writeln();

    // Kegiatan Inti
    buffer.writeln(
      'Kegiatan Inti (${widget.rppData['waktu_inti'] ?? '140'} menit)',
    );
    if (widget.rppData['kegiatan_inti'] != null) {
      final intiLines = widget.rppData['kegiatan_inti'].toString().split('\n');
      for (var line in intiLines) {
        if (line.trim().isNotEmpty) {
          if (line.trim().startsWith('A.') ||
              line.trim().startsWith('B.') ||
              line.trim().startsWith('C.')) {
            buffer.writeln(line.trim());
          } else {
            buffer.writeln('• ${line.trim()}');
          }
        }
      }
    } else {
      buffer.writeln('A. Ayo Mengamati');
      buffer.writeln('• Siswa menyimak teks yang dibacakan oleh guru');
      buffer.writeln('• Guru menunjukkan gambar jenis permainan dan olahraga');
      buffer.writeln(
        '• Guru memancing partisipasi aktif siswa dengan pertanyaan',
      );
      buffer.writeln();
      buffer.writeln('B. Ayo Membaca');
      buffer.writeln('• Siswa menirukan kata-kata yang dibacakan guru');
      buffer.writeln('• Guru memberi kesempatan bertanya tentang makna kata');
      buffer.writeln();
      buffer.writeln('C. Ayo Mencoba');
      buffer.writeln(
        '• Siswa mengidentifikasi gambar kegiatan yang menyehatkan',
      );
      buffer.writeln('• Siswa memberi tanda centang/silang pada gambar');
    }
    buffer.writeln();

    // Kegiatan Penutup
    buffer.writeln(
      'Kegiatan Penutup (${widget.rppData['waktu_penutup'] ?? '15'} menit)',
    );
    if (widget.rppData['kegiatan_penutup'] != null) {
      final penutupLines = widget.rppData['kegiatan_penutup'].toString().split(
        '\n',
      );
      for (var line in penutupLines) {
        if (line.trim().isNotEmpty) {
          buffer.writeln('• ${line.trim()}');
        }
      }
    } else {
      buffer.writeln('• Siswa membuat resume dengan bimbingan guru');
      buffer.writeln('• Guru memeriksa pekerjaan siswa');
      buffer.writeln('• Pemberian hadiah/pujian untuk pekerjaan yang benar');
    }
    buffer.writeln();

    // C. PENILAIAN
    buffer.writeln('C. PENILAIAN (ASESMEN)');
    if (widget.rppData['penilaian'] != null) {
      buffer.writeln(widget.rppData['penilaian']);
    } else {
      buffer.writeln(
        'Penilaian terhadap materi ini dapat dilakukan sesuai kebutuhan guru yaitu dari pengamatan sikap, tes pengetahuan dan presentasi unjuk kerja atau hasil karya/projek dengan rubric penilaian.',
      );
    }
    buffer.writeln();

    // Tanda Tangan
    buffer.writeln('Mengetahui');
    buffer.writeln();
    buffer.writeln('Kepala Sekolah');
    buffer.writeln();
    buffer.writeln('...................................');
    buffer.writeln('NIP ..............................');
    buffer.writeln();
    buffer.writeln('Guru Mata Pelajaran');
    buffer.writeln();
    buffer.writeln('...................................');
    buffer.writeln('NIP ..............................');

    if (widget.rppData['is_ai_generated'] == true) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('*RPP ini digenerate secara otomatis menggunakan AI*');
    }

    return buffer.toString();
  }

  String _getMonthName(int month) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  Future<void> _saveRPP() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await ApiSubjectService.saveRPP({
        'guru_id': widget.rppData['guru_id'],
        'mata_pelajaran_id': widget.rppData['mata_pelajaran_id'],
        'judul': widget.rppData['judul'],
        'tujuan_pembelajaran': widget.rppData['tujuan_pembelajaran'],
        'kegiatan_pendahuluan': widget.rppData['kegiatan_pendahuluan'],
        'kegiatan_inti': widget.rppData['kegiatan_inti'],
        'kegiatan_penutup': widget.rppData['kegiatan_penutup'],
        'penilaian': widget.rppData['penilaian'],
        'satuan_pendidikan': widget.rppData['satuan_pendidikan'],
        'kelas_semester': widget.rppData['kelas_semester'],
        'tema': widget.rppData['tema'],
        'sub_tema': widget.rppData['sub_tema'],
        'pembelajaran_ke': widget.rppData['pembelajaran_ke'],
        'alokasi_waktu': widget.rppData['alokasi_waktu'],
        'waktu_pendahuluan': widget.rppData['waktu_pendahuluan'],
        'waktu_inti': widget.rppData['waktu_inti'],
        'waktu_penutup': widget.rppData['waktu_penutup'],
        'is_ai_generated': widget.rppData['is_ai_generated'] ?? false,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('RPP berhasil disimpan')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan RPP: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _exportToWord() async {
    try {
      // Tunggu sebentar untuk memastikan plugin siap
      await Future.delayed(Duration(milliseconds: 100));

      // Create a new PDF document
      final PdfDocument document = PdfDocument();

      // Add a page
      final PdfPage page = document.pages.add();

      // Create PDF graphics
      final PdfGraphics graphics = page.graphics;

      // Create PDF font
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        16,
        style: PdfFontStyle.bold,
      );

      // Draw title
      graphics.drawString(
        'RENCANA PELAKSANAAN PEMBELAJARAN (RPP)',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.size.width, 30),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Draw content
      final List<String> lines = _editedContent.split('\n');
      double yPosition = 40;

      for (String line in lines) {
        if (line.trim().isEmpty) {
          yPosition += 10;
          continue;
        }

        graphics.drawString(
          line,
          font,
          bounds: Rect.fromLTWH(50, yPosition, page.size.width - 100, 15),
        );
        yPosition += 18;

        // Check for page break
        if (yPosition > page.size.height - 50) {
          document.pages.add();
          yPosition = 40;
        }
      }

      // Save the document
      final List<int> bytes = await document.save();
      document.dispose();

      // Get directory dengan error handling
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/RPP_${widget.rppData['judul']}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);

      // Open the file
      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('RPP berhasil diexport ke PDF')));
      }
    } catch (e) {
      print('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _exportToText() async {
    try {
      await Future.delayed(Duration(milliseconds: 100));

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/RPP_${widget.rppData['judul']}_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(_editedContent, flush: true);

      await OpenFile.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RPP berhasil diexport ke file text')),
        );
      }
    } catch (e) {
      print('Text export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal export: ${e.toString()}')),
        );
      }
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _updateContent(String newContent) {
    setState(() {
      _editedContent = newContent;
    });
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit RPP' : 'Detail RPP'),
        backgroundColor: Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing) ...[
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: _toggleEdit,
              tooltip: 'Edit RPP',
            ),
            IconButton(
              icon: Icon(Icons.download),
              onPressed: _exportToWord,
              tooltip: 'Download sebagai PDF',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'word') _exportToText();
                if (value == 'pdf') _exportToWord();
                if (value == 'copy') _copyToClipboard();
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'word',
                  child: Row(
                    children: [
                      Icon(Icons.description, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Export ke Word'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Export ke PDF'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.content_copy, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Copy ke Clipboard'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (_isEditing) ...[
            IconButton(
              icon: Icon(Icons.save),
              onPressed: () {
                _toggleEdit();
                _saveRPP();
              },
              tooltip: 'Simpan Perubahan',
            ),
            IconButton(
              icon: Icon(Icons.close),
              onPressed: _toggleEdit,
              tooltip: 'Batal Edit',
            ),
          ],
          if (widget.isNew && !_isEditing) ...[
            IconButton(
              icon: _isSaving
                  ? CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                  : Icon(Icons.save),
              onPressed: _isSaving ? null : _saveRPP,
              tooltip: 'Simpan RPP',
            ),
          ],
        ],
      ),
      body: _isEditing ? _buildEditor() : _buildPreview(),
    );
  }

  Widget _buildEditor() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Toolbar sederhana
          Container(
            padding: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFormatButton('B', Icons.format_bold, () {}),
                _buildFormatButton('I', Icons.format_italic, () {}),
                _buildFormatButton('U', Icons.format_underlined, () {}),
                _buildFormatButton('H1', Icons.title, () {}),
                _buildFormatButton('Table', Icons.table_chart, () {}),
                _buildFormatButton('List', Icons.list, () {}),
              ],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: TextEditingController(text: _editedContent),
                onChanged: _updateContent,
                maxLines: null,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  hintText: 'Ketik RPP disini...',
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Courier',
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatButton(
    String text,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      tooltip: text,
    );
  }

  Widget _buildPreview() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: _buildFormattedContent(),
        ),
      ),
    );
  }

  Widget _buildFormattedContent() {
    final lines = _editedContent.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.trim().isEmpty) {
          return SizedBox(height: 16);
        }

        if (line.startsWith('RENCANA PELAKSANAAN PEMBELAJARAN')) {
          return Column(
            children: [
              Text(
                line,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F46E5),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
            ],
          );
        }

        if (line.startsWith('=')) {
          return Container(
            height: 2,
            color: Colors.grey.shade300,
            margin: EdgeInsets.symmetric(vertical: 8),
          );
        }

        if (line.startsWith('|')) {
          return _buildTableRow(line);
        }

        if (line.startsWith('A.') ||
            line.startsWith('B.') ||
            line.startsWith('C.')) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              Text(
                line,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4F46E5),
                ),
              ),
              SizedBox(height: 8),
            ],
          );
        }

        if (line.contains('Media :') || line.contains('Alat/Bahan :')) {
          return Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          );
        }

        if (line.startsWith('•') ||
            line.startsWith('1.') ||
            line.startsWith('2.')) {
          return Padding(
            padding: EdgeInsets.only(left: 16, bottom: 4),
            child: Text(line, style: TextStyle(fontSize: 14, height: 1.5)),
          );
        }

        if (line.contains('Mengetahui') ||
            line.contains('Kepala Sekolah') ||
            line.contains('Guru Mata Pelajaran')) {
          return Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              line,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(line, style: TextStyle(fontSize: 14, height: 1.5)),
        );
      }).toList(),
    );
  }

  Widget _buildTableRow(String line) {
    final cells = line
        .split('|')
        .where((cell) => cell.trim().isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: cells.map((cell) {
          return Expanded(
            flex: 2,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(cell.trim(), style: TextStyle(fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _editedContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('RPP berhasil disalin ke clipboard')),
    );
  }
}
