class Absensi {
  final String siswaId;
  final DateTime tanggal;
  final String status; // hadir, sakit, izin, alpha

  Absensi({
    required this.siswaId,
    required this.tanggal,
    required this.status,
  });
}