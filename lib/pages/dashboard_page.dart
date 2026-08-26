import 'package:flutter/material.dart';

import '../models/dashboard_layout.dart';
import '../models/models.dart';
import '../services/dashboard_layout_service.dart';
import '../ui/shared_ui.dart';
import '../utils/datetime_utils.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.backgroundAsset,
    required this.panelOpacity,
    required this.tasks,
    required this.todayEvents,
    required this.upcomingAssessments,
    required this.onToggleTask,
    required this.onAddTask,
    required this.onRemoveTask,
    required this.onOpenAssessments,
    required this.onOpacityChanged,
    this.gapSessionPanel,
  });

  final String backgroundAsset;
  final double panelOpacity;
  final List<TaskItem> tasks;
  final List<AppEvent> todayEvents;
  final List<Assessment> upcomingAssessments;

  final void Function(int index) onToggleTask;
  final VoidCallback onAddTask;
  final void Function(int index) onRemoveTask;
  final VoidCallback onOpenAssessments;
  final ValueChanged<double> onOpacityChanged;
  final Widget? gapSessionPanel;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _layoutService = DashboardLayoutService();
  DashboardLayoutConfig _layout = DashboardLayoutConfig.defaults();
  bool _ready = false;
  bool _editMode = false;

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    final loaded = await _layoutService.load();
    if (!mounted) return;
    setState(() {
      _layout = loaded;
      _ready = true;
    });
  }

  Future<void> _persist() async {
    await _layoutService.save(_layout);
  }

  void _enterEdit() {
    if (_editMode) return;
    setState(() => _editMode = true);
  }

  void _exitEdit() {
    if (!_editMode) return;
    setState(() => _editMode = false);
  }

  void _deletePhone(DashboardWidgetType type) {
    setState(() => _layout.phoneRects.remove(type));
    _persist();
  }

  void _deleteDesktop(DashboardWidgetType type) {
    setState(() => _layout.desktopRects.remove(type));
    _persist();
  }

  void _addPhone(DashboardWidgetType type) {
    if (_layout.phoneRects.containsKey(type)) return;
    final defaults = DashboardLayoutConfig.defaultPhoneRects()[type];
    var rect = defaults ??
        const DesktopRect(col: 0, row: 0, colSpan: 12, rowSpan: 3);
    rect = _layout.firstFreeRect(
          _layout.phoneRects,
          colSpan: rect.colSpan,
          rowSpan: rect.rowSpan,
        ) ??
        rect;
    if (!_layout.isValidRect(rect)) return;
    setState(() => _layout.phoneRects[type] = rect);
    _persist();
  }

  void _addDesktop(DashboardWidgetType type) {
    if (_layout.desktopRects.containsKey(type)) return;
    final defaults = DashboardLayoutConfig.defaultDesktopRects()[type];
    var rect = defaults ??
        const DesktopRect(col: 0, row: 0, colSpan: 4, rowSpan: 3);
    rect = _layout.firstFreeRect(
          _layout.desktopRects,
          colSpan: rect.colSpan,
          rowSpan: rect.rowSpan,
        ) ??
        rect;
    if (!_layout.isValidRect(rect)) return;
    setState(() => _layout.desktopRects[type] = rect);
    _persist();
  }

  Future<void> _openAddPicker({required bool phone}) async {
    final missing =
        phone ? _layout.missingForPhone() : _layout.missingForDesktop();
    final picked = await showModalBottomSheet<DashboardWidgetType>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => _AddWidgetSheet(available: missing),
    );
    if (picked == null || !mounted) return;
    if (phone) {
      _addPhone(picked);
    } else {
      _addDesktop(picked);
    }
  }

  Widget _panelFor(DashboardWidgetType type, {required bool expandLists}) {
    switch (type) {
      case DashboardWidgetType.tasks:
        return _TasksPanel(
          tasks: widget.tasks,
          onToggle: widget.onToggleTask,
          onAdd: widget.onAddTask,
          onRemove: widget.onRemoveTask,
          expandList: expandLists,
        );
      case DashboardWidgetType.todayEvents:
        return _TodayEventsPanel(
          events: widget.todayEvents,
          expandList: expandLists,
        );
      case DashboardWidgetType.upcomingAssessments:
        return _UpcomingAssessmentsPanel(
          assessments: widget.upcomingAssessments.take(6).toList(),
          onOpenAll: widget.onOpenAssessments,
          expandList: expandLists,
        );
      case DashboardWidgetType.gapSession:
        return widget.gapSessionPanel ??
            const Center(child: Text('Gap session'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = widget.tasks.where((t) => t.done).length;
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget header() {
      if (!isWide) {
        return Row(
          children: [
            Expanded(
              child: Text(
                'Study Grove',
                style: TextStyle(
                  fontSize: 20,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (!_editMode)
              IconButton(
                tooltip: 'Edit layout',
                onPressed: _enterEdit,
                icon: const Icon(Icons.dashboard_customize_outlined),
              ),
          ],
        );
      }
      return Row(
        children: [
          Text(
            'Study Grove',
            style: TextStyle(
              fontSize: 20,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(width: 12),
          GreenChip('Tasks complete: $done/${widget.tasks.length}'),
          const SizedBox(width: 10),
          const GreenChip('Today'),
          const Spacer(),
          if (!_editMode)
            IconButton(
              tooltip: 'Edit layout',
              onPressed: _enterEdit,
              icon: const Icon(Icons.dashboard_customize_outlined),
            ),
          SizedBox(
            width: 250,
            child: FrostPanel(
              opacity: 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.blur_on, size: 18, color: scheme.onSurface),
                  const SizedBox(width: 8),
                  Text(
                    'Opacity',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: scheme.primary,
                          inactiveTrackColor:
                              scheme.onSurface.withValues(alpha: 0.28),
                          thumbColor: scheme.primary,
                          overlayColor: scheme.primary.withValues(alpha: 0.18),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: widget.panelOpacity.clamp(0.20, 0.85),
                          min: 0.20,
                          max: 0.85,
                          onChanged: widget.onOpacityChanged,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget editBubbleRow({required bool phone}) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: !_editMode
            ? const SizedBox.shrink(key: ValueKey('no-edit'))
            : Padding(
                key: const ValueKey('edit'),
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openAddPicker(phone: phone),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(
                        'Add widget',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _exitEdit,
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
      );
    }

    Widget footer() {
      if (isWide) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Stay curious',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.84),
            ),
          ),
        );
      }
      return Row(
        children: [
          Text(
            'Stay curious',
            style: TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.84),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 168,
            child: FrostPanel(
              opacity: 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.blur_on, size: 16, color: scheme.onSurface),
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: scheme.primary,
                          inactiveTrackColor:
                              scheme.onSurface.withValues(alpha: 0.28),
                          thumbColor: scheme.primary,
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: widget.panelOpacity.clamp(0.20, 0.85),
                          min: 0.20,
                          max: 0.85,
                          onChanged: widget.onOpacityChanged,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            widget.backgroundAsset,
            fit: BoxFit.cover,
            alignment: isWide ? Alignment.center : Alignment.centerLeft,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.1),
                radius: 1.15,
                colors: [
                  Colors.transparent,
                  Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.40),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                header(),
                const SizedBox(height: 10),
                editBubbleRow(phone: !isWide),
                Expanded(
                  child: _DashboardGridCanvas(
                    rects: isWide ? _layout.desktopRects : _layout.phoneRects,
                    editMode: _editMode,
                    panelOpacity: widget.panelOpacity,
                    touchFriendly: !isWide,
                    onEnterEdit: _enterEdit,
                    onExitEdit: _exitEdit,
                    onDelete: isWide ? _deleteDesktop : _deletePhone,
                    onMoveOrResize: (type, rect) {
                      if (!_layout.isValidRect(rect)) return;
                      final map =
                          isWide ? _layout.desktopRects : _layout.phoneRects;
                      setState(() {
                        // Re-insert so the moved widget paints on top when overlapping.
                        map.remove(type);
                        map[type] = rect;
                      });
                      _persist();
                    },
                    panelBuilder: (type) =>
                        _panelFor(type, expandLists: true),
                  ),
                ),
                const SizedBox(height: 10),
                footer(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardGridCanvas extends StatefulWidget {
  const _DashboardGridCanvas({
    required this.rects,
    required this.editMode,
    required this.panelOpacity,
    required this.touchFriendly,
    required this.onEnterEdit,
    required this.onExitEdit,
    required this.onDelete,
    required this.onMoveOrResize,
    required this.panelBuilder,
  });

  final Map<DashboardWidgetType, DesktopRect> rects;
  final bool editMode;
  final double panelOpacity;
  final bool touchFriendly;
  final VoidCallback onEnterEdit;
  final VoidCallback onExitEdit;
  final ValueChanged<DashboardWidgetType> onDelete;
  final void Function(DashboardWidgetType type, DesktopRect rect) onMoveOrResize;
  final Widget Function(DashboardWidgetType type) panelBuilder;

  @override
  State<_DashboardGridCanvas> createState() => _DashboardGridCanvasState();
}

class _DashboardGridCanvasState extends State<_DashboardGridCanvas> {
  final GlobalKey _gridKey = GlobalKey();

  RenderBox? get gridBox {
    final ctx = _gridKey.currentContext;
    if (ctx == null) return null;
    return ctx.findRenderObject() as RenderBox?;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = widget.rects.entries.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / DashboardLayoutConfig.gridCols;
        final cellH = constraints.maxHeight / DashboardLayoutConfig.gridRows;

        return Stack(
          key: _gridKey,
          clipBehavior: Clip.hardEdge,
          children: [
            if (widget.editMode)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onExitEdit,
                  child: CustomPaint(
                    painter: _GridPainter(
                      cols: DashboardLayoutConfig.gridCols,
                      rows: DashboardLayoutConfig.gridRows,
                      color: scheme.onSurface.withValues(alpha: 0.10),
                    ),
                  ),
                ),
              ),
            if (entries.isEmpty)
              Center(
                child: GestureDetector(
                  onLongPress: widget.onEnterEdit,
                  onSecondaryTap: widget.onEnterEdit,
                  child: Text(
                    widget.editMode
                        ? 'No widgets yet.\nTap Add widget above.'
                        : 'No widgets yet.\nTap the edit icon to customize.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: 0.84),
                    ),
                  ),
                ),
              ),
            for (final e in entries)
              _DesktopWidgetFrame(
                rect: e.value,
                cellW: cellW,
                cellH: cellH,
                editMode: widget.editMode,
                panelOpacity: widget.panelOpacity,
                touchFriendly: widget.touchFriendly,
                getGridBox: () => gridBox,
                onEnterEdit: widget.onEnterEdit,
                onDelete: () => widget.onDelete(e.key),
                onMoveOrResize: (rect) =>
                    widget.onMoveOrResize(e.key, rect),
                child: widget.panelBuilder(e.key),
              ),
          ],
        );
      },
    );
  }
}

class _DesktopWidgetFrame extends StatefulWidget {
  const _DesktopWidgetFrame({
    required this.rect,
    required this.cellW,
    required this.cellH,
    required this.editMode,
    required this.panelOpacity,
    required this.touchFriendly,
    required this.getGridBox,
    required this.onEnterEdit,
    required this.onDelete,
    required this.onMoveOrResize,
    required this.child,
  });

  final DesktopRect rect;
  final double cellW;
  final double cellH;
  final bool editMode;
  final double panelOpacity;
  final bool touchFriendly;
  final RenderBox? Function() getGridBox;
  final VoidCallback onEnterEdit;
  final VoidCallback onDelete;
  final ValueChanged<DesktopRect> onMoveOrResize;
  final Widget child;

  @override
  State<_DesktopWidgetFrame> createState() => _DesktopWidgetFrameState();
}

class _DesktopWidgetFrameState extends State<_DesktopWidgetFrame> {
  DesktopRect? _draft;
  Offset? _grabLocal;

  DesktopRect get _current => _draft ?? widget.rect;

  @override
  void didUpdateWidget(covariant _DesktopWidgetFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rect != widget.rect) {
      _draft = null;
    }
  }

  void _commit() {
    final next = _draft ?? widget.rect;
    _grabLocal = null;
    setState(() => _draft = null);
    widget.onMoveOrResize(next);
  }

  void _moveTo(Offset global) {
    final box = widget.getGridBox();
    if (box == null) return;
    final local = box.globalToLocal(global);
    final grab = _grabLocal ?? Offset.zero;
    final originX = local.dx - grab.dx;
    final originY = local.dy - grab.dy;
    final base = widget.rect;
    final col = (originX / widget.cellW)
        .round()
        .clamp(0, DashboardLayoutConfig.gridCols - base.colSpan);
    final row = (originY / widget.cellH)
        .round()
        .clamp(0, DashboardLayoutConfig.gridRows - base.rowSpan);
    setState(() => _draft = base.copyWith(col: col, row: row));
  }

  void _resizeTo(Offset global) {
    final box = widget.getGridBox();
    if (box == null) return;
    final local = box.globalToLocal(global);
    final origin = widget.rect;
    final endCol = (local.dx / widget.cellW)
        .ceil()
        .clamp(
          origin.col + DashboardLayoutConfig.minColSpan,
          DashboardLayoutConfig.gridCols,
        );
    final endRow = (local.dy / widget.cellH)
        .ceil()
        .clamp(
          origin.row + DashboardLayoutConfig.minRowSpan,
          DashboardLayoutConfig.gridRows,
        );
    setState(
      () => _draft = origin.copyWith(
        colSpan: endCol - origin.col,
        rowSpan: endRow - origin.row,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rect = _current;
    final left = rect.col * widget.cellW;
    final top = rect.row * widget.cellH;
    final width = rect.colSpan * widget.cellW;
    final height = rect.rowSpan * widget.cellH;
    final scheme = Theme.of(context).colorScheme;
    final deleteSize = widget.touchFriendly ? 44.0 : 32.0;
    final resizeSize = widget.touchFriendly ? 40.0 : 22.0;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onLongPress: widget.onEnterEdit,
                onSecondaryTap: widget.onEnterEdit,
                child: FrostPanel(
                  opacity: widget.panelOpacity,
                  child: widget.child,
                ),
              ),
            ),
            if (widget.editMode) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (details) {
                    _grabLocal = details.localPosition;
                  },
                  onPanUpdate: (details) => _moveTo(details.globalPosition),
                  onPanEnd: (_) => _commit(),
                  onPanCancel: _commit,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: scheme.error,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onDelete,
                    child: SizedBox(
                      width: deleteSize,
                      height: deleteSize,
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: GestureDetector(
                  onPanUpdate: (details) =>
                      _resizeTo(details.globalPosition),
                  onPanEnd: (_) => _commit(),
                  onPanCancel: _commit,
                  child: Container(
                    width: resizeSize,
                    height: resizeSize,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.cols,
    required this.rows,
    required this.color,
  });

  final int cols;
  final int rows;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final cellW = size.width / cols;
    final cellH = size.height / rows;
    for (var c = 0; c <= cols; c++) {
      final x = c * cellW;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var r = 0; r <= rows; r++) {
      final y = r * cellH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.cols != cols ||
        oldDelegate.rows != rows ||
        oldDelegate.color != color;
  }
}

class _AddWidgetSheet extends StatelessWidget {
  const _AddWidgetSheet({required this.available});

  final List<DashboardWidgetType> available;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add widget',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              available.isEmpty
                  ? 'All widgets are already on the dashboard. Remove one first.'
                  : 'Scroll and tap a widget to add it.',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.84),
              ),
            ),
            const SizedBox(height: 16),
            if (available.isEmpty)
              const SizedBox(height: 8)
            else
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: available.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final type = available[index];
                    return _WidgetPreviewCard(
                      type: type,
                      onTap: () => Navigator.pop(context, type),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WidgetPreviewCard extends StatelessWidget {
  const _WidgetPreviewCard({required this.type, required this.onTap});

  final DashboardWidgetType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                type.label,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                type.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.84),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _previewBody(scheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewBody(ColorScheme scheme) {
    switch (type) {
      case DashboardWidgetType.tasks:
        return Column(
          children: [
            _previewRow(scheme, checked: true, label: 'Read chapter 3'),
            _previewRow(scheme, checked: false, label: 'Practice quiz'),
            _previewRow(scheme, checked: false, label: 'Email tutor'),
          ],
        );
      case DashboardWidgetType.todayEvents:
        return Column(
          children: [
            _previewChip(scheme, '9:00', 'Lecture'),
            const SizedBox(height: 8),
            _previewChip(scheme, '14:00', 'Study block'),
          ],
        );
      case DashboardWidgetType.upcomingAssessments:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('STAT1201', style: TextStyle(fontSize: 11, color: scheme.onSurface.withValues(alpha: 0.7))),
            const Text('Mini Test 2', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: 0.45,
                minHeight: 8,
                color: scheme.primary,
                backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
              ),
            ),
          ],
        );
      case DashboardWidgetType.gapSession:
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Begin Review',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        );
    }
  }

  Widget _previewRow(ColorScheme scheme, {required bool checked, required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                decoration: checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewChip(ColorScheme scheme, String time, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$time  $title', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _TasksPanel extends StatelessWidget {
  const _TasksPanel({
    required this.tasks,
    required this.onToggle,
    required this.onAdd,
    required this.onRemove,
    this.expandList = true,
  });

  final List<TaskItem> tasks;
  final void Function(int index) onToggle;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = tasks.isEmpty
        ? Text(
            'No tasks yet.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.84)),
          )
        : ListView.builder(
            shrinkWrap: !expandList,
            physics: expandList
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: tasks.length,
            itemBuilder: (_, i) {
              final t = tasks[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onToggle(i),
                  child: Row(
                    children: [
                      Checkbox(value: t.done, onChanged: (_) => onToggle(i)),
                      Expanded(
                        child: Text(
                          t.title,
                          style: TextStyle(
                            color: t.done
                                ? scheme.onSurface.withValues(alpha: 0.86)
                                : scheme.onSurface,
                            decoration:
                                t.done ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        onPressed: () => onRemove(i),
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: scheme.onSurface.withValues(alpha: 0.84),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "TODAY'S QUEUE",
              style: TextStyle(
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Add task',
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (expandList) Expanded(child: list) else list,
      ],
    );
  }
}

class _TodayEventsPanel extends StatelessWidget {
  const _TodayEventsPanel({
    required this.events,
    this.expandList = true,
  });

  final List<AppEvent> events;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = events.isEmpty
        ? Text(
            'No events.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.84)),
          )
        : ListView(
            shrinkWrap: !expandList,
            physics: expandList
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            children: events
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 10, color: scheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            formatTimeRange(
                              context,
                              e.startMinutes,
                              e.endMinutes,
                            ),
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (e.isRecurring)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.repeat,
                                size: 12,
                                color:
                                    scheme.onSurface.withValues(alpha: 0.84),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              e.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TODAY',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        if (expandList) Expanded(child: body) else body,
      ],
    );
  }
}

class _UpcomingAssessmentsPanel extends StatelessWidget {
  const _UpcomingAssessmentsPanel({
    required this.assessments,
    required this.onOpenAll,
    this.expandList = true,
  });

  final List<Assessment> assessments;
  final VoidCallback onOpenAll;
  final bool expandList;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = ListView.separated(
      shrinkWrap: !expandList,
      physics: expandList
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemCount: assessments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final a = assessments[i];
        final pct = (a.progress * 100).round();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.course.toUpperCase(),
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.84),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [GreenChip(a.dueLabel), GreenChip('$pct%')],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: a.progress.clamp(0, 1),
                  minHeight: 8,
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'UPCOMING ASSESSMENTS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: onOpenAll,
              child: Text('Open', style: TextStyle(color: scheme.onSurface)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (expandList) Expanded(child: list) else list,
      ],
    );
  }
}
