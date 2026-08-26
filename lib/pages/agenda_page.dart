import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/agenda_service.dart';
import '../ui/shared_ui.dart';

const _firstHour = 6;
const _lastHour = 22;
const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _agendaSidePhotoAsset = 'agenda_photo/pexels-photo-2409038.jpeg';
/// Share of panel width used for the image (gutters added on top).
const _sidePhotoWidthFraction = 0.32;
const _sidePhotoWidthMin = 200.0;
const _sidePhotoWidthMax = 460.0;
const _sidePhotoMinPanelWidth = 720.0;

class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key, required this.panelOpacity, required this.agendaService});

  final double panelOpacity;
  final AgendaService agendaService;

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> {
  late DateTime _weekMonday;
  int? _expandedDayIndex;

  @override
  void initState() {
    super.initState();
    _weekMonday = AgendaService.mondayOf(DateTime.now());
  }

  String get _weekKey => widget.agendaService.weekKeyFromMonday(_weekMonday);

  List<int> get _visibleDayIndices {
    if (_expandedDayIndex != null) return [_expandedDayIndex!];
    return List<int>.generate(7, (i) => i);
  }

  String _weekRangeText() {
    final mon = _weekMonday;
    final sun = mon.add(const Duration(days: 6));
    const mNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (mon.month == sun.month) {
      return '${mon.day}–${sun.day} ${mNames[mon.month - 1]} ${mon.year}';
    }
    return '${mon.day} ${mNames[mon.month - 1]} – ${sun.day} ${mNames[sun.month - 1]} ${sun.year}';
  }

  static String _hourLabel(int hour) {
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  void _shiftWeek(int deltaWeeks) {
    setState(() {
      _weekMonday = _weekMonday.add(Duration(days: 7 * deltaWeeks));
    });
  }

  Future<void> _confirmDeleteItem(String slotKey, AgendaSlotItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1411),
        title: const Text('Delete this item?'),
        content: Text(item.title, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await widget.agendaService.removeSlotItem(
        weekKey: _weekKey,
        slotKey: slotKey,
        itemId: item.id,
      );
    }
  }

  Future<void> _promptAddItem(int dayIndex, int hour) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1411),
        title: const Text('Add to this hour'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'What are you planning?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      await widget.agendaService.addSlotItem(
        weekKey: _weekKey,
        dayIndex: dayIndex,
        hour: hour,
        title: controller.text.trim(),
      );
    }
    controller.dispose();
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
      ),
      children: [
        const SizedBox(
          height: 48,
          child: Center(
            child: Text('', style: TextStyle(fontSize: 10)),
          ),
        ),
        ..._visibleDayIndices.map((dayIndex) {
          final d = _weekMonday.add(Duration(days: dayIndex));
          final tapExpand = _expandedDayIndex == null;
          return GestureDetector(
            onTap: tapExpand ? () => setState(() => _expandedDayIndex = dayIndex) : null,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayLabels[dayIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: tapExpand ? const Color(0xFF2AD08F) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${d.day}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _itemRow(String slotKey, AgendaSlotItem item, {required bool showDelete}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: item.done,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (v) {
                if (v == null) return;
                widget.agendaService.setSlotItemDone(
                  weekKey: _weekKey,
                  slotKey: slotKey,
                  itemId: item.id,
                  done: v,
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                item.title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  decoration: item.done ? TextDecoration.lineThrough : null,
                  color: item.done ? Colors.white54 : Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
          ),
          if (showDelete)
            IconButton(
              iconSize: 18,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: Icon(Icons.delete_outline, color: Colors.white.withValues(alpha: 0.45)),
              onPressed: () => _confirmDeleteItem(slotKey, item),
              tooltip: 'Delete',
            ),
        ],
      ),
    );
  }

  Widget _hourCell(Map<String, List<AgendaSlotItem>> slots, int dayIndex, int hour) {
    final slotKey = '${dayIndex}_$hour';
    final items = slots[slotKey] ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        color: Colors.black.withValues(alpha: 0.12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              iconSize: 18,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: Icon(Icons.add_circle_outline, color: Colors.white.withValues(alpha: 0.5)),
              onPressed: () => _promptAddItem(dayIndex, hour),
              tooltip: 'Add',
            ),
          ),
          if (items.isEmpty)
            SizedBox(height: _expandedDayIndex != null ? 8 : 4)
          else
            ...items.map((item) => _itemRow(slotKey, item, showDelete: _expandedDayIndex != null)),
        ],
      ),
    );
  }

  Widget _buildTable(Map<String, List<AgendaSlotItem>> slots, {required double gridWidth}) {
    final usableW = math.max(200.0, gridWidth);
    final timeCol = 44.0;
    final dayColW = _expandedDayIndex != null
        ? math.max(160.0, usableW - timeCol - 8)
        : math.max(96.0, math.min(130.0, (usableW - timeCol) / 7));

    final colCount = _visibleDayIndices.length + 1;
    final Map<int, TableColumnWidth> columnWidths = {
      0: FixedColumnWidth(timeCol),
    };
    for (var i = 1; i < colCount; i++) {
      columnWidths[i] = FixedColumnWidth(dayColW);
    }

    final rows = <TableRow>[
      _buildHeaderRow(),
    ];

    for (var hour = _firstHour; hour <= _lastHour; hour++) {
      rows.add(
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Text(
                _hourLabel(hour),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
            ..._visibleDayIndices.map((dayIndex) => _hourCell(slots, dayIndex, hour)),
          ],
        ),
      );
    }

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: FixedColumnWidth(dayColW),
            columnWidths: columnWidths,
            children: rows,
          ),
        ),
      ),
    );
  }

  double _sidePhotoImageWidth(double panelInnerWidth) {
    final w = panelInnerWidth * _sidePhotoWidthFraction;
    return w.clamp(_sidePhotoWidthMin, _sidePhotoWidthMax);
  }

  Widget _agendaSidePhoto({required double width, required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          _agendaSidePhotoAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, Object error, StackTrace? stackTrace) {
            return Container(
              width: width,
              height: height,
              color: Colors.white.withValues(alpha: 0.06),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              child: Text(
                'Add the image at agenda_photo/pexels-photo-2409038.jpeg',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45)),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _gridAndOptionalPhoto(Map<String, List<AgendaSlotItem>> slots, double panelInnerWidth) {
    final showSidePhoto =
        _expandedDayIndex == null && panelInnerWidth >= _sidePhotoMinPanelWidth;
    final gap = 14.0;
    final photoW = _sidePhotoImageWidth(panelInnerWidth);
    final sideColumnWidth = showSidePhoto ? photoW + gap * 2 : 0.0;
    final reserved = sideColumnWidth;
    final gridW = math.max(200.0, panelInnerWidth - reserved);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildTable(slots, gridWidth: gridW),
        ),
        if (showSidePhoto)
          LayoutBuilder(
            builder: (context, cons) {
              final h = cons.maxHeight.isFinite
                  ? cons.maxHeight.clamp(180.0, 2000.0)
                  : 480.0;
              return SizedBox(
                width: sideColumnWidth,
                child: Center(
                  child: _agendaSidePhoto(width: photoW, height: h),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_expandedDayIndex != null)
                  IconButton(
                    onPressed: () => setState(() => _expandedDayIndex = null),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'All days',
                  ),
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Agenda',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1),
                      ),
                      if (_expandedDayIndex != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '· ${_dayLabels[_expandedDayIndex!]}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftWeek(-1),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous week',
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: GreenChip(_weekRangeText()),
                ),
                IconButton(
                  onPressed: () => _shiftWeek(1),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next week',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _expandedDayIndex == null
                  ? 'Scroll to browse the week. Tap a day above to focus that column.'
                  : 'Back arrow returns to the full week.',
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FrostPanel(
                opacity: widget.panelOpacity,
                padding: const EdgeInsets.all(12),
                child: StreamBuilder<Map<String, List<AgendaSlotItem>>>(
                  stream: widget.agendaService.streamWeek(_weekKey),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Could not load agenda: ${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return _gridAndOptionalPhoto(snap.data ?? {}, constraints.maxWidth);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
