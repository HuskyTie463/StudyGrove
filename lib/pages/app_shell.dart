// lib/pages/app_shell.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import '../models/models.dart';

import '../services/task_service.dart';
import '../services/event_service.dart';
import '../services/assessment_service.dart';
import '../services/subject_service.dart';
import '../services/lecture_lab_service.dart';
import '../services/friction_and_progress.dart';

import 'dashboard_page.dart';
import 'planner_page.dart';
import 'calendar_page.dart';
import 'weekly_planner_page.dart';
import 'subjects_page.dart';
import 'assessments_page.dart';
import 'assessment_detail_page.dart';
import 'pomodoro_page.dart';
import 'study_roulette_page.dart';
import 'study_intelligence_pages.dart';
import 'consolidation_page.dart';
import 'voice_chat_page.dart';
import 'settings_page.dart';
import '../ui/style_motifs.dart';

enum AppPage {
  dashboard,
  planner,
  calendar,
  weeklyPlanner,
  subjects,
  assessments,
  pomodoro,
  studyRoulette,
  memoryWeather,
  lectureLab,
  voiceChat,
  consolidation,
  settings,
}

class _ShellNavItem {
  const _ShellNavItem({
    required this.page,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.shortLabel,
    this.primary = true,
  });

  final AppPage page;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String shortLabel;
  final bool primary;
}

const _shellNavItems = <_ShellNavItem>[
  _ShellNavItem(
    page: AppPage.dashboard,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Dashboard',
    shortLabel: 'Dash',
  ),
  _ShellNavItem(
    page: AppPage.voiceChat,
    icon: Icons.graphic_eq,
    selectedIcon: Icons.graphic_eq,
    label: 'Voice Chat',
    shortLabel: 'Voice',
  ),
  _ShellNavItem(
    page: AppPage.planner,
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist,
    label: 'Planner',
    shortLabel: 'Plan',
  ),
  _ShellNavItem(
    page: AppPage.calendar,
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    label: 'Calendar',
    shortLabel: 'Cal',
  ),
  _ShellNavItem(
    page: AppPage.weeklyPlanner,
    icon: Icons.view_week_outlined,
    selectedIcon: Icons.view_week,
    label: 'Weekly Planner',
    shortLabel: 'Week',
    primary: false,
  ),
  _ShellNavItem(
    page: AppPage.assessments,
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
    label: 'Assessments',
    shortLabel: 'Assess',
  ),
  _ShellNavItem(
    page: AppPage.subjects,
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    label: 'Subjects',
    shortLabel: 'Subj',
    primary: false,
  ),
  _ShellNavItem(
    page: AppPage.memoryWeather,
    icon: Icons.cloud_outlined,
    selectedIcon: Icons.cloud,
    label: 'Memory Weather',
    shortLabel: 'Memory',
  ),
  _ShellNavItem(
    page: AppPage.lectureLab,
    icon: Icons.science_outlined,
    selectedIcon: Icons.science,
    label: 'Lecture Lab',
    shortLabel: 'Lab',
    primary: false,
  ),
  _ShellNavItem(
    page: AppPage.consolidation,
    icon: Icons.spa_outlined,
    selectedIcon: Icons.spa,
    label: 'Consolidation',
    shortLabel: 'Review',
    primary: false,
  ),
  _ShellNavItem(
    page: AppPage.pomodoro,
    icon: Icons.timer_outlined,
    selectedIcon: Icons.timer,
    label: 'Pomodoro',
    shortLabel: 'Pomo',
  ),
  _ShellNavItem(
    page: AppPage.studyRoulette,
    icon: Icons.casino_outlined,
    selectedIcon: Icons.casino,
    label: 'Study Roulette',
    shortLabel: 'Spin',
    primary: false,
  ),
  _ShellNavItem(
    page: AppPage.settings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: 'Settings',
    shortLabel: 'Set',
    primary: false,
  ),
];

List<_ShellNavItem> get _primaryNavItems =>
    _shellNavItems.where((item) => item.primary).toList(growable: false);

List<_ShellNavItem> get _secondaryNavItems =>
    _shellNavItems.where((item) => !item.primary).toList(growable: false);

