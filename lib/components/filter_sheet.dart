// components/filter_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:manajemensekolah/utils/color_utils.dart';

class FilterSheet extends StatefulWidget {
  final FilterConfig config;
  final Map<String, dynamic> initialFilters;
  final Function(Map<String, dynamic>) onApplyFilters;
  final Color? primaryColor;

  const FilterSheet({
    Key? key,
    required this.config,
    required this.initialFilters,
    required this.onApplyFilters,
    this.primaryColor,
  }) : super(key: key);

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late Map<String, dynamic> _currentFilters;

  @override
  void initState() {
    super.initState();
    _currentFilters = Map.from(widget.initialFilters);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final primaryColor = widget.primaryColor ?? ColorUtils.getRoleColor("guru");

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Filter',
                    'id': 'Filter',
                  }),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _resetAllFilters,
                  child: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Reset',
                      'id': 'Reset',
                    }),
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ],
            ),
          ),

          // Filter Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.config.sections.map((section) {
                  return _buildFilterSection(section, primaryColor);
                }).toList(),
              ),
            ),
          ),

          // Apply Button
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: primaryColor),
                    ),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Cancel',
                        'id': 'Batal',
                      }),
                      style: TextStyle(color: primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApplyFilters(_currentFilters);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: primaryColor,
                    ),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Apply',
                        'id': 'Terapkan',
                      }),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(FilterSection section, Color primaryColor) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              section.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              alignment: WrapAlignment.start,
              runAlignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              spacing: 8,
              runSpacing: 8,
              children: section.options.map((option) {
                final isSelected = _isOptionSelected(section.key, option.value);
                return FilterChip(
                  label: Text(option.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    _toggleOption(section.key, option.value, selected);
                  },
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: primaryColor.withOpacity(0.2),
                  checkmarkColor: primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? primaryColor : Colors.grey.shade700,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  bool _isOptionSelected(String sectionKey, dynamic optionValue) {
    final currentValue = _currentFilters[sectionKey];
    if (currentValue == null) return false;

    if (currentValue is List) {
      return currentValue.contains(optionValue);
    } else {
      return currentValue == optionValue;
    }
  }

  void _toggleOption(String sectionKey, dynamic optionValue, bool selected) {
    setState(() {
      final currentValue = _currentFilters[sectionKey];
      
      if (currentValue is List) {
        final List<dynamic> list = List.from(currentValue);
        if (selected) {
          list.add(optionValue);
        } else {
          list.remove(optionValue);
        }
        _currentFilters[sectionKey] = list;
      } else {
        _currentFilters[sectionKey] = selected ? optionValue : null;
      }
    });
  }

  void _resetAllFilters() {
    setState(() {
      _currentFilters.clear();
    });
  }
}

class FilterConfig {
  final List<FilterSection> sections;

  FilterConfig({required this.sections});
}

class FilterSection {
  final String key;
  final String title;
  final List<FilterOption> options;
  final bool multiSelect;

  FilterSection({
    required this.key,
    required this.title,
    required this.options,
    this.multiSelect = false,
  });
}

class FilterOption {
  final String label;
  final dynamic value;

  FilterOption({required this.label, required this.value});
}