import 'dart:convert';

enum DashboardWidgetType {
  tasks,
  todayEvents,
  upcomingAssessments,
  gapSession;

  String get label => switch (this) {
        DashboardWidgetType.tasks => "Today's queue",
        DashboardWidgetType.todayEvents => "Today's events",
        DashboardWidgetType.upcomingAssessments => 'Upcoming assessments',
        DashboardWidgetType.gapSession => 'Gap session',
      };

  String get description => switch (this) {
        DashboardWidgetType.tasks => 'Check off and manage today’s tasks',
        DashboardWidgetType.todayEvents => 'Timed events scheduled for today',
        DashboardWidgetType.upcomingAssessments =>
          'Assessments coming up with progress',
        DashboardWidgetType.gapSession =>
          'Short review or consolidation in the next free gap',
      };

  static DashboardWidgetType? tryParse(String raw) {
    for (final v in DashboardWidgetType.values) {
      if (v.name == raw) return v;
    }
    return null;
  }
}

class DesktopRect {
  const DesktopRect({
    required this.col,
    required this.row,
    required this.colSpan,
    required this.rowSpan,
  });

  final int col;
  final int row;
  final int colSpan;
  final int rowSpan;

  DesktopRect copyWith({
    int? col,
    int? row,
    int? colSpan,
    int? rowSpan,
  }) {
    return DesktopRect(
      col: col ?? this.col,
      row: row ?? this.row,
      colSpan: colSpan ?? this.colSpan,
      rowSpan: rowSpan ?? this.rowSpan,
    );
  }

  Map<String, dynamic> toJson() => {
        'col': col,
        'row': row,
        'colSpan': colSpan,
        'rowSpan': rowSpan,
      };

  factory DesktopRect.fromJson(Map<String, dynamic> json) {
    return DesktopRect(
      col: (json['col'] as num?)?.toInt() ?? 0,
      row: (json['row'] as num?)?.toInt() ?? 0,
      colSpan: (json['colSpan'] as num?)?.toInt() ?? 3,
      rowSpan: (json['rowSpan'] as num?)?.toInt() ?? 2,
    );
  }

  bool overlaps(DesktopRect other) {
    final aRight = col + colSpan;
    final aBottom = row + rowSpan;
    final bRight = other.col + other.colSpan;
    final bBottom = other.row + other.rowSpan;
    return col < bRight &&
        aRight > other.col &&
        row < bBottom &&
        aBottom > other.row;
  }

  @override
  bool operator ==(Object other) {
    return other is DesktopRect &&
        other.col == col &&
        other.row == row &&
        other.colSpan == colSpan &&
        other.rowSpan == rowSpan;
  }

  @override
  int get hashCode => Object.hash(col, row, colSpan, rowSpan);
}

class DashboardLayoutConfig {
  DashboardLayoutConfig({
    required this.phoneRects,
    required this.desktopRects,
  });

  /// Free placement on phone grid for present widgets.
  Map<DashboardWidgetType, DesktopRect> phoneRects;

  /// Free placement on desktop grid for present widgets.
  Map<DashboardWidgetType, DesktopRect> desktopRects;

  static const int gridCols = 12;
  static const int gridRows = 8;
  static const int minColSpan = 3;
  static const int minRowSpan = 2;

  static Map<DashboardWidgetType, DesktopRect> defaultPhoneRects() => {
        DashboardWidgetType.gapSession: const DesktopRect(
          col: 0,
          row: 0,
          colSpan: 12,
          rowSpan: 2,
        ),
        DashboardWidgetType.tasks: const DesktopRect(
          col: 0,
          row: 2,
          colSpan: 12,
          rowSpan: 3,
        ),
        DashboardWidgetType.todayEvents: const DesktopRect(
          col: 0,
          row: 5,
          colSpan: 12,
          rowSpan: 3,
        ),
      };

  static Map<DashboardWidgetType, DesktopRect> defaultDesktopRects() => {
        DashboardWidgetType.gapSession: const DesktopRect(
          col: 0,
          row: 0,
          colSpan: 5,
          rowSpan: 2,
        ),
        DashboardWidgetType.tasks: const DesktopRect(
          col: 0,
          row: 2,
          colSpan: 5,
          rowSpan: 6,
        ),
        DashboardWidgetType.todayEvents: const DesktopRect(
          col: 8,
          row: 0,
          colSpan: 4,
          rowSpan: 4,
        ),
        DashboardWidgetType.upcomingAssessments: const DesktopRect(
          col: 8,
          row: 4,
          colSpan: 4,
          rowSpan: 4,
        ),
      };

  static DashboardLayoutConfig defaults() {
    return DashboardLayoutConfig(
      phoneRects: defaultPhoneRects(),
      desktopRects: defaultDesktopRects(),
    );
  }

