import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manajemensekolah/utils/language_utils.dart';

class ConflictResolutionDialog extends StatefulWidget {
  final List<dynamic> conflictingSchedules;
  final Function(String) onDeleteConfirmed;
  final Function() onCancel;

  const ConflictResolutionDialog({
    super.key,
    required this.conflictingSchedules,
    required this.onDeleteConfirmed,
    required this.onCancel,
  });

  @override
  ConflictResolutionDialogState createState() => ConflictResolutionDialogState();
}

class ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  String? _selectedScheduleToDelete;

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Schedule Conflict Detected',
                          'id': 'Terdeteksi Jadwal Bentrok',
                        }),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                // Description
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'The following schedules conflict with each other. Please select one to delete:',
                    'id': 'Jadwal berikut bentrok satu sama lain. Pilih salah satu untuk dihapus:',
                  }),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                
                SizedBox(height: 20),
                
                // List of conflicting schedules
                Container(
                  constraints: BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.conflictingSchedules.length,
                    itemBuilder: (context, index) {
                      final schedule = widget.conflictingSchedules[index];
                      return _buildScheduleItem(schedule, languageProvider);
                    },
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          AppLocalizations.cancel.tr,
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedScheduleToDelete != null
                            ? () => widget.onDeleteConfirmed(_selectedScheduleToDelete!)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedScheduleToDelete != null 
                              ? Colors.red.shade600 
                              : Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Delete Selected',
                            'id': 'Hapus yang Dipilih',
                          }),
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleItem(dynamic schedule, LanguageProvider languageProvider) {
    final isSelected = _selectedScheduleToDelete == schedule['id'];
    
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.red.shade400 : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isSelected ? Colors.red.shade50 : Colors.white,
      ),
      child: RadioListTile<String>(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              schedule['mata_pelajaran_nama'] ?? 'No Subject',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${languageProvider.getTranslatedText({
                'en': 'Teacher',
                'id': 'Guru',
              })}: ${schedule['guru_nama'] ?? 'No Teacher'}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            SizedBox(height: 2),
            Text(
              '${languageProvider.getTranslatedText({
                'en': 'Class',
                'id': 'Kelas',
              })}: ${schedule['kelas_nama'] ?? 'No Class'}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            SizedBox(height: 2),
            Text(
              '${languageProvider.getTranslatedText({
                'en': 'Time',
                'id': 'Waktu',
              })}: ${schedule['jam_mulai']?.toString().substring(0, 5) ?? ''} - ${schedule['jam_selesai']?.toString().substring(0, 5) ?? ''}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        value: schedule['id'],
        groupValue: _selectedScheduleToDelete,
        onChanged: (value) {
          setState(() {
            _selectedScheduleToDelete = value;
          });
        },
        activeColor: Colors.red.shade600,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}