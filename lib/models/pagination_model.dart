class PaginationMeta {
  final int totalItems;
  final int totalPages;
  final int currentPage;
  final int perPage;
  final bool hasNextPage;
  final bool hasPrevPage;
  final int? nextPage;
  final int? prevPage;

  PaginationMeta({
    required this.totalItems,
    required this.totalPages,
    required this.currentPage,
    required this.perPage,
    required this.hasNextPage,
    required this.hasPrevPage,
    this.nextPage,
    this.prevPage,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      totalItems: json['total_items'] ?? 0,
      totalPages: json['total_pages'] ?? 0,
      currentPage: json['current_page'] ?? 1,
      perPage: json['per_page'] ?? 10,
      hasNextPage: json['has_next_page'] ?? false,
      hasPrevPage: json['has_prev_page'] ?? false,
      nextPage: json['next_page'],
      prevPage: json['prev_page'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_items': totalItems,
      'total_pages': totalPages,
      'current_page': currentPage,
      'per_page': perPage,
      'has_next_page': hasNextPage,
      'has_prev_page': hasPrevPage,
      'next_page': nextPage,
      'prev_page': prevPage,
    };
  }
}

class PaginatedResponse<T> {
  final bool success;
  final List<T> data;
  final PaginationMeta pagination;

  PaginatedResponse({
    required this.success,
    required this.data,
    required this.pagination,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PaginatedResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List).map((item) => fromJsonT(item)).toList(),
      pagination: PaginationMeta.fromJson(json['pagination']),
    );
  }

  Map<String, dynamic> toJson(Map<String, dynamic> Function(T) toJsonT) {
    return {
      'success': success,
      'data': data.map((item) => toJsonT(item)).toList(),
      'pagination': pagination.toJson(),
    };
  }
}
