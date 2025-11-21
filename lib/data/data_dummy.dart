import 'package:manajemensekolah/models/guru.dart';
import 'package:manajemensekolah/models/kelas.dart';

import '../models/absensi.dart';
import '../models/kegiatan.dart';
import '../models/nilai.dart';
import '../models/pengumuman.dart';
import '../models/siswa.dart';
import '../models/user.dart';

class DataDummy {
  static List<User> users = [
    User(id: '1', nama: 'Admin Sekolah', email: 'admin@sekolah.com', password: 'admin123', role: 'admin'),
    User(id: '2', nama: 'Budi Santoso', email: 'budi@sekolah.com', password: 'guru123', role: 'guru', kelas: '7A'),
    User(id: '3', nama: 'Sari Dewi', email: 'sari@sekolah.com', password: 'guru123', role: 'guru', kelas: '8B'),
    User(id: '4', nama: 'Staff TU', email: 'staff@sekolah.com', password: 'staff123', role: 'staff'),
    User(id: '5', nama: 'Wali Ahmad', email: 'wali1@email.com', password: 'wali123', role: 'wali'),
    User(id: '6', nama: 'Wali Siti', email: 'wali2@email.com', password: 'wali123', role: 'wali'),
  ];

  static List<Siswa> siswa = [
    Siswa(id: '1', nama: 'Ahmad Rizki', kelas: '7A', nis: '001', alamat: 'Jl. Merdeka 1', nameParent: 'Wali Ahmad', noTelepon: '081234567890'),
    Siswa(id: '2', nama: 'Siti Nurhaliza', kelas: '7A', nis: '002', alamat: 'Jl. Sudirman 2', nameParent: 'Wali Siti', noTelepon: '081234567891'),
    Siswa(id: '3', nama: 'Budi Permana', kelas: '7B', nis: '003', alamat: 'Jl. Gatot Subroto 3', nameParent: 'Wali Budi', noTelepon: '081234567892'),
    Siswa(id: '4', nama: 'Dewi Sartika', kelas: '8A', nis: '004', alamat: 'Jl. Diponegoro 4', nameParent: 'Wali Dewi', noTelepon: '081234567893'),
    Siswa(id: '5', nama: 'Andi Wijaya', kelas: '8B', nis: '005', alamat: 'Jl. Ahmad Yani 5', nameParent: 'Wali Andi', noTelepon: '081234567894'),
  ];

  static List<Nilai> nilai = [
    Nilai(siswaId: '1', mataPelajaran: 'Matematika', nilai: 85.0, semester: 'Ganjil'),
    Nilai(siswaId: '1', mataPelajaran: 'Bahasa Indonesia', nilai: 88.0, semester: 'Ganjil'),
    Nilai(siswaId: '1', mataPelajaran: 'IPA', nilai: 82.0, semester: 'Ganjil'),
    Nilai(siswaId: '2', mataPelajaran: 'Matematika', nilai: 78.0, semester: 'Ganjil'),
    Nilai(siswaId: '2', mataPelajaran: 'Bahasa Indonesia', nilai: 85.0, semester: 'Ganjil'),
    Nilai(siswaId: '2', mataPelajaran: 'IPA', nilai: 80.0, semester: 'Ganjil'),
  ];

  static List<Absensi> absensi = [
    Absensi(siswaId: '1', tanggal: DateTime.now().subtract(Duration(days: 1)), status: 'hadir'),
    Absensi(siswaId: '1', tanggal: DateTime.now().subtract(Duration(days: 2)), status: 'hadir'),
    Absensi(siswaId: '1', tanggal: DateTime.now().subtract(Duration(days: 3)), status: 'sakit'),
    Absensi(siswaId: '2', tanggal: DateTime.now().subtract(Duration(days: 1)), status: 'hadir'),
    Absensi(siswaId: '2', tanggal: DateTime.now().subtract(Duration(days: 2)), status: 'izin'),
  ];

  static List<Kegiatan> kegiatan = [
    Kegiatan(
      id: '1',
      nama: 'Upacara Bendera',
      deskripsi: 'Upacara bendera rutin setiap hari Senin',
      tanggal: DateTime.now().add(Duration(days: 1)),
      lokasi: 'Lapangan Sekolah',
    ),
    Kegiatan(
      id: '2',
      nama: 'Ujian Tengah Semester',
      deskripsi: 'Pelaksanaan ujian tengah semester untuk semua kelas',
      tanggal: DateTime.now().add(Duration(days: 7)),
      lokasi: 'Ruang Kelas',
    ),
    Kegiatan(
      id: '3',
      nama: 'Lomba Sains',
      deskripsi: 'Lomba sains antar kelas tingkat SMP',
      tanggal: DateTime.now().add(Duration(days: 14)),
      lokasi: 'Lab IPA',
    ),
  ];

  static List<Pengumuman> pengumuman = [
    Pengumuman(
      id: '1',
      judul: 'Libur Semester',
      isi: 'Libur semester akan dimulai tanggal 15 Desember 2024',
      tanggal: DateTime.now(),
      kategori: 'Akademik',
    ),
    Pengumuman(
      id: '2',
      judul: 'Pembayaran SPP',
      isi: 'Batas waktu pembayaran SPP bulan ini adalah tanggal 10',
      tanggal: DateTime.now().subtract(Duration(days: 1)),
      kategori: 'Keuangan',
    ),
  ];
  static List<Map<String, dynamic>> inventaris = [
    {'nama': 'Meja Siswa', 'jumlah': 150, 'kondisi': 'Baik'},
    {'nama': 'Kursi Siswa', 'jumlah': 150, 'kondisi': 'Baik'},
    {'nama': 'Papan Tulis', 'jumlah': 12, 'kondisi': 'Baik'},
    {'nama': 'Proyektor', 'jumlah': 5, 'kondisi': 'Rusak Ringan'},
    {'nama': 'Komputer', 'jumlah': 20, 'kondisi': 'Baik'},
    {'nama': 'Printer', 'jumlah': 3, 'kondisi': 'Baik'},
  ];

  static List<Kelas> daftarKelas = [
    Kelas(id: '1', nama: '7A', waliKelas: 'Budi Santoso', jumlahSiswa: 25),
    Kelas(id: '2', nama: '7B', waliKelas: 'Sari Dewi', jumlahSiswa: 23),
    Kelas(id: '3', nama: '8A', waliKelas: 'Ahmad Fauzi', jumlahSiswa: 28),
    Kelas(id: '4', nama: '8B', waliKelas: 'Dewi Sartika', jumlahSiswa: 26),
    Kelas(id: '5', nama: '9A', waliKelas: 'Rudi Hartono', jumlahSiswa: 30),
    Kelas(id: '6', nama: '9B', waliKelas: 'Siti Rahayu', jumlahSiswa: 27),
  ];

  static List<Guru> daftarGuru = [
    Guru(id: '1', nama: 'Budi Santoso'),
    Guru(id: '2', nama: 'Sari Dewi'),
    Guru(id: '3', nama: 'Ahmad Fauzi'),
    Guru(id: '4', nama: 'Dewi Sartika'),
    Guru(id: '5', nama: 'Rudi Hartono'),
    Guru(id: '6', nama: 'Siti Rahayu'),
  ];
}