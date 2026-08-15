/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// table_models.dart` — PARTIAL PORT. `TablePage`/`RestaurantTable` only
/// (needed to search/select a table for a sale). `TableStats`,
/// `TableCreateRequest`, `TableUpdateRequest` (admin CRUD/dashboard, out
/// of scope) are not ported.
class TablePage {
  final List<RestaurantTable> content;
  final int number;
  final int size;
  final int totalElements;
  final int totalPages;

  TablePage({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  /// The backend's `TablePageResponse` serializes the page index as
  /// `"page"` (its Java field name), not `"number"` — reading the wrong
  /// key here made this throw a null-cast error on every table search (a
  /// real bug already fixed in source; ported with the fix already in
  /// place, not reintroduced).
  factory TablePage.fromJson(Map<String, dynamic> json) => TablePage(
        content: (json['content'] as List<dynamic>)
            .map((e) => RestaurantTable.fromJson(e as Map<String, dynamic>))
            .toList(),
        number: (json['page'] as int?) ?? 0,
        size: (json['size'] as int?) ?? 0,
        totalElements: (json['totalElements'] as int?) ?? 0,
        totalPages: (json['totalPages'] as int?) ?? 0,
      );

  static TablePage sample() => TablePage(
        content: [RestaurantTable.sample()],
        number: 0,
        size: 1,
        totalElements: 1,
        totalPages: 1,
      );
}

class RestaurantTable {
  String get displayText => displayName;
  final int id;
  final String tableNumber;
  final String displayName;
  final String status;
  final int capacity;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? section;
  final String? notes;

  RestaurantTable({
    required this.id,
    required this.tableNumber,
    required this.displayName,
    required this.status,
    required this.capacity,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.section,
    this.notes,
  });

  /// Helper to copy with minimal fields; used when only tableName is known
  /// (e.g. `TableSelectionNotifier`'s device-local cache, which stores just
  /// a name string).
  RestaurantTable copyWith({
    int? id,
    String? tableNumber,
    String? displayName,
    String? status,
    int? capacity,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? section,
    String? notes,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      capacity: capacity ?? this.capacity,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      section: section ?? this.section,
      notes: notes ?? this.notes,
    );
  }

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    final tableNumber = json['tableNumber'] as String;
    return RestaurantTable(
      id: json['id'] as int,
      displayName: (json['displayName'] as String?)?.isNotEmpty == true
          ? json['displayName'] as String
          : tableNumber,
      tableNumber: tableNumber,
      status: json['status'] as String,
      capacity: json['capacity'] as int,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      section: json['section'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tableNumber': tableNumber,
        'displayName': displayName,
        'status': status,
        'capacity': capacity,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'section': section,
        'notes': notes,
      };

  static RestaurantTable sample() => RestaurantTable(
        id: 1,
        tableNumber: 'A1',
        displayName: 'Table A1',
        status: 'available',
        capacity: 4,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        section: 'Main',
      );
}
