import 'package:flutter/material.dart';

class AdministrasiScreen extends StatelessWidget {
  const AdministrasiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Administrasi')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.all(16),
        children: [
          _buildAdminCard('Surat Masuk', Icons.mail_outline, () {}),
          _buildAdminCard('Surat Keluar', Icons.send, () {}),
          _buildAdminCard('Dokumen', Icons.folder, () {}),
          _buildAdminCard('Arsip', Icons.archive, () {}),
          _buildAdminCard('Ijazah', Icons.school, () {}),
          _buildAdminCard('Sertifikat', Icons.card_membership, () {}),
        ],
      ),
    );
  }

  Widget _buildAdminCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}