import 'dart:convert';

import 'package:http/http.dart' as http;

class RPPService {
  Map<String, dynamic> _createFallbackRPP({
    required String judul,
    required String mataPelajaranId,
    required String mataPelajaranName,
    List<Map<String, dynamic>> kontenMateri = const [],
    String customContent = '',
  }) {
    return {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'title': judul,
      'subject_id': mataPelajaranId,
      'subject_name': mataPelajaranName,
      'learning_objectives': customContent.isNotEmpty
          ? customContent
          : 'Tujuan pembelajaran belum tersedia.',
      'preliminary_activities': 'Kegiatan pendahuluan belum tersedia.',
      'core_activities': 'Kegiatan inti belum tersedia.',
      'closing_activities': 'Kegiatan penutup belum tersedia.',
      'assessment': 'Penilaian belum tersedia.',
      'education_unit': 'SD/MI',
      'class_semester': '1 / 1',
      'theme': judul,
      'sub_theme': 'Sub Tema 1',
      'learning_sequence': '1',
      'time_allocation': '1 Hari',
      'preliminary_time': '15',
      'core_time': '140',
      'closing_time': '15',
      'created_at': DateTime.now().toIso8601String(),
      'is_ai_generated': false,
      'material_content': kontenMateri,
    };
  }

  static const String baseUrl = "https://api.openai.com/v1/chat/completions";
  // Ganti dengan API key OpenAI Anda
  static const String apiKey = "your-openai-api-key";

