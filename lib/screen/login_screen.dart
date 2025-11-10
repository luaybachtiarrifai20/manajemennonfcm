import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  final String? initialError;

  const LoginScreen({super.key, this.initialError});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  bool _serverConnected = true;
  bool _showSchoolSelection = false;
  bool _showRoleSelection = false;
  List<dynamic> _sekolahList = [];
  List<dynamic> _roleList = [];
  Map<String, dynamic>? _selectedSekolah;
  Map<String, dynamic>? _userData;
  String? _selectedSekolahId;

  @override
  void initState() {
    super.initState();
    _checkServerConnection();

    // Show initial error if provided
    if (widget.initialError != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.initialError!),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      });
    }
  }

  Future<void> _checkServerConnection() async {
    try {
      await ApiService.checkHealth();
      setState(() {
        _serverConnected = true;
      });
    } catch (e) {
      setState(() {
        _serverConnected = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server tidak terhubung. Pastikan backend berjalan.'),
        ),
      );
    }
  }

  void _handleTokenExpired() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesi telah berakhir. Silakan login kembali.'),
          duration: Duration(seconds: 3),
        ),
      );

      // Clear state
      setState(() {
        _isLoading = false;
        _showSchoolSelection = false;
        _showRoleSelection = false;
        _sekolahList = [];
        _roleList = [];
        _selectedSekolah = null;
        _userData = null;
        _selectedSekolahId = null;
      });

      // Clear form
      emailController.clear();
      passwordController.clear();
    }
  }

  Future<void> login() async {
    if (!_serverConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Server tidak terhubung. Tidak dapat login.')),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final String email = emailController.text.trim();
    final String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan password harus diisi')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final responseData = await ApiService.login(
        email,
        password,
        sekolahId: _selectedSekolahId,
      );

      // Debug logging
      if (kDebugMode) {
        print('🔐 Login Response: $responseData');
        print('📝 Response keys: ${responseData.keys}');
        print('🏫 Pilih sekolah: ${responseData['pilih_sekolah']}');
        print('🎭 Pilih role: ${responseData['pilih_role']}');
      }

      // Handle school selection flow
      if (responseData['pilih_sekolah'] == true) {
        if (kDebugMode) {
          print('🏫 Need to select school');
          print(
            '📋 Available schools: ${responseData['sekolah_list']?.length}',
          );
        }

        // Validasi data sekolah
        if (responseData['sekolah_list'] == null ||
            responseData['sekolah_list'].isEmpty) {
          throw Exception('Daftar sekolah tidak tersedia');
        }

        if (responseData['user'] == null) {
          throw Exception('Data user tidak ditemukan');
        }

        setState(() {
          _showSchoolSelection = true;
          _sekolahList = responseData['sekolah_list'];
          _userData = responseData['user'];
          _isLoading = false;
        });
        return;
      }

      // Handle role selection flow
      if (responseData['pilih_role'] == true) {
        if (kDebugMode) {
          print('🎭 Need to select role');
          print('📋 Available roles: ${responseData['role_list']}');
        }

        // Validasi data role
        if (responseData['role_list'] == null ||
            responseData['role_list'].isEmpty) {
          throw Exception('Daftar role tidak tersedia');
        }

        if (responseData['user'] == null) {
          throw Exception('Data user tidak ditemukan');
        }

        setState(() {
          _showRoleSelection = true;
          _roleList = responseData['role_list'];
          _userData = responseData['user'];
          _selectedSekolah = responseData['sekolah'] ?? {};
          _isLoading = false;
        });
        return;
      }

      // Handle successful login (langsung dapat token)
      // Validasi response structure hanya untuk login sukses
      if (responseData['token'] == null) {
        throw Exception('Token tidak ditemukan dalam response server');
      }

      if (responseData['user'] == null) {
        throw Exception('Data user tidak ditemukan dalam response server');
      }

      // Simpan data login
      await _saveLoginData(responseData);

      // Validasi role sebelum navigasi
      final String userRole = responseData['user']['role']?.toString() ?? '';
      if (userRole.isEmpty) {
        throw Exception('Role user tidak ditemukan');
      }

      if (!mounted) return;

      // Navigate berdasarkan role
      Navigator.pushReplacementNamed(context, '/$userRole');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login berhasil! Selamat datang ${responseData['user']['nama']}',
          ),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        print('❌ Login error: $error');
      }

      String errorMessage = 'Terjadi kesalahan saat login';
      if (error.toString().contains('Token tidak ditemukan')) {
        errorMessage = 'Token tidak valid dari server';
      } else if (error.toString().contains('Data user tidak ditemukan')) {
        errorMessage = 'Data user tidak valid dari server';
      } else {
        errorMessage = error.toString();
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));

      if (error.toString().contains('expired') ||
          error.toString().contains('token') ||
          error.toString().contains('Token')) {
        errorMessage = 'Sesi telah berakhir. Silakan login kembali.';
        _handleTokenExpired();
      } else if (error.toString().contains('Token tidak ditemukan')) {
        errorMessage = 'Token tidak valid dari server';
      } else if (error.toString().contains('Data user tidak ditemukan')) {
        errorMessage = 'Data user tidak valid dari server';
      } else {
        errorMessage = error.toString();
      }

      if (!error.toString().contains('expired')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  // Ganti method _saveLoginData dengan:
  Future<void> _saveLoginData(Map<String, dynamic> responseData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', responseData['token']);
    await prefs.setString('user', json.encode(responseData['user']));

    // Clear force logout flag
    await prefs.setBool('force_logout', false);
  }

  Future<void> _selectSchool(String sekolahId) async {
    if (kDebugMode) {
      print('🎯 Selecting school: $sekolahId');
    }

    setState(() {
      _isLoading = true;
      _selectedSekolahId = sekolahId;
    });

    try {
      final responseData = await ApiService.login(
        emailController.text.trim(),
        passwordController.text,
        sekolahId: sekolahId,
      );

      if (kDebugMode) {
        print('🔐 School Selection Response: $responseData');
        print(
          '🏫 Pilih sekolah after selection: ${responseData['pilih_sekolah']}',
        );
        print('🎭 Pilih role after selection: ${responseData['pilih_role']}');
      }

      // PERBAIKAN: Handle jika setelah pilih sekolah, perlu pilih role
      if (responseData['pilih_role'] == true) {
        if (kDebugMode) {
          print('🎭 Need to select role after school selection');
        }

        if (responseData['role_list'] == null ||
            responseData['role_list'].isEmpty) {
          throw Exception('Daftar role tidak tersedia');
        }

        setState(() {
          _showSchoolSelection = false;
          _showRoleSelection = true;
          _roleList = responseData['role_list'];
          _userData = responseData['user'];
          _selectedSekolah = responseData['sekolah'] ?? {};
          _isLoading = false;
        });
        return;
      }

      // Validasi response untuk login sukses
      if (responseData['token'] == null) {
        throw Exception('Token tidak ditemukan setelah memilih sekolah');
      }

      if (responseData['user'] == null) {
        throw Exception('Data user tidak ditemukan setelah memilih sekolah');
      }

      await _saveLoginData(responseData);

      // Validasi role
      final String userRole = responseData['user']['role']?.toString() ?? '';
      if (userRole.isEmpty) {
        throw Exception('Role user tidak ditemukan');
      }

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/$userRole');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login berhasil! Selamat datang di ${responseData['user']['nama_sekolah']}',
          ),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        print('❌ School selection error: $error');
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));

      setState(() {
        _isLoading = false;
        // Jangan reset _showSchoolSelection agar user bisa memilih sekolah lain
      });
    }
  }

  Future<void> _selectRole(String role) async {
    if (kDebugMode) {
      print('🎯 Selecting role: $role');
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final responseData = await ApiService.login(
        emailController.text.trim(),
        passwordController.text,
        sekolahId: _selectedSekolah?['id'] ?? _selectedSekolahId,
        role: role,
      );

      if (kDebugMode) {
        print('🔐 Role Selection Response: $responseData');
        print('🔑 Token present: ${responseData['token'] != null}');
      }

      // Validasi response untuk login sukses
      if (responseData['token'] == null) {
        throw Exception('Token tidak ditemukan setelah memilih role');
      }

      if (responseData['user'] == null) {
        throw Exception('Data user tidak ditemukan setelah memilih role');
      }

      await _saveLoginData(responseData);

      // Validasi role
      final String userRole = responseData['user']['role']?.toString() ?? '';
      if (userRole.isEmpty) {
        throw Exception('Role user tidak ditemukan');
      }

      if (!mounted) return;

      Navigator.pushReplacementNamed(context, '/$userRole');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login berhasil! Selamat datang sebagai ${_getRoleDisplayName(role)}',
          ),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        print('❌ Role selection error: $error');
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));

      setState(() {
        _isLoading = false;
        // Jangan reset _showRoleSelection agar user bisa memilih role lain
      });
    }
  }

  Widget _buildRoleSelection() {
    return Column(
      children: [
        SizedBox(height: 20),
        Text(
          'Pilih Role',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          'Halo ${_userData?['nama']},',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        Text(
          'Sekolah: ${_selectedSekolah?['nama_sekolah'] ?? _userData?['nama_sekolah']}',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: _roleList.length,
            itemBuilder: (context, index) {
              final role = _roleList[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                child: ListTile(
                  leading: _getRoleIcon(role),
                  title: Text(_getRoleDisplayName(role)),
                  subtitle: Text('Akses sebagai ${_getRoleDescription(role)}'),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectRole(role),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 20),
        TextButton(
          onPressed: () {
            setState(() {
              _showRoleSelection = false;
              _showSchoolSelection = true; // Kembali ke pemilihan sekolah
              _isLoading = false;
            });
          },
          child: Text('Kembali ke Pilih Sekolah'),
        ),
      ],
    );
  }

  Widget _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icon(Icons.admin_panel_settings, color: Colors.blue);
      case 'guru':
        return Icon(Icons.school, color: Colors.green);
      case 'wali':
        return Icon(Icons.family_restroom, color: Colors.purple);
      case 'staff':
        return Icon(Icons.work, color: Colors.orange);
      default:
        return Icon(Icons.person, color: Colors.grey);
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'guru':
        return 'Guru';
      case 'wali':
        return 'Wali Murid';
      case 'staff':
        return 'Staff';
      default:
        return role;
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'admin':
        return 'Pengelola sistem sekolah';
      case 'guru':
        return 'Pengajar dan pendidikan';
      case 'wali':
        return 'Orang tua/wali siswa';
      case 'staff':
        return 'Staff administrasi';
      default:
        return 'Pengguna sistem';
    }
  }

  Widget _buildSchoolSelection() {
    return Column(
      children: [
        SizedBox(height: 20),
        Text(
          'Pilih Sekolah',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 10),
        Text(
          'Halo ${_userData?['nama']}, silakan pilih sekolah:',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: _sekolahList.length,
            itemBuilder: (context, index) {
              final sekolah = _sekolahList[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                child: ListTile(
                  leading: Icon(Icons.school, color: Colors.blue),
                  title: Text(sekolah['nama_sekolah']),
                  subtitle: Text(sekolah['alamat'] ?? ''),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _selectSchool(sekolah['sekolah_id']),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 20),
        TextButton(
          onPressed: () {
            setState(() {
              _showSchoolSelection = false;
              _isLoading = false;
            });
          },
          child: Text('Kembali ke Login'),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.school, size: 80, color: Colors.blue),
        SizedBox(height: 20),
        Text(
          'Sistem Manajemen Sekolah',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),

        if (!_serverConnected) ...[
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Server tidak terhubung',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ],

        SizedBox(height: 30),
        TextField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 15),
        TextField(
          controller: passwordController,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock),
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          onSubmitted: (_) => login(),
        ),
        SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _serverConnected ? login : null,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text('LOGIN'),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[400]!, Colors.blue[800]!],
          ),
        ),
        child: Center(
          child: Card(
            margin: EdgeInsets.all(20),
            elevation: 8,
            child: Padding(
              padding: EdgeInsets.all(30),
              child: _showSchoolSelection
                  ? _buildSchoolSelection()
                  : _showRoleSelection
                  ? _buildRoleSelection()
                  : _buildLoginForm(),
            ),
          ),
        ),
      ),
    );
  }
}
