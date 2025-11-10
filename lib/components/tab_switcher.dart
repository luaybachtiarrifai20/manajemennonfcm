// components/tab_switcher.dart
import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';

class TabSwitcher extends StatelessWidget {
  final TabController tabController;
  final List<TabItem> tabs;
  final Color? primaryColor;

  const TabSwitcher({
    Key? key,
    required this.tabController,
    required this.tabs,
    this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? ColorUtils.getRoleColor('guru');
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          return Expanded(
            child: _buildTabButton(index, tab, color),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabButton(int tabIndex, TabItem tab, Color primaryColor) {
    final isSelected = tabController.index == tabIndex;

    return Material(
      color: isSelected ? primaryColor.withOpacity(0.85) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          tabController.animateTo(tabIndex);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tab.icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TabItem {
  final String label;
  final IconData icon;

  TabItem({required this.label, required this.icon});
}