import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';

class ClassFormDialog extends StatefulWidget {
  final bool isEditMode;
  final String initialName;
  final String? initialTeacherId;
  final int? initialGradeLevel;
  final List<dynamic> teachers;
  final List<int> gradeLevels;
  final Function(String, String?, int?) onSave;
  final VoidCallback onCancel;

  const ClassFormDialog({
    super.key,
    required this.isEditMode,
    required this.initialName,
    this.initialTeacherId,
    this.initialGradeLevel,
    required this.teachers,
    required this.gradeLevels,
    required this.onSave,
    required this.onCancel,
  });

  @override
  ClassFormDialogState createState() => ClassFormDialogState();
}

class ClassFormDialogState extends State<ClassFormDialog> {
  late final TextEditingController _nameController;
  late String? _selectedTeacherId;
  late int? _selectedGradeLevel;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _selectedTeacherId = widget.initialTeacherId;
    _selectedGradeLevel = widget.initialGradeLevel;
  }

  @override
  void didUpdateWidget(ClassFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialName != widget.initialName) {
      _nameController.text = widget.initialName;
    }
    if (oldWidget.initialTeacherId != widget.initialTeacherId) {
      _selectedTeacherId = widget.initialTeacherId;
    }
    if (oldWidget.initialGradeLevel != widget.initialGradeLevel) {
      _selectedGradeLevel = widget.initialGradeLevel;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final selectedTeacherId = _selectedTeacherId;
    final selectedGradeLevel = _selectedGradeLevel;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.classNameRequired.tr,
          ),
        ),
      );
      return;
    }

    if (selectedGradeLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.gradeLevelRequired.tr,
          ),
        ),
      );
      return;
    }

    widget.onSave(name, selectedTeacherId, selectedGradeLevel);
  }

  Color _getPrimaryColor() {
    return Color(0xFF4361EE); // Blue untuk admin
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header dengan gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPrimaryColor(),
                        _getPrimaryColor().withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.isEditMode ? Icons.edit : Icons.add,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.isEditMode
                              ? languageProvider.getTranslatedText({
                                  'en': 'Edit Class',
                                  'id': 'Edit Kelas',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'Add Class',
                                  'id': 'Tambah Kelas',
                                }),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: languageProvider.getTranslatedText({
                          'en': 'Class Name',
                          'id': 'Nama Kelas',
                        }),
                        icon: Icons.class_,
                      ),
                      SizedBox(height: 12),
                      _buildDropdown(
                        value: _selectedGradeLevel?.toString(),
                        label: languageProvider.getTranslatedText({
                          'en': 'Grade Level',
                          'id': 'Tingkat Kelas',
                        }),
                        icon: Icons.grade,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Select Grade Level',
                                'id': 'Pilih Tingkat Kelas',
                              }),
                            ),
                          ),
                          ...widget.gradeLevels.map((grade) {
                            return DropdownMenuItem(
                              value: grade.toString(),
                              child: Text('Grade $grade'),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedGradeLevel = value != null ? int.tryParse(value) : null;
                          });
                        },
                      ),
                      SizedBox(height: 12),
                      _buildDropdown(
                        value: _selectedTeacherId,
                        label: languageProvider.getTranslatedText({
                          'en': 'Homeroom Teacher',
                          'id': 'Wali Kelas',
                        }),
                        icon: Icons.person,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'No Teacher',
                                'id': 'Tidak Ada Wali Kelas',
                              }),
                            ),
                          ),
                          ...widget.teachers
                              .where((teacher) => teacher['id'] != null)
                              .map((teacher) {
                                return DropdownMenuItem<String>(
                                  value: teacher['id'].toString(),
                                  child: Text(teacher['nama'] ?? 'Unknown Teacher'),
                                );
                              })
                              .toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedTeacherId = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                // Actions
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onCancel,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            AppLocalizations.cancel.tr,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getPrimaryColor(),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            widget.isEditMode
                                ? languageProvider.getTranslatedText({
                                    'en': 'Update',
                                    'id': 'Perbarui',
                                  })
                                : AppLocalizations.save.tr,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hintText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _getPrimaryColor(), size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: items,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
    );
  }
}