  /// Migrate old phoneOrder list into stacked full-width rects.
  static Map<DashboardWidgetType, DesktopRect> rectsFromPhoneOrder(
    List<DashboardWidgetType> order,
  ) {
    if (order.isEmpty) return {};
    final span = (gridRows / order.length).floor().clamp(minRowSpan, gridRows);
    final map = <DashboardWidgetType, DesktopRect>{};
    var row = 0;
    for (var i = 0; i < order.length; i++) {
      final rowSpan = i == order.length - 1
          ? (gridRows - row).clamp(minRowSpan, gridRows)
          : span;
      map[order[i]] = DesktopRect(
        col: 0,
        row: row.clamp(0, gridRows - minRowSpan),
        colSpan: gridCols,
        rowSpan: rowSpan,
      );
      row += rowSpan;
      if (row >= gridRows) break;
    }
    return map;
  }

  List<DashboardWidgetType> missingForPhone() => DashboardWidgetType.values
      .where((t) => !phoneRects.containsKey(t))
      .toList();

  List<DashboardWidgetType> missingForDesktop() => DashboardWidgetType.values
      .where((t) => !desktopRects.containsKey(t))
      .toList();

  DashboardLayoutConfig copy() {
    return DashboardLayoutConfig(
      phoneRects: Map<DashboardWidgetType, DesktopRect>.from(phoneRects),
      desktopRects: Map<DashboardWidgetType, DesktopRect>.from(desktopRects),
    );
  }

  Map<String, dynamic> toJson() => {
        'phoneRects': {
          for (final e in phoneRects.entries) e.key.name: e.value.toJson(),
        },
        'desktopRects': {
          for (final e in desktopRects.entries) e.key.name: e.value.toJson(),
        },
      };

  static Map<DashboardWidgetType, DesktopRect> _parseRects(dynamic raw) {
    final out = <DashboardWidgetType, DesktopRect>{};
    if (raw is! Map) return out;
    for (final e in raw.entries) {
      final t = DashboardWidgetType.tryParse(e.key.toString());
      if (t == null) continue;
      final value = e.value;
      if (value is Map) {
        out[t] = DesktopRect.fromJson(Map<String, dynamic>.from(value));
      }
    }
    return out;
  }

  factory DashboardLayoutConfig.fromJson(Map<String, dynamic> json) {
    var phone = _parseRects(json['phoneRects']);
    final desktop = _parseRects(json['desktopRects']);

    // Back-compat: older saves used phoneOrder only.
    if (phone.isEmpty && json['phoneOrder'] is List) {
      final order = <DashboardWidgetType>[];
      for (final raw in json['phoneOrder'] as List) {
        final t = DashboardWidgetType.tryParse(raw.toString());
        if (t != null && !order.contains(t)) order.add(t);
      }
      phone = rectsFromPhoneOrder(order);
    }

    if (phone.isEmpty &&
        desktop.isEmpty &&
        !json.containsKey('phoneRects') &&
        !json.containsKey('desktopRects') &&
        !json.containsKey('phoneOrder')) {
      return DashboardLayoutConfig.defaults();
    }
    return DashboardLayoutConfig(phoneRects: phone, desktopRects: desktop);
  }

  String encode() => jsonEncode(toJson());

  static DashboardLayoutConfig decode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return DashboardLayoutConfig.fromJson(map);
      }
      if (map is Map) {
        return DashboardLayoutConfig.fromJson(Map<String, dynamic>.from(map));
      }
    } catch (_) {}
    return DashboardLayoutConfig.defaults();
  }

  DesktopRect? firstFreeRect(
    Map<DashboardWidgetType, DesktopRect> occupied, {
    int colSpan = 4,
    int rowSpan = 3,
  }) {
    colSpan = colSpan.clamp(minColSpan, gridCols);
    rowSpan = rowSpan.clamp(minRowSpan, gridRows);
    for (var row = 0; row <= gridRows - rowSpan; row++) {
      for (var col = 0; col <= gridCols - colSpan; col++) {
        final candidate = DesktopRect(
          col: col,
          row: row,
          colSpan: colSpan,
          rowSpan: rowSpan,
        );
        final hits = occupied.values.any((r) => r.overlaps(candidate));
        if (!hits) return candidate;
      }
    }
    return null;
  }

  /// Bounds + min-size only. Overlap is allowed when the user wants it.
  bool isValidRect(DesktopRect rect) {
    return rect.col >= 0 &&
        rect.row >= 0 &&
        rect.colSpan >= minColSpan &&
        rect.rowSpan >= minRowSpan &&
        rect.col + rect.colSpan <= gridCols &&
        rect.row + rect.rowSpan <= gridRows;
  }
}
