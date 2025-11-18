import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'admin_rpp_screen.dart';

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  List<dynamic> _teachersList = [];
  List<dynamic> _filteredTeachersList = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final teachersData = await ApiTeacherService().getTeacher();

      setState(() {
        _teachersList = teachersData;
        _filteredTeachersList = teachersData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _filterTeachers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredTeachersList = _teachersList;
      } else {
        _filteredTeachersList = _teachersList.where((teacher) {
          final name = teacher['nama']?.toString().toLowerCase() ?? '';
          final nip = teacher['nip']?.toString().toLowerCase() ?? '';
          final subject = teacher['mata_pelajaran_nama']?.toString().toLowerCase() ?? '';
          
          return name.contains(query.toLowerCase()) ||
                 nip.contains(query.toLowerCase()) ||
                 subject.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _viewTeacherRPP(String teacherId, String teacherName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminRppScreen(
          teacherId: teacherId,
          teacherName: teacherName,
        ),
      ),
    );
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  Color _getSubjectColor(String? subject) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    
    final index = subject?.hashCode ?? 0;
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Kelola RPP - Daftar Guru',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadTeachers,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade300,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama guru, NIP, atau mata pelajaran...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: _filterTeachers,
            ),
          ),
          
          // Stats Info
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Chip(
                  backgroundColor: Colors.blue.shade100,
                  label: Text('Total: ${_teachersList.length} Guru'),
                ),
                SizedBox(width: 8),
                Chip(
                  backgroundColor: Colors.green.shade100,
                  label: Text('Aktif: ${_teachersList.length}'),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Teachers List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: Colors.red),
                            SizedBox(height: 16),
                            Text(
                              'Error: $_errorMessage',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.red),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadTeachers,
                              child: Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : _filteredTeachersList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Belum ada data guru'
                                      : 'Guru tidak ditemukan',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      _filterTeachers('');
                                    },
                                    child: Text('Reset Pencarian'),
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredTeachersList.length,
                            itemBuilder: (context, index) {
                              final teacher = _filteredTeachersList[index];
                              return Card(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getSubjectColor(
                                        teacher['mata_pelajaran_nama']),
                                    child: Text(
                                      teacher['nama']?.toString().substring(0, 1) ?? 'G',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    teacher['nama'] ?? 'Nama tidak tersedia',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (teacher['nip'] != null)
                                        Text('NIP: ${teacher['nip']}'),
                                      if (teacher['mata_pelajaran_nama'] != null)
                                        Text(
                                          'Mata Pelajaran: ${teacher['mata_pelajaran_nama']}',
                                          style: TextStyle(color: Colors.blue.shade700),
                                        ),
                                      if (teacher['email'] != null)
                                        Text(
                                          'Email: ${teacher['email']}',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                  onTap: () => _viewTeacherRPP(
                                    teacher['id'].toString(),
                                    teacher['nama'] ?? 'Guru',
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}