bool _isSecondaryPage(AppPage page) =>
    _secondaryNavItems.any((item) => item.page == page);

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppPage _page = AppPage.dashboard;
  double panelOpacity = 0.50;

  late final String _uid;
  late final TaskService _taskSvc;
  late final EventService _eventSvc;
  late final AssessmentService _assessSvc;
  late final SubjectService _subjectSvc;
  late final LectureLabService _lectureLabSvc;
  late final FrictionService _frictionSvc;
  late final ProgressMetricsService _progressSvc;

  DateTime _selectedDay = DateTime.now();
  late final Stream<List<AppEvent>> _eventsStream;
  bool _loadingTimedOut = false;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid ?? 'NO_USER';

    _taskSvc = TaskService(_uid);
    _eventSvc = EventService(_uid);
    _assessSvc = AssessmentService(_uid);
    _subjectSvc = SubjectService(_uid);
    _lectureLabSvc = LectureLabService(_uid);
    _frictionSvc = FrictionService(_uid);
    _progressSvc = ProgressMetricsService(_uid);

    _selectedDay = _dayOnly(DateTime.now());
    _eventsStream = _eventSvc.streamCombinedEventsForDay(_selectedDay);
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _setPage(AppPage p) => setState(() => _page = p);

  static bool _useDesktopRail(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.android) {
      return MediaQuery.of(context).size.width >= 720;
    }
    return true;
  }

  Widget _wrapShell(Widget child) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final showBg = themeController.showShellBackground ||
            themeController.useBackgroundBlend;
        if (!showBg) return child;
        final isWide = MediaQuery.of(context).size.width >= 900;
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: Image.asset(
                themeController.backgroundAsset,
                fit: BoxFit.cover,
                alignment: isWide ? Alignment.center : Alignment.centerLeft,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(
                      alpha: Theme.of(context).brightness == Brightness.light
                          ? 0.64
                          : 0.42,
                    ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _useDesktopRail(context);

    return StreamBuilder<List<TaskItem>>(
      stream: _taskSvc.streamTasks(),
      builder: (context, taskSnap) {
        if (taskSnap.connectionState == ConnectionState.waiting &&
            !taskSnap.hasData) {
          _loadingTimer ??= Timer(const Duration(seconds: 8), () {
            if (mounted) {
              setState(() => _loadingTimedOut = true);
            }
          });
          if (_loadingTimedOut) {
            _loadingTimer?.cancel();
            _loadingTimer = null;
            final body = _buildPage(
              tasks: const [],
              assessments: const [],
              eventsForSelectedDay: const [],
            );
            return Scaffold(
              body: isWide
                  ? Row(
                      children: [
                        _LeftRail(selected: _page, onSelect: _setPage),
                        Expanded(child: body),
                      ],
                    )
                  : body,
              bottomNavigationBar: isWide
                  ? null
                  : _BottomNav(selected: _page, onSelect: _setPage),
            );
          }
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    'Loading…',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.84),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'If this takes too long, check your connection.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        _loadingTimer?.cancel();
        _loadingTimer = null;
        if (taskSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.86),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load: ${taskSnap.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.84),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final tasks = taskSnap.data ?? const <TaskItem>[];

        return StreamBuilder<List<Assessment>>(
          stream: _assessSvc.streamAssessments(),
          builder: (context, assSnap) {
            if (assSnap.connectionState == ConnectionState.waiting &&
                !assSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (assSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.86),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load assessments: ${assSnap.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.84),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            final assessments = assSnap.data ?? const <Assessment>[];

            return StreamBuilder<List<AppEvent>>(
              stream: _eventsStream,
              builder: (context, eventSnap) {
                // This is so we don't block on Events - show dashboard with empty events; they'll appear when loaded - in place to fix the issue of dashboard not leading when events DNE
                if (eventSnap.connectionState == ConnectionState.waiting &&
                    !eventSnap.hasData) {
                  final eventsForSelectedDay = const <AppEvent>[];
                  final body = _buildPage(
                    tasks: tasks,
                    assessments: assessments,
                    eventsForSelectedDay: eventsForSelectedDay,
                  );
                  return Scaffold(
                    body: isWide
                        ? Row(
                            children: [
                              _LeftRail(selected: _page, onSelect: _setPage),
                              Expanded(child: body),
                            ],
                          )
                        : body,
                    bottomNavigationBar: isWide
                        ? null
                        : _BottomNav(selected: _page, onSelect: _setPage),
                  );
                }
                if (eventSnap.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.86),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load events: ${eventSnap.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.84),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final eventsForSelectedDay =
                    eventSnap.data ?? const <AppEvent>[];

                final body = _buildPage(
                  tasks: tasks,
                  assessments: assessments,
                  eventsForSelectedDay: eventsForSelectedDay,
                );

                return Scaffold(
                  body: _wrapShell(
                    isWide
                        ? Row(
                            children: [
                              _LeftRail(selected: _page, onSelect: _setPage),
                              Expanded(child: body),
                            ],
                          )
                        : body,
                  ),
                  bottomNavigationBar: isWide
                      ? null
                      : _BottomNav(selected: _page, onSelect: _setPage),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPage({
    required List<TaskItem> tasks,
    required List<Assessment> assessments,
    required List<AppEvent> eventsForSelectedDay,
  }) {
    switch (_page) {
      case AppPage.dashboard:
        final today = _dayOnly(DateTime.now());
        final todayEvents = (_dayOnly(_selectedDay) == today)
            ? eventsForSelectedDay
            : const <AppEvent>[];

        final upcoming = [...assessments]
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

        return StreamBuilder<List<ReviewTopic>>(
          stream: _lectureLabSvc.streamTopics(),
          builder: (context, topicSnap) {
            return StreamBuilder<FrictionReason?>(
              stream: _frictionSvc.streamLastFriction(),
              builder: (context, frictionSnap) {
                return DashboardPage(
                  backgroundAsset: themeController.backgroundAsset,
                  panelOpacity: panelOpacity,
                  tasks: tasks,
                  todayEvents: todayEvents,
                  upcomingAssessments: upcoming,
                  onToggleTask: (i) =>
                      _taskSvc.toggleDone(tasks[i].id, !tasks[i].done),
                  onAddTask: () => _promptAddTask(context),
                  onRemoveTask: (i) => _taskSvc.deleteTask(tasks[i].id),
                  onOpenAssessments: () => _setPage(AppPage.assessments),
                  onOpacityChanged: (v) => setState(() => panelOpacity = v),
                  gapSessionPanel: GapSessionCard(
                    events: todayEvents,
                    assessments: upcoming,
                    topics: topicSnap.data ?? const [],
                    friction: frictionSnap.data,
                    frictionService: _frictionSvc,
                    progressService: _progressSvc,
                    onBeginReview: () => _setPage(AppPage.memoryWeather),
                    onBeginConsolidation: () =>
                        _setPage(AppPage.consolidation),
                  ),
                );
              },
            );
          },
        );

      case AppPage.planner:
        return PlannerPage(
          panelOpacity: panelOpacity,
          tasks: tasks,
          eventService: _eventSvc,
          taskService: _taskSvc,
          onToggleTask: (i) => _taskSvc.toggleDone(tasks[i].id, !tasks[i].done),
          onAddTask: () => _promptAddTask(context),
          onRemoveTask: (i) => _taskSvc.deleteTask(tasks[i].id),
        );

      case AppPage.calendar:
        return CalendarPage(
          panelOpacity: panelOpacity,
          eventService: _eventSvc,
          subjectService: _subjectSvc,
        );

      case AppPage.weeklyPlanner:
        return WeeklyPlannerPage(
          panelOpacity: panelOpacity,
          eventService: _eventSvc,
          subjectService: _subjectSvc,
        );

      case AppPage.subjects:
        return SubjectsPage(
          panelOpacity: panelOpacity,
          subjectService: _subjectSvc,
          eventService: _eventSvc,
        );

      case AppPage.assessments:
        return AssessmentsPage(
          panelOpacity: panelOpacity,
          onOpacityChanged: (v) => setState(() => panelOpacity = v),
          assessmentService: _assessSvc,
          subjectService: _subjectSvc,
          onOpenAssessment: (assessment) async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AssessmentDetailPage(
                  panelOpacity: panelOpacity,
                  assessment: assessment,
                  service: _assessSvc,
                ),
              ),
            );
            if (mounted) setState(() {});
          },
        );

      case AppPage.pomodoro:
        return PomodoroPage(panelOpacity: panelOpacity);

      case AppPage.studyRoulette:
        return StudyRoulettePage(panelOpacity: panelOpacity);

      case AppPage.memoryWeather:
        return MemoryWeatherPage(
          lectureLabService: _lectureLabSvc,
          assessments: assessments,
          frictionService: _frictionSvc,
          progressService: _progressSvc,
          onOpenAssessment: (assessment) async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AssessmentDetailPage(
                  panelOpacity: panelOpacity,
                  assessment: assessment,
                  service: _assessSvc,
                ),
              ),
            );
          },
        );

      case AppPage.lectureLab:
        return StreamBuilder<List<Subject>>(
          stream: _subjectSvc.streamSubjects(),
          builder: (context, subSnap) {
            return LectureLabPage(
              service: _lectureLabSvc,
              subjects: subSnap.data ?? const [],
              assessments: assessments.where((a) => a.isActive).toList(),
            );
          },
        );

      case AppPage.voiceChat:
        return StreamBuilder<List<Subject>>(
          stream: _subjectSvc.streamSubjects(),
          builder: (context, subSnap) {
            return VoiceChatPage(
              lectureLabService: _lectureLabSvc,
              subjects: subSnap.data ?? const [],
              progressService: _progressSvc,
            );
          },
        );

      case AppPage.consolidation:
        return StreamBuilder<List<Subject>>(
          stream: _subjectSvc.streamSubjects(),
          builder: (context, subSnap) {
            return ConsolidationPage(
              lectureLabService: _lectureLabSvc,
              subjects: subSnap.data ?? const [],
              progressService: _progressSvc,
            );
          },
        );

      case AppPage.settings:
        return const SettingsPage();
    }
  }

  Future<void> _promptAddTask(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add task"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "e.g., 45 min past paper Qs",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (result?.isNotEmpty == true) {
      await _taskSvc.addTask(result!);
    }
  }
}

class _LeftRail extends StatelessWidget {
  const _LeftRail({required this.selected, required this.onSelect});
  final AppPage selected;
  final ValueChanged<AppPage> onSelect;

  static const _railWidth = 84.0;
  static const _tileHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final railTheme = Theme.of(context).navigationRailTheme;
    final selectedColor =
        railTheme.selectedIconTheme?.color ?? scheme.primary;
    final unselectedColor =
        railTheme.unselectedIconTheme?.color ?? scheme.onSurfaceVariant;

    return SizedBox(
      width: _railWidth,
      child: StyleRailMotif(
        child: Material(
          color: scheme.surface.withValues(alpha: 0.78),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final item in _shellNavItems)
                _RailTile(
                  item: item,
                  selected: selected == item.page,
                  height: _tileHeight,
                  onTap: () => onSelect(item.page),
                  selectedColor: selectedColor,
                  unselectedColor: unselectedColor,
                  selectedLabelStyle: railTheme.selectedLabelTextStyle,
                  unselectedLabelStyle: railTheme.unselectedLabelTextStyle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.item,
    required this.selected,
    required this.height,
    required this.onTap,
    required this.selectedColor,
    required this.unselectedColor,
    this.selectedLabelStyle,
    this.unselectedLabelStyle,
  });

  final _ShellNavItem item;
  final bool selected;
  final double height;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color unselectedColor;
  final TextStyle? selectedLabelStyle;
  final TextStyle? unselectedLabelStyle;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;
    final labelStyle = (selected ? selectedLabelStyle : unselectedLabelStyle)
            ?.copyWith(color: color) ??
        TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        );

    return Tooltip(
      message: item.label,
      waitDuration: const Duration(milliseconds: 450),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: color,
              ),
              const SizedBox(height: 2),
              Text(
                item.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selected, required this.onSelect});
  final AppPage selected;
  final ValueChanged<AppPage> onSelect;

  static const _mobilePrimaryCount = 4;

  int get _currentIndex {
    if (_isSecondaryPage(selected)) return _mobilePrimaryCount;
    final primaryIndex =
        _primaryNavItems.indexWhere((item) => item.page == selected);
    if (primaryIndex >= _mobilePrimaryCount) return _mobilePrimaryCount;
    return primaryIndex >= 0 ? primaryIndex : 0;
  }

  Future<void> _openMoreSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'More destinations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final item in _secondaryNavItems)
                ListTile(
                  leading: Icon(
                    selected == item.page ? item.selectedIcon : item.icon,
                  ),
                  title: Text(item.label),
                  selected: selected == item.page,
                  onTap: () {
                    Navigator.pop(context);
                    onSelect(item.page);
                  },
                ),
              if (_primaryNavItems.length > _mobilePrimaryCount) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Also available',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                for (final item in _primaryNavItems.skip(_mobilePrimaryCount))
                  ListTile(
                    leading: Icon(
                      selected == item.page ? item.selectedIcon : item.icon,
                    ),
                    title: Text(item.label),
                    selected: selected == item.page,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(item.page);
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        if (index == _mobilePrimaryCount) {
          _openMoreSheet(context);
          return;
        }
        onSelect(_primaryNavItems[index].page);
      },
      type: BottomNavigationBarType.fixed,
      items: [
        for (final item in _primaryNavItems.take(_mobilePrimaryCount))
          BottomNavigationBarItem(
            icon: Icon(item.icon),
            activeIcon: Icon(item.selectedIcon),
            label: item.shortLabel,
          ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          activeIcon: Icon(Icons.more_horiz),
          label: 'More',
        ),
      ],
    );
  }
}
