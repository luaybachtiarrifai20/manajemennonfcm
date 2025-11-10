import 'package:flutter/material.dart';
import 'package:manajemensekolah/data/data_dummy.dart';

class InventarisScreen extends StatelessWidget {

  const InventarisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inventaris')),
      body: ListView.builder(
        itemCount: DataDummy.inventaris.length,
        itemBuilder: (context, index) {
          final item = DataDummy.inventaris[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              leading: Icon(Icons.inventory_2, color: Colors.blue),
              title: Text(item['nama']),
              subtitle: Text('Jumlah: ${item['jumlah']}'),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item['kondisi'] == 'Baik' ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item['kondisi'],
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
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