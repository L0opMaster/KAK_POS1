/// Represents a paginated response for restaurant tables.
class TablePage {
  /// List of tables in the current page.
  final List<RestaurantTable> content;

  /// Current page number.
  final int number;

  /// Page size.
  final int size;

  /// Total number of elements.
  final int totalElements;

  /// Total number of pages.
  final int totalPages;

  TablePage({
    required this.content,
    required this.number,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  /// Creates a TablePage from JSON.
  ///
  /// The backend's `TablePageResponse` serializes the page index as
  /// `"page"` (its Java field name), not `"number"` — reading the wrong
  /// key here made this throw a null-cast error on every table search.
  factory TablePage.fromJson(Map<String, dynamic> json) => TablePage(
        content: (json['content'] as List<dynamic>)
            .map((e) => RestaurantTable.fromJson(e as Map<String, dynamic>))
            .toList(),
        number: (json['page'] as int?) ?? 0,
        size: (json['size'] as int?) ?? 0,
        totalElements: (json['totalElements'] as int?) ?? 0,
        totalPages: (json['totalPages'] as int?) ?? 0,
      );

  /// Converts TablePage to JSON.
  Map<String, dynamic> toJson() => {
        'content': content.map((e) => e.toJson()).toList(),
        'number': number,
        'size': size,
        'totalElements': totalElements,
        'totalPages': totalPages,
      };

  /// Sample data for testing.
  static TablePage sample() => TablePage(
        content: [RestaurantTable.sample()],
        number: 0,
        size: 1,
        totalElements: 1,
        totalPages: 1,
      );
}

/// Statistics for tables in the restaurant.
class TableStats {
  final int totalTables;
  final int activeTables;
  final int availableTables;
  final int occupiedTables;
  final int reservedTables;

  const TableStats({
    required this.totalTables,
    required this.activeTables,
    required this.availableTables,
    required this.occupiedTables,
    required this.reservedTables,
  });

  /// Creates TableStats from JSON.
  factory TableStats.fromJson(Map<String, dynamic> json) => TableStats(
        totalTables: json['totalTables'] as int,
        activeTables: json['activeTables'] as int,
        availableTables: json['availableTables'] as int,
        occupiedTables: json['occupiedTables'] as int,
        reservedTables: json['reservedTables'] as int,
      );

  /// Converts TableStats to JSON.
  Map<String, dynamic> toJson() => {
        'totalTables': totalTables,
        'activeTables': activeTables,
        'availableTables': availableTables,
        'occupiedTables': occupiedTables,
        'reservedTables': reservedTables,
      };

  /// Sample data for testing.
  static TableStats sample() => TableStats(
        totalTables: 10,
        activeTables: 8,
        availableTables: 5,
        occupiedTables: 3,
        reservedTables: 2,
      );
}

/// Represents a restaurant table.
class RestaurantTable {
  /// Display text for the table.
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

  /// Helper to copy with minimal fields; used when only tableName is known.
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

  /// Creates RestaurantTable from JSON.
  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    final tableNumber = json['tableNumber'] as String;
    return RestaurantTable(
      id: json['id'] as int,
      tableNumber: tableNumber,
      // displayName is optional server-side (backend `display_name` column
      // has no default) — fall back to the table number, matching what
      // the create form's "leave blank to use the table number" hint
      // promises but the backend itself doesn't enforce.
      displayName: (json['displayName'] as String?)?.isNotEmpty == true
          ? json['displayName'] as String
          : tableNumber,
      status: json['status'] as String,
      capacity: json['capacity'] as int,
      isActive: json['isActive'] as bool,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
              DateTime.now(),
      section: json['section'] as String?,
      notes: json['notes'] as String?,
    );
  }

  /// Converts RestaurantTable to JSON.
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

  /// Sample data for testing.
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

/// Request payload to create a new restaurant table.
class TableCreateRequest {
  final String tableNumber;
  final String? displayName;
  final int capacity;
  final String? section;
  final String? notes;

  TableCreateRequest({
    required this.tableNumber,
    this.displayName,
    required this.capacity,
    this.section,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'tableNumber': tableNumber,
        if (displayName != null) 'displayName': displayName,
        'capacity': capacity,
        if (section != null) 'section': section,
        if (notes != null) 'notes': notes,
      };
}

/// Request payload to update an existing restaurant table.
/// The table number itself cannot be changed after creation (backend
/// constraint — TableUpdateRequest has no tableNumber field).
class TableUpdateRequest {
  final String? displayName;
  final int capacity;
  final String? section;
  final String? notes;
  final String? status;
  final bool? isActive;

  TableUpdateRequest({
    this.displayName,
    required this.capacity,
    this.section,
    this.notes,
    this.status,
    this.isActive,
  });

  Map<String, dynamic> toJson() => {
        if (displayName != null) 'displayName': displayName,
        'capacity': capacity,
        if (section != null) 'section': section,
        if (notes != null) 'notes': notes,
        if (status != null) 'status': status,
        if (isActive != null) 'isActive': isActive,
      };
}
