class User {
  final String id;
  final String nama;
  final String email;
  final String password;
  final String role;
  final String? kelas;

  User({
    required this.id,
    required this.nama,
    required this.email,
    required this.password,
    required this.role,
    this.kelas,
  });
}