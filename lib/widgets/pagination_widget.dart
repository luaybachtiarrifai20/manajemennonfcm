import 'package:flutter/material.dart';
import 'package:manajemensekolah/models/pagination_model.dart';

class PaginationWidget extends StatelessWidget {
  final PaginationMeta pagination;
  final Function(int) onPageChanged;
  final bool isLoading;
  final Color? primaryColor;

  const PaginationWidget({
    super.key,
    required this.pagination,
    required this.onPageChanged,
    this.isLoading = false,
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = primaryColor ?? Theme.of(context).primaryColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Menampilkan ${_getStartItem()} - ${_getEndItem()} dari ${pagination.totalItems}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                if (pagination.totalPages > 1)
                  Text(
                    'Halaman ${pagination.currentPage} dari ${pagination.totalPages}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),

          // Controls
          Row(
            children: [
              // First Page Button (if not on first page)
              if (pagination.currentPage > 2)
                _buildPageButton(
                  icon: Icons.first_page,
                  onPressed: isLoading ? null : () => onPageChanged(1),
                  color: color,
                ),

              SizedBox(width: 4),

              // Previous Button
              _buildPageButton(
                icon: Icons.chevron_left,
                onPressed: pagination.hasPrevPage && !isLoading
                    ? () => onPageChanged(pagination.prevPage!)
                    : null,
                color: color,
              ),

              SizedBox(width: 8),

              // Page Info
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 40,
                        height: 16,
                        child: Center(
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ),
                      )
                    : Text(
                        '${pagination.currentPage}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
              ),

              SizedBox(width: 8),

              // Next Button
              _buildPageButton(
                icon: Icons.chevron_right,
                onPressed: pagination.hasNextPage && !isLoading
                    ? () => onPageChanged(pagination.nextPage!)
                    : null,
                color: color,
              ),

              SizedBox(width: 4),

              // Last Page Button (if not on last page)
              if (pagination.currentPage < pagination.totalPages - 1)
                _buildPageButton(
                  icon: Icons.last_page,
                  onPressed:
                      isLoading ? null : () => onPageChanged(pagination.totalPages),
                  color: color,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onPressed,
      color: onPressed != null ? color : Colors.grey.shade300,
      splashRadius: 20,
      padding: EdgeInsets.all(8),
      constraints: BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ),
    );
  }

  int _getStartItem() {
    if (pagination.totalItems == 0) return 0;
    return ((pagination.currentPage - 1) * pagination.perPage) + 1;
  }

  int _getEndItem() {
    final calculated = pagination.currentPage * pagination.perPage;
    return calculated > pagination.totalItems
        ? pagination.totalItems
        : calculated;
  }
}

// Compact version for smaller spaces
class CompactPaginationWidget extends StatelessWidget {
  final PaginationMeta pagination;
  final Function(int) onPageChanged;
  final bool isLoading;

  const CompactPaginationWidget({
    super.key,
    required this.pagination,
    required this.onPageChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, size: 18),
            onPressed: pagination.hasPrevPage && !isLoading
                ? () => onPageChanged(pagination.prevPage!)
                : null,
            padding: EdgeInsets.all(4),
            constraints: BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          Text(
            '${pagination.currentPage} / ${pagination.totalPages}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, size: 18),
            onPressed: pagination.hasNextPage && !isLoading
                ? () => onPageChanged(pagination.nextPage!)
                : null,
            padding: EdgeInsets.all(4),
            constraints: BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}
