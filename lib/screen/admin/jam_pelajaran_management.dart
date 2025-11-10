import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';

class JamPelajaranManagementScreen extends StatefulWidget {
  const JamPelajaranManagementScreen({super.key});

  @override
  JamPelajaranManagementScreenState createState() =>
      JamPelajaranManagementScreenState();
}

class JamPelajaranManagementScreenState
    extends State<JamPelajaranManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _jamMulaiController = TextEditingController();
  final TextEditingController _jamSelesaiController = TextEditingController();
  final TextEditingController _jamKeController = TextEditingController();

  List<dynamic> _jamPelajaranList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJamPelajaran();
  }

  Future<void> _loadJamPelajaran() async {
    try {
      final jamPelajaran = await ApiScheduleService.getJamPelajaran();
      setState(() {
        _jamPelajaranList = jamPelajaran;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading jam pelajaran: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addJamPelajaran() async {
    if (_formKey.currentState!.validate()) {
      try {
        final data = {
          'jam_ke': int.parse(_jamKeController.text),
          'jam_mulai': _jamMulaiController.text,
          'jam_selesai': _jamSelesaiController.text,
        };

        await ApiScheduleService.addJamPelajaran(data);

        // Reset form
        _jamKeController.clear();
        _jamMulaiController.clear();
        _jamSelesaiController.clear();

        // Reload data
        _loadJamPelajaran();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Jam pelajaran berhasil ditambahkan'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambah jam pelajaran: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Management Jam Pelajaran',
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
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade300),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Form Tambah Jam Pelajaran
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tambah Jam Pelajaran',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    controller: _jamKeController,
                                    decoration: InputDecoration(
                                      labelText: 'Jam Ke',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Jam ke harus diisi';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _jamMulaiController,
                                    decoration: InputDecoration(
                                      labelText: 'Jam Mulai (HH:MM)',
                                      border: OutlineInputBorder(),
                                      hintText: '07:00',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Jam mulai harus diisi';
                                      }
                                      if (!RegExp(
                                        r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$',
                                      ).hasMatch(value)) {
                                        return 'Format jam tidak valid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _jamSelesaiController,
                                    decoration: InputDecoration(
                                      labelText: 'Jam Selesai (HH:MM)',
                                      border: OutlineInputBorder(),
                                      hintText: '08:30',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Jam selesai harus diisi';
                                      }
                                      if (!RegExp(
                                        r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$',
                                      ).hasMatch(value)) {
                                        return 'Format jam tidak valid';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _addJamPelajaran,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF4F46E5),
                                minimumSize: Size(double.infinity, 50),
                              ),
                              child: Text('Tambah Jam Pelajaran'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // List Jam Pelajaran
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daftar Jam Pelajaran',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 16),
                            Expanded(
                              child: _jamPelajaranList.isEmpty
                                  ? Center(
                                      child: Text('Belum ada jam pelajaran'),
                                    )
                                  : ListView.builder(
                                      itemCount: _jamPelajaranList.length,
                                      itemBuilder: (context, index) {
                                        final jam = _jamPelajaranList[index];
                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: Color(0xFF4F46E5),
                                            child: Text(
                                              jam['jam_ke'].toString(),
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            'Jam Ke-${jam['jam_ke']}',
                                          ),
                                          subtitle: Text(
                                            '${jam['jam_mulai']} - ${jam['jam_selesai']}',
                                          ),
                                          trailing: Icon(Icons.schedule),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
