import 'package:flutter/material.dart';

/// A flexible search and filter component with separate styling
/// Allows different widths and colors for search bar and filter button
class SeparatedSearchFilter extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final String hintText;
  final bool showFilter;
  final bool hasActiveFilter;
  final VoidCallback? onFilterPressed;
  
  // Search bar styling
  final Color? searchBackgroundColor;
  final Color? searchIconColor;
  final Color? searchTextColor;
  final Color? searchHintColor;
  final double searchBorderRadius;
  final double? searchWidth; // null means Expanded
  
  // Filter button styling
  final Color? filterActiveColor;
  final Color? filterInactiveColor;
  final Color? filterIconColor;
  final double filterBorderRadius;
  final double? filterWidth; // Fixed width for filter button
  final double? filterHeight; // Fixed height for filter button (matches search bar if null)
  
  // Spacing
  final double spacing;
  
  // Container styling
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Color? containerColor;

  const SeparatedSearchFilter({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
    this.showFilter = true,
    this.hasActiveFilter = false,
    this.onFilterPressed,
    // Search styling
    this.searchBackgroundColor,
    this.searchIconColor,
    this.searchTextColor,
    this.searchHintColor,
    this.searchBorderRadius = 12,
    this.searchWidth,
    // Filter styling
    this.filterActiveColor,
    this.filterInactiveColor,
    this.filterIconColor,
    this.filterBorderRadius = 12,
    this.filterWidth,
    this.filterHeight,
    // Layout
    this.spacing = 8,
    this.margin,
    this.padding,
    this.containerColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveSearchBgColor = searchBackgroundColor ?? Colors.white;
    final effectiveSearchIconColor = searchIconColor ?? Colors.grey;
    final effectiveSearchTextColor = searchTextColor ?? Colors.black87;
    final effectiveSearchHintColor = searchHintColor ?? Colors.grey;
    
    final effectiveFilterActiveColor = filterActiveColor ?? Colors.green;
    final effectiveFilterInactiveColor = filterInactiveColor ?? Colors.green.withOpacity(0.8);
    final effectiveFilterIconColor = filterIconColor ?? Colors.white;

    Widget searchBar = Container(
      decoration: BoxDecoration(
        color: effectiveSearchBgColor,
        borderRadius: BorderRadius.circular(searchBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: effectiveSearchTextColor),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: effectiveSearchHintColor),
          prefixIcon: Icon(
            Icons.search,
            color: effectiveSearchIconColor,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );

    // Wrap search bar with width constraint if specified
    if (searchWidth != null) {
      searchBar = SizedBox(
        width: searchWidth,
        child: searchBar,
      );
    } else {
      searchBar = Expanded(child: searchBar);
    }

    Widget? filterButton;
    if (showFilter) {
      final buttonWidth = filterWidth ?? 48.0;
      final buttonHeight = filterHeight ?? 48.0;
      filterButton = Material(
        color: hasActiveFilter
            ? effectiveFilterActiveColor
            : effectiveFilterInactiveColor,
        borderRadius: BorderRadius.circular(filterBorderRadius),
        elevation: 2,
        shadowColor: (hasActiveFilter 
            ? effectiveFilterActiveColor 
            : effectiveFilterInactiveColor).withOpacity(0.3),
        child: InkWell(
          onTap: onFilterPressed,
          borderRadius: BorderRadius.circular(filterBorderRadius),
          child: SizedBox(
            width: buttonWidth,
            height: buttonHeight,
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    Icons.tune,
                    color: effectiveFilterIconColor,
                    size: 22,
                  ),
                ),
                if (hasActiveFilter)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding,
      decoration: containerColor != null
          ? BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      child: Row(
        children: [
          searchBar,
          if (showFilter) ...[
            SizedBox(width: spacing),
            filterButton!,
          ],
        ],
      ),
    );
  }
}
