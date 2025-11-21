import 'package:flutter/material.dart';
import 'package:manajemensekolah/data/data_dummy.dart';
import 'package:manajemensekolah/models/siswa.dart';

class DataSiswaScreen extends StatelessWidget {
  const DataSiswaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Data Siswa')),
      body: ListView.builder(
        itemCount: DataDummy.siswa.length,
        itemBuilder: (context, index) {
          final siswa = DataDummy.siswa[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              leading: CircleAvatar(child: Text(siswa.nama[0])),
              title: Text(siswa.nama),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NIS: ${siswa.nis}'),
                  Text('Kelas: ${siswa.kelas}'),
                  Text('Wali: ${siswa.nameParent}'),
                  Text('Alamat: ${siswa.alamat}'),
                ],
              ),
              trailing: IconButton(
                icon: Icon(Icons.info),
                onPressed: () => _showDetailSiswa(context, siswa),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDetailSiswa(BuildContext context, Siswa siswa) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detail ${siswa.nama}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NIS: ${siswa.nis}'),
            Text('Kelas: ${siswa.kelas}'),
            Text('Alamat: ${siswa.alamat}'),
            Text('Nama Wali: ${siswa.nameParent}'),
            Text('No. Telepon: ${siswa.noTelepon}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
