import 'package:flutter/material.dart';

Widget buildDashboardCard(String title, IconData icon, VoidCallback onTap, Color color) {
  return Card(
    elevation: 4,
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 50, color: color),
          SizedBox(height: 10),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}