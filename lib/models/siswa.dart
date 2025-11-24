class Siswa {
  final String id;
  final String nama;
  final String kelas;
  final String nis;
  final String alamat;
  final String nameParent;
  final String noTelepon;
  final String? classId;

  Siswa({
    required this.id,
    required this.nama,
    required this.kelas,
    required this.nis,
    required this.alamat,
    required this.nameParent,
    required this.noTelepon,
    this.classId,
  });

  factory Siswa.fromJson(Map<String, dynamic> json) {
    return Siswa(
      id: json['id'].toString(),
      nama: json['nama'] ?? '',
      kelas: json['kelas_nama'] ?? '',
      nis: json['nis'] ?? '',
      alamat: json['alamat'] ?? '',
      nameParent: json['nameParent'] ?? '',
      noTelepon: json['noTelepon'] ?? '',
      classId: json['kelas_id'],
    );
  }
}
