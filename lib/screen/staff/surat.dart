import 'package:flutter/material.dart';

class SuratMenyuratScreen extends StatelessWidget {
  final List<Map<String, dynamic>> surat = [
    {
      'judul': 'Surat Undangan Rapat Guru',
      'tanggal': '2024-01-15',
      'status': 'Terkirim',
      'jenis': 'Keluar',
    },
    {
      'judul': 'Surat Permohonan Izin Kegiatan',
      'tanggal': '2024-01-12',
      'status': 'Diterima',
      'jenis': 'Masuk',
    },
    {
      'judul': 'Surat Edaran Libur Semester',
      'tanggal': '2024-01-10',
      'status': 'Terkirim',
      'jenis': 'Keluar',
    },
  ];
  
  SuratMenyuratScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Surat Menyurat')),
      body: ListView.builder(
        itemCount: surat.length,
        itemBuilder: (context, index) {
          final item = surat[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              leading: Icon(
                item['jenis'] == 'Masuk' ? Icons.mail : Icons.send,
                color: item['jenis'] == 'Masuk' ? Colors.green : Colors.blue,
              ),
              title: Text(item['judul']),
              subtitle: Text('${item['tanggal']} - ${item['jenis']}'),
              trailing: Chip(
                label: Text(item['status']),
                backgroundColor: item['status'] == 'Terkirim'
                    ? Colors.blue[100]
                    : Colors.green[100],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.add),
      ),
    );
  }
}
