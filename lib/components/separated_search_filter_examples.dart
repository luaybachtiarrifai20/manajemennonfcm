/// EXAMPLES: How to use SeparatedSearchFilter component
/// 
/// This file shows different usage examples of the SeparatedSearchFilter component
/// Copy the examples below to use in your pages

/*

// Example 1: Basic usage with default styling
SeparatedSearchFilter(
  controller: _searchController,
  onChanged: (value) => setState(() {}),
  hintText: 'Search...',
  showFilter: true,
  hasActiveFilter: _hasActiveFilter,
  onFilterPressed: _showFilterSheet,
)

// Example 2: Custom colors - Green theme
SeparatedSearchFilter(
  controller: _searchController,
  onChanged: (value) => setState(() {}),
  hintText: 'Search subjects...',
  showFilter: true,
  hasActiveFilter: _hasActiveFilter,
  onFilterPressed: _showFilterSheet,
  // Search bar styling
  searchBackgroundColor: Colors.white,
  searchIconColor: Colors.grey.shade600,
  searchTextColor: Colors.black87,
  searchHintColor: Colors.grey.shade400,
  searchBorderRadius: 14,
  // Filter button styling
  filterActiveColor: Colors.green.shade600,
  filterInactiveColor: Colors.green.shade100,
  filterIconColor: _hasActiveFilter ? Colors.white : Colors.green.shade600,
  filterBorderRadius: 14,
  filterWidth: 56,
  spacing: 12,
)

// Example 3: Different colors - Orange/Blue theme
SeparatedSearchFilter(
  controller: _searchController,
  onChanged: (value) => setState(() {}),
  hintText: 'Search classes...',
  showFilter: true,
  hasActiveFilter: _hasActiveFilter,
  onFilterPressed: _showFilterSheet,
  // Search bar - Blue accent
  searchBackgroundColor: Colors.blue.shade50,
  searchIconColor: Colors.blue.shade400,
  searchTextColor: Colors.black,
  searchHintColor: Colors.grey,
  searchBorderRadius: 12,
  // Filter button - Orange accent
  filterActiveColor: Colors.orange.shade600,
  filterInactiveColor: Colors.orange.shade100,
  filterIconColor: _hasActiveFilter ? Colors.white : Colors.orange.shade600,
  filterBorderRadius: 12,
  filterWidth: 52,
  spacing: 10,
)

// Example 4: Compact size with container background
SeparatedSearchFilter(
  controller: _searchController,
  onChanged: (value) => setState(() {}),
  hintText: 'Quick search...',
  showFilter: true,
  hasActiveFilter: _hasActiveFilter,
  onFilterPressed: _showFilterSheet,
  // Compact styling
  searchBorderRadius: 8,
  filterBorderRadius: 8,
  filterWidth: 44,
  spacing: 6,
  // Container with background
  containerColor: Colors.grey.shade100,
  margin: const EdgeInsets.all(12),
  padding: const EdgeInsets.all(8),
)

// Example 5: Large search bar with small filter button
SeparatedSearchFilter(
  controller: _searchController,
  onChanged: (value) => setState(() {}),
  hintText: 'Type to search...',
  showFilter: true,
  hasActiveFilter: _hasActiveFilter,
  onFilterPressed: _showFilterSheet,
  // Large search
  searchBorderRadius: 16,
  // Small filter
  filterWidth: 48,
  filterBorderRadius: 24, // Circular
  spacing: 16,
)

// Example 6: Without filter button (search only)
SeparatedSearchFilter(
  controller: _searchController,
  onChanged: (value) => setState(() {}),
  hintText: 'Search...',
  showFilter: false, // No filter button
  searchBackgroundColor: Colors.white,
  searchIconColor: Colors.grey,
  searchTextColor: Colors.black87,
  searchBorderRadius: 12,
)

// Example 7: Transparent background on gradient
SeparatedSearchFilter(
  controller: _searchController,
  onChanged: (value) => setState(() {}),
  hintText: 'Search...',
  showFilter: true,
  hasActiveFilter: _hasActiveFilter,
  onFilterPressed: _showFilterSheet,
  // Semi-transparent for gradient backgrounds
  searchBackgroundColor: Colors.white.withOpacity(0.9),
  searchIconColor: Colors.grey.shade700,
  filterActiveColor: Colors.purple.shade600,
  filterInactiveColor: Colors.white.withOpacity(0.8),
  filterIconColor: _hasActiveFilter ? Colors.white : Colors.purple.shade600,
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
)

// Example 8: Dark theme
SeparatedSearchFilter(
  controller: _searchController,
  onChanged: (value) => setState(() {}),
  hintText: 'Search...',
  showFilter: true,
  hasActiveFilter: _hasActiveFilter,
  onFilterPressed: _showFilterSheet,
  // Dark theme colors
  searchBackgroundColor: Colors.grey.shade800,
  searchIconColor: Colors.grey.shade400,
  searchTextColor: Colors.white,
  searchHintColor: Colors.grey.shade500,
  searchBorderRadius: 12,
  filterActiveColor: Colors.blue.shade700,
  filterInactiveColor: Colors.grey.shade700,
  filterIconColor: Colors.white,
  filterBorderRadius: 12,
)

*/