  Future<Map<String, dynamic>> generateRPP({
    required String judul,
    required String mataPelajaranId,
    required String mataPelajaranName,
    required List<Map<String, dynamic>> kontenMateri,
    String tujuanPembelajaran = '',
    String alatMedia = '',
  }) async {
    try {
      // Siapkan prompt untuk AI
      final prompt = _buildPrompt(
        judul: judul,
        mataPelajaranName: mataPelajaranName,
        kontenMateri: kontenMateri,
        tujuanPembelajaran: tujuanPembelajaran,
        alatMedia: alatMedia,
      );

      // Panggil API OpenAI
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Anda adalah ahli pembuatan RPP (Rencana Pelaksanaan Pembelajaran) yang profesional. Buatlah RPP yang lengkap dan terstruktur berdasarkan materi yang diberikan.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.7,
          'max_tokens': 3000,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices'][0]['message']['content'];

        // Parse response AI menjadi struktur RPP
        return _parseAIResponse(
          content: content,
          judul: judul,
          mataPelajaranId: mataPelajaranId,
          mataPelajaranName: mataPelajaranName,
        );
      } else {
        throw Exception('Failed to generate RPP: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback: Buat RPP sederhana jika AI gagal
      return _createFallbackRPP(
        judul: judul,
        mataPelajaranId: mataPelajaranId,
        mataPelajaranName: mataPelajaranName,
        kontenMateri: kontenMateri,
      );
    }
  }

  String _buildPrompt({
    required String judul,
    required String mataPelajaranName,
    required List<Map<String, dynamic>> kontenMateri,
    required String tujuanPembelajaran,
    required String alatMedia,
  }) {
    final buffer = StringBuffer();

    buffer.writeln(
      'Buatkan RPP (Rencana Pelaksanaan Pembelajaran) format 1 lembar dengan 3 komponen utama seperti contoh berikut:',
    );
    buffer.writeln();
    buffer.writeln('RENCANA PELAKSANAAN PEMBELAJARAN (RPP)');
    buffer.writeln('KURIKULUM 2013 (3 KOMPONEN)');
    buffer.writeln('(Sesuai Edaran Mendikbud Nomor 14 Tahun 2019)');
    buffer.writeln();
    buffer.writeln('Satuan Pendidikan\t: SD/MI ......');
    buffer.writeln('Kelas / Semester\t: 1 / 1');
    buffer.writeln('Tema\t\t\t: Kegemaranku (Tema 2)');
    buffer.writeln('Sub Tema\t\t: Gemar Berolahraga (Sub Tema 1)');
    buffer.writeln('Pembelajaran ke\t: 1');
    buffer.writeln('Alokasi waktu\t: 1 Hari');
    buffer.writeln();
    buffer.writeln('A. TUJUAN PEMBELAJARAN');
    buffer.writeln(
      '1. Dengan mengamati gambar, siswa dapat memahami kosakata tentang cara memelihara kesehatan dengan tepat.',
    );
    buffer.writeln(
      '2. Dengan menirukan kata-kata yang dibacakan oleh guru, siswa dapat menambah kosakata tentang cara memelihara kesehatan dengan tepat dan percaya diri.',
    );
    buffer.writeln(
      '3. Melalui kegiatan membaca, siswa dapat menggunakan kosakata tentang olahraga sebagai cara memelihara kesehatan dengan tepat.',
    );
    buffer.writeln();
    buffer.writeln('B. KEGIATAN PEMBELAJARAN');
    buffer.writeln();
    buffer.writeln('Kegiatan Pendahuluan (15 menit)');
    buffer.writeln('• Melakukan Pembukaan dengan Salam dan Membaca Doa');
    buffer.writeln(
      '• Mengaitkan Materi Sebelumnya dengan Materi yang akan dipelajari',
    );
    buffer.writeln(
      '• Memberikan gambaran tentang manfaat mempelajari pelajaran',
    );
    buffer.writeln();
    buffer.writeln('Kegiatan Inti (140 menit)');
    buffer.writeln('A. Ayo Mengamati');
    buffer.writeln('• Siswa menyimak teks yang dibacakan oleh guru');
    buffer.writeln('• Guru menunjukkan gambar jenis permainan dan olahraga');
    buffer.writeln('B. Ayo Membaca');
    buffer.writeln('• Siswa menirukan kata-kata yang dibacakan guru');
    buffer.writeln('C. Ayo Mencoba');
    buffer.writeln('• Siswa mengidentifikasi gambar kegiatan yang menyehatkan');
    buffer.writeln();
    buffer.writeln('Kegiatan Penutup (15 menit)');
    buffer.writeln('• Siswa membuat resume dengan bimbingan guru');
    buffer.writeln('• Guru memeriksa pekerjaan siswa');
    buffer.writeln();
    buffer.writeln('C. PENILAIAN (ASESMEN)');
    buffer.writeln(
      'Penilaian terhadap materi ini dapat dilakukan sesuai kebutuhan guru yaitu dari pengamatan sikap, tes pengetahuan dan presentasi unjuk kerja atau hasil karya/projek dengan rubric penilaian.',
    );
    buffer.writeln();
    buffer.writeln(
      'Buat RPP dengan format yang sama untuk mata pelajaran: $mataPelajaranName',
    );
    buffer.writeln('Judul: $judul');

    if (tujuanPembelajaran.isNotEmpty) {
      buffer.writeln(
        'Tujuan Pembelajaran yang diinginkan: $tujuanPembelajaran',
      );
    }

    if (kontenMateri.isNotEmpty) {
      buffer.writeln('Materi yang akan diajarkan:');
      for (var materi in kontenMateri) {
        buffer.writeln('- ${materi['judul']}');
      }
    }

    return buffer.toString();
  }

  Map<String, dynamic> _parseAIResponse({
    required String content,
    required String judul,
    required String mataPelajaranId,
    required String mataPelajaranName,
  }) {
    try {
      return {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'title': judul,
        'subject_id': mataPelajaranId,
        'subject_name': mataPelajaranName,
        'learning_objectives': _extractSection(
          content,
          'A. TUJUAN PEMBELAJARAN',
        ),
        'preliminary_activities': _extractSection(
          content,
          'Kegiatan Pendahuluan',
        ),
        'core_activities': _extractSection(content, 'Kegiatan Inti'),
        'closing_activities': _extractSection(content, 'Kegiatan Penutup'),
        'assessment': _extractSection(content, 'C. PENILAIAN'),
        'education_unit': 'SD/MI',
        'class_semester': '1 / 1',
        'theme': judul,
        'sub_theme': 'Sub Tema 1',
        'learning_sequence': '1',
        'time_allocation': '1 Hari',
        'preliminary_time': '15',
        'core_time': '140',
        'closing_time': '15',
        'created_at': DateTime.now().toIso8601String(),
        'is_ai_generated': true,
      };
    } catch (e) {
      return _createFallbackRPP(
        judul: judul,
        mataPelajaranId: mataPelajaranId,
        mataPelajaranName: mataPelajaranName,
        kontenMateri: [],
        customContent: content,
      );
    }
  }

  String _extractSection(String content, String sectionTitle) {
    try {
      final lines = content.split('\n');
      bool foundSection = false;
      final sectionContent = StringBuffer();

      for (String line in lines) {
        if (line.contains(sectionTitle)) {
          foundSection = true;
          continue;
        }

        if (foundSection) {
          if (line.trim().isEmpty ||
              line.contains('B. KEGIATAN PEMBELAJARAN') ||
              line.contains('C. PENILAIAN') ||
              line.contains('Mengetahui')) {
            break;
          }
          sectionContent.writeln(line);
        }
      }

      return sectionContent.toString().trim();
    } catch (e) {
      return '';
    }
  }
}
