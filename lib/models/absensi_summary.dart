// models/absensi_summary.dart
class AbsensiSummary {
  final String id;
  final String mataPelajaranId;
  final String mataPelajaranNama;
  final DateTime tanggal;
  final int totalSiswa;
  final int hadir;
  final int tidakHadir;

  AbsensiSummary({
    required this.id,
    required this.mataPelajaranId,
    required this.mataPelajaranNama,
    required this.tanggal,
    required this.totalSiswa,
    required this.hadir,
    required this.tidakHadir,
  });

  factory AbsensiSummary.fromJson(Map<String, dynamic> json) {
    return AbsensiSummary(
      id: json['id'] ?? '',
      mataPelajaranId: json['mata_pelajaran_id'] ?? '',
      mataPelajaranNama: json['mata_pelajaran_nama'] ?? '',
      tanggal: DateTime.parse(json['tanggal']),
      totalSiswa: json['total_siswa'] ?? 0,
      hadir: json['hadir'] ?? 0,
      tidakHadir: json['tidak_hadir'] ?? 0,
    );
  }
}