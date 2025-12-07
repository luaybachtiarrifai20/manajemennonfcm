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
      nama: json['name'] ?? '',
      kelas: json['kelas_nama'] ?? '',
      nis: json['student_number'] ?? '',
      alamat: json['address'] ?? '',
      nameParent: json['guardian_name'] ?? '',
      noTelepon: json['phone_number'] ?? '',
      classId: json['class_id'],
    );
  }
}
