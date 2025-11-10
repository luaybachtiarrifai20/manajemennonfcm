class Siswa {
  final String id;
  final String nama;
  final String kelas;
  final String nis;
  final String alamat;
  final String namaWali;
  final String noTelepon;
  final String? kelasId;

  Siswa({
    required this.id,
    required this.nama,
    required this.kelas,
    required this.nis,
    required this.alamat,
    required this.namaWali,
    required this.noTelepon,
    this.kelasId,
  });

  factory Siswa.fromJson(Map<String, dynamic> json) {
    return Siswa(
      id: json['id'].toString(),
      nama: json['nama'] ?? '',
      kelas: json['kelas_nama'] ?? '',
      nis: json['nis'] ?? '',
      alamat: json['alamat'] ?? '',
      namaWali: json['namaWali'] ?? '',
      noTelepon: json['noTelepon'] ?? '',
      kelasId: json['kelas_id'],
    );
  }
}