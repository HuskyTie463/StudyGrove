import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/models.dart';
import '../services/assessment_service.dart';
import '../services/event_service.dart';
import '../services/friction_and_progress.dart';
import '../services/lecture_lab_service.dart';
import '../services/note_service.dart';
import '../services/profile_service.dart';
import '../services/study_time_service.dart';
import '../services/subject_service.dart';
import '../services/task_service.dart';
import '../theme/chrome_palettes.dart';
import '../theme/design_tokens.dart';
import '../ui/shared_ui.dart';
import '../ui/shell_nav.dart';
import '../ui/shell_scope.dart';
import '../ui/style_motifs.dart';
import 'assessment_detail_page.dart';
import 'assessments_page.dart';
import 'backgrounds_page.dart';
import 'calendar_page.dart';
import 'consolidation_page.dart';
import 'dashboard_page.dart';
import 'notes_page.dart';
import 'planner_page.dart';
import 'pomodoro_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'study_intelligence_pages.dart';
import 'study_roulette_page.dart';
import 'study_time_page.dart';
import 'subjects_page.dart';
import 'voice_chat_page.dart';
import 'weekly_planner_page.dart';

export '../ui/shell_nav.dart' show AppPage;

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppPage _page = AppPage.dashboard;
  AppPage? _previous;
  ShellSection? _openSection;
  String? _subjectId;

  late final String _uid;
  late final TaskService _taskSvc;
  late final EventService _eventSvc;
  late final AssessmentService _assessSvc;
  late final SubjectService _subjectSvc;
  late final LectureLabService _lectureLabSvc;
  late final FrictionService _frictionSvc;
  late final ProgressMetricsService _progressSvc;
  late final NoteService _noteSvc;
  late final StudyTimeService _studyTimeSvc;
  late final ProfileService _profile;

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
    _noteSvc = NoteService(_uid);
    _studyTimeSvc = StudyTimeService(_uid);
    _profile = ProfileService(_uid)..load();

    _selectedDay = _dayOnly(DateTime.now());
    _eventsStream = _eventSvc.streamCombinedEventsForDay(_selectedDay);
    _restoreSubject();
    _applyLaunchLink();
  }

  void _applyLaunchLink() {
    final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final lower = route.toLowerCase();
    if (lower.contains('timetable') ||
        lower.contains('studygrove://calendar')) {
      _page = AppPage.calendar;
      _openSection = null;
    }
  }

  Future<void> _restoreSubject() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('shell_subject_$_uid');
    if (!mounted || id == null || id.isEmpty) return;
    setState(() => _subjectId = id);
  }

  Future<void> _persistSubject(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null || id.isEmpty) {
      await prefs.remove('shell_subject_$_uid');
    } else {
      await prefs.setString('shell_subject_$_uid', id);
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _studyTimeSvc.dispose();
    _profile.dispose();
    super.dispose();
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _setPage(AppPage p) {
    setState(() {
      if (p != _page) {
        _previous = _page;
        _page = p;
      }
      _openSection = null;
    });
  }

  /// Top-bar destinations (Profile, Backgrounds, Settings): second click leaves.
  void _toggleOrOpenPage(AppPage p) {
    if (_page == p) {
      final back = (_previous != null && _previous != p)
          ? _previous!
          : AppPage.dashboard;
      setState(() {
        _previous = p;
        _page = back;
        _openSection = null;
      });
      return;
    }
    _setPage(p);
  }

  void _toggleSection(ShellSection section) {
    setState(() {
      _openSection = _openSection == section ? null : section;
    });
  }

  void _setSubject(String? id) {
    setState(() => _subjectId = id);
    _persistSubject(id);
  }

  static bool _useDesktopRail(BuildContext context) => useDesktopChrome(context);

  bool _matchesSubject({
    String? itemSubjectId,
    String? course,
    String? title,
    List<Subject> subjects = const [],
  }) {
    return matchesSelectedSubject(
      selectedId: _subjectId,
      subjects: subjects,
      itemSubjectId: itemSubjectId,
      course: course,
      title: title,
    );
  }

  Widget _wrapShell(Widget child) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // One wallpaper for the whole shell. Pages and chrome must not
            // paint a second copy — they only sit on top of this layer.
            ExcludeSemantics(
              child: RepaintBoundary(
                child: Image.asset(
                  themeController.backgroundAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }

  Widget _chrome({
    required Widget body,
    required List<Subject> subjects,
    required bool isWide,
  }) {
    final validId =
        subjects.any((s) => s.id == _subjectId) ? _subjectId : null;
    return AnimatedBuilder(
      animation: Listenable.merge([_profile, themeController]),
      builder: (context, _) {
        return ShellScope(
          page: _page,
          subjectId: validId,
          subjects: subjects,
          profile: _profile,
          goTo: _setPage,
          setSubjectId: _setSubject,
          child: Column(
            children: [
              _TopBar(
                page: _page,
                previous: _previous,
                subjects: subjects,
                subjectId: validId,
                profile: _profile,
                compact: !isWide,
                onSelectSubject: _setSubject,
                onOpenPage: _setPage,
                onTogglePage: _toggleOrOpenPage,
                onRecent: _previous == null ? null : () => _setPage(_previous!),
              ),
              Expanded(
                child: isWide
                    ? Row(
                        children: [
                          _IconRail(
                            page: _page,
                            openSection: _openSection,
                            onToggleSection: _toggleSection,
                            onOpenSettings: () =>
                                _toggleOrOpenPage(AppPage.settings),
                          ),
                          if (_openSection != null)
                            _SubRail(
                              section: _openSection!,
                              page: _page,
                              onSelect: _setPage,
                            ),
                          Expanded(child: body),
                        ],
                      )
                    : body,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _useDesktopRail(context);

    return StreamBuilder<List<Subject>>(
      stream: _subjectSvc.streamSubjects(),
      builder: (context, subSnap) {
        final subjects = subSnap.data ?? const <Subject>[];
        return StreamBuilder<List<TaskItem>>(
          stream: _taskSvc.streamTasks(),
          builder: (context, taskSnap) {
            if (taskSnap.connectionState == ConnectionState.waiting &&
                !taskSnap.hasData) {
              _loadingTimer ??= Timer(const Duration(seconds: 8), () {
                if (mounted) setState(() => _loadingTimedOut = true);
              });
              if (_loadingTimedOut) {
                _loadingTimer?.cancel();
                _loadingTimer = null;
                final body = _buildPage(
                  tasks: const [],
                  assessments: const [],
                  eventsForSelectedDay: const [],
                  subjects: subjects,
                );
                return _wrapShell(
                  Scaffold(
                    backgroundColor: Colors.transparent,
                    extendBody: true,
                    body: _chrome(
                      body: body,
                      subjects: subjects,
                      isWide: isWide,
                    ),
                    bottomNavigationBar: isWide
                        ? null
                        : _BottomNav(
                            page: _page,
                            openSection: _openSection,
                            onToggleSection: (s) =>
                                _showMobileSection(context, s),
                            onSettings: () =>
                                _toggleOrOpenPage(AppPage.settings),
                          ),
                  ),
                );
              }
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            _loadingTimer?.cancel();
            _loadingTimer = null;
            if (taskSnap.hasError) {
              return Scaffold(
                body: Center(child: Text('Could not load: ${taskSnap.error}')),
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
                final assessments = assSnap.data ?? const <Assessment>[];

                return StreamBuilder<List<AppEvent>>(
                  stream: _eventsStream,
                  builder: (context, eventSnap) {
                    final eventsForSelectedDay =
                        eventSnap.data ?? const <AppEvent>[];
                    final body = _buildPage(
                      tasks: tasks,
                      assessments: assessments,
                      eventsForSelectedDay: eventsForSelectedDay,
                      subjects: subjects,
                    );
                    return _wrapShell(
                      Scaffold(
                        backgroundColor: Colors.transparent,
                        extendBody: true,
                        body: _chrome(
                          body: body,
                          subjects: subjects,
                          isWide: isWide,
                        ),
                        bottomNavigationBar: isWide
                            ? null
                            : _BottomNav(
                                page: _page,
                                openSection: _openSection,
                                onToggleSection: (s) =>
                                    _showMobileSection(context, s),
                                onSettings: () =>
                                    _toggleOrOpenPage(AppPage.settings),
                              ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showMobileSection(BuildContext context, ShellSection section) async {
    final def = sectionDef(section);
    if (def == null) return;
    if (def.children.length == 1) {
      _setPage(def.children.first.page);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return ListView(
          shrinkWrap: true,
          children: [
            for (final child in def.children)
              ListTile(
                leading: Icon(child.icon),
                title: Text(child.label),
                selected: child.page == _page,
                onTap: () {
                  Navigator.pop(ctx);
                  _setPage(child.page);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildPage({
    required List<TaskItem> tasks,
    required List<Assessment> assessments,
    required List<AppEvent> eventsForSelectedDay,
    required List<Subject> subjects,
  }) {
    final opacity = themeController.panelOpacity;
    final scopedTasks = tasks
        .where(
          (t) => _matchesSubject(
            itemSubjectId: t.subjectId,
            title: t.title,
            subjects: subjects,
          ),
        )
        .toList();
    final scopedAssessments = assessments
        .where(
          (a) => _matchesSubject(
            itemSubjectId: a.subjectId,
            course: a.course,
            title: a.title,
            subjects: subjects,
          ),
        )
        .toList();
    final scopedEvents = eventsForSelectedDay
        .where(
          (e) => _matchesSubject(
            itemSubjectId: e.subjectId,
            title: e.title,
            subjects: subjects,
          ),
        )
        .toList();

    switch (_page) {
      case AppPage.dashboard:
        final today = _dayOnly(DateTime.now());
        final todayEvents = (_dayOnly(_selectedDay) == today)
            ? scopedEvents
            : const <AppEvent>[];
        final upcoming = [...scopedAssessments]
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

        return StreamBuilder<List<ReviewTopic>>(
          stream: _lectureLabSvc.streamTopics(),
          builder: (context, topicSnap) {
            return StreamBuilder<FrictionReason?>(
              stream: _frictionSvc.streamLastFriction(),
              builder: (context, frictionSnap) {
                final topics = (topicSnap.data ?? const <ReviewTopic>[])
                    .where(
                      (t) => _matchesSubject(
                        itemSubjectId: t.subjectId,
                        course: t.course,
                        title: t.title,
                        subjects: subjects,
                      ),
                    )
                    .toList();
                return DashboardPage(
                  panelOpacity: opacity,
                  tasks: scopedTasks,
                  todayEvents: todayEvents,
                  upcomingAssessments: upcoming,
                  onToggleTask: (i) => _taskSvc.toggleDone(
                    scopedTasks[i].id,
                    !scopedTasks[i].done,
                  ),
                  onAddTask: () => _promptAddTask(context),
                  onRemoveTask: (i) => _taskSvc.deleteTask(scopedTasks[i].id),
                  onSetTaskUrgency: (i, urgency) =>
                      _taskSvc.setUrgency(scopedTasks[i].id, urgency),
                  onOpenAssessments: () => _setPage(AppPage.assessments),
                  onOpacityChanged: themeController.setPanelOpacity,
                  gapSessionPanel: GapSessionCard(
                    events: todayEvents,
                    assessments: upcoming,
                    topics: topics,
                    friction: frictionSnap.data,
                    frictionService: _frictionSvc,
                    progressService: _progressSvc,
                    onBeginReview: () => _setPage(AppPage.consolidation),
                    onBeginConsolidation: () => _setPage(AppPage.consolidation),
                  ),
                );
              },
            );
          },
        );

      case AppPage.planner:
        return PlannerPage(
          panelOpacity: opacity,
          tasks: scopedTasks,
          eventService: _eventSvc,
          taskService: _taskSvc,
          onToggleTask: (i) =>
              _taskSvc.toggleDone(scopedTasks[i].id, !scopedTasks[i].done),
          onAddTask: () => _promptAddTask(context),
          onRemoveTask: (i) => _taskSvc.deleteTask(scopedTasks[i].id),
          onSetUrgency: (i, urgency) =>
              _taskSvc.setUrgency(scopedTasks[i].id, urgency),
        );

      case AppPage.notes:
        return NotesPage(panelOpacity: opacity, noteService: _noteSvc);

      case AppPage.calendar:
        return CalendarPage(
          panelOpacity: opacity,
          eventService: _eventSvc,
          subjectService: _subjectSvc,
        );

      case AppPage.weeklyPlanner:
        return WeeklyPlannerPage(
          panelOpacity: opacity,
          eventService: _eventSvc,
          subjectService: _subjectSvc,
        );

      case AppPage.subjects:
        return SubjectsPage(
          panelOpacity: opacity,
          subjectService: _subjectSvc,
          eventService: _eventSvc,
        );

      case AppPage.assessments:
        return AssessmentsPage(
          panelOpacity: opacity,
          onOpacityChanged: themeController.setPanelOpacity,
          assessmentService: _assessSvc,
          subjectService: _subjectSvc,
          focusSubjectId: _subjectId,
          onOpenAssessment: (assessment) async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AssessmentDetailPage(
                  panelOpacity: opacity,
                  assessment: assessment,
                  service: _assessSvc,
                ),
              ),
            );
            if (mounted) setState(() {});
          },
        );

      case AppPage.pomodoro:
        return PomodoroPage(
          panelOpacity: opacity,
          subjectService: _subjectSvc,
          studyTimeService: _studyTimeSvc,
          initialSubjectId: _subjectId,
        );

      case AppPage.studyTime:
        return StudyTimePage(
          panelOpacity: opacity,
          subjectService: _subjectSvc,
          studyTimeService: _studyTimeSvc,
          focusSubjectId: _subjectId,
        );

      case AppPage.studyRoulette:
        String? rouletteSubject;
        for (final s in subjects) {
          if (s.id == _subjectId) {
            rouletteSubject = s.label;
            break;
          }
        }
        return StudyRoulettePage(
          panelOpacity: opacity,
          subjectLabel: rouletteSubject,
        );

      case AppPage.lectureLab:
        return LectureLabPage(
          service: _lectureLabSvc,
          subjects: subjects,
          assessments: scopedAssessments.where((a) => a.isActive).toList(),
          initialSubjectId: _subjectId,
        );

      case AppPage.voiceChat:
        return VoiceChatPage(
          lectureLabService: _lectureLabSvc,
          subjects: subjects,
          progressService: _progressSvc,
          initialSubjectId: _subjectId,
        );

      case AppPage.consolidation:
        return ConsolidationPage(
          lectureLabService: _lectureLabSvc,
          subjects: subjects,
          progressService: _progressSvc,
          initialSubjectId: _subjectId,
        );

      case AppPage.settings:
        return const SettingsPage();

      case AppPage.profile:
        return ProfilePage(profile: _profile);

      case AppPage.backgrounds:
        return const BackgroundsPage();
    }
  }

  Future<void> _promptAddTask(BuildContext context) async {
    final controller = TextEditingController();
    var urgency = TaskUrgency.normal;
    final result = await showDialog<(String, TaskUrgency)?>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'e.g., 45 min past paper Qs',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Urgency',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TaskUrgency>(
                segments: const [
                  ButtonSegment(
                    value: TaskUrgency.normal,
                    label: Text('Normal'),
                    icon: Icon(Icons.low_priority, size: 18),
                  ),
                  ButtonSegment(
                    value: TaskUrgency.urgent,
                    label: Text('Urgent'),
                    icon: Icon(Icons.priority_high, size: 18),
                  ),
                ],
                selected: {urgency},
                onSelectionChanged: (v) =>
                    setDialogState(() => urgency = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, (controller.text.trim(), urgency)),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result.$1.isEmpty) return;
    await _taskSvc.addTask(
      result.$1,
      urgency: result.$2,
      subjectId: _subjectId,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.page,
    required this.previous,
    required this.subjects,
    required this.subjectId,
    required this.profile,
    required this.compact,
    required this.onSelectSubject,
    required this.onOpenPage,
    required this.onTogglePage,
    required this.onRecent,
  });

  final AppPage page;
  final AppPage? previous;
  final List<Subject> subjects;
  final String? subjectId;
  final ProfileService profile;
  final bool compact;
  final ValueChanged<String?> onSelectSubject;
  final ValueChanged<AppPage> onOpenPage;
  final ValueChanged<AppPage> onTogglePage;
  final VoidCallback? onRecent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FrostChrome(
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
            child: Row(
              children: [
                _SubjectChooser(
                  subjects: subjects,
                  subjectId: subjectId,
                  compact: compact,
                  onSelectSubject: onSelectSubject,
                  onCreateSubject: () => onOpenPage(AppPage.subjects),
                ),
                SizedBox(width: compact ? 6 : 12),
                Expanded(
                  child: Text(
                    titleForPage(page),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 15 : 16,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                if (!compact && onRecent != null)
                  TextButton.icon(
                    onPressed: onRecent,
                    icon: const Icon(Icons.history, size: 18),
                    label: Text(titleForPage(previous!)),
                  ),
                if (!compact) ...[
                  MenuAnchor(
                    builder: (context, controller, _) {
                      return IconButton(
                        tooltip: 'Colour theme',
                        isSelected: controller.isOpen,
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        icon: Icon(
                          controller.isOpen
                              ? Icons.palette
                              : Icons.palette_outlined,
                        ),
                      );
                    },
                    menuChildren: [
                      for (final p in kChromePalettes)
                        MenuItemButton(
                          onPressed: () => themeController.setStyle(p.family),
                          child: _paletteRow(p),
                        ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Backgrounds',
                    isSelected: page == AppPage.backgrounds,
                    onPressed: () => onTogglePage(AppPage.backgrounds),
                    icon: Icon(
                      page == AppPage.backgrounds
                          ? Icons.wallpaper
                          : Icons.wallpaper_outlined,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onTogglePage(AppPage.profile),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          ProfileAvatar(profile: profile, size: 28),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: Text(
                              profile.greetingName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: page == AppPage.profile
                                    ? t.primaryAction
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Log out',
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout),
                  ),
                ] else ...[
                  IconButton(
                    tooltip: 'Profile',
                    visualDensity: VisualDensity.compact,
                    isSelected: page == AppPage.profile,
                    onPressed: () => onTogglePage(AppPage.profile),
                    icon: ProfileAvatar(profile: profile, size: 26),
                  ),
                  MenuAnchor(
                    builder: (context, controller, _) {
                      return IconButton(
                        tooltip: 'More',
                        isSelected: controller.isOpen,
                        onPressed: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        icon: const Icon(Icons.more_vert),
                      );
                    },
                    menuChildren: [
                      if (onRecent != null)
                        MenuItemButton(
                          onPressed: onRecent,
                          child: Text('Back to ${titleForPage(previous!)}'),
                        ),
                      for (final p in kChromePalettes)
                        MenuItemButton(
                          onPressed: () => themeController.setStyle(p.family),
                          child: _paletteRow(p),
                        ),
                      MenuItemButton(
                        onPressed: () => onTogglePage(AppPage.backgrounds),
                        child: Text(
                          page == AppPage.backgrounds
                              ? 'Close backgrounds'
                              : 'Backgrounds',
                        ),
                      ),
                      MenuItemButton(
                        onPressed: () => onTogglePage(AppPage.profile),
                        child: Text(
                          page == AppPage.profile ? 'Close profile' : 'Profile',
                        ),
                      ),
                      MenuItemButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paletteRow(ChromePalette p) {
    return Row(
      children: [
        ...p.swatch.map(
          (c) => Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(p.label),
        if (themeController.style == p.family) ...[
          const SizedBox(width: 12),
          const Icon(Icons.check, size: 16),
        ],
      ],
    );
  }
}

class _IconRail extends StatelessWidget {
  const _IconRail({
    required this.page,
    required this.openSection,
    required this.onToggleSection,
    required this.onOpenSettings,
  });

  final AppPage page;
  final ShellSection? openSection;
  final ValueChanged<ShellSection> onToggleSection;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final selectedSection = sectionForPage(page);

    return SizedBox(
      width: 56,
      child: StyleRailMotif(
        child: FrostChrome(
          child: Column(
            children: [
              const SizedBox(height: 8),
              for (final def in kShellSections)
                _IconRailButton(
                  tooltip: def.label,
                  icon: openSection == def.section || selectedSection == def.section
                      ? def.selectedIcon
                      : def.icon,
                  selected: openSection == def.section ||
                      (openSection == null && selectedSection == def.section),
                  color: t.primaryAction,
                  muted: t.textMuted,
                  onTap: () => onToggleSection(def.section),
                ),
              const Spacer(),
              _IconRailButton(
                tooltip: 'Settings',
                icon: page == AppPage.settings
                    ? Icons.settings
                    : Icons.settings_outlined,
                selected: page == AppPage.settings,
                color: t.primaryAction,
                muted: t.textMuted,
                onTap: onOpenSettings,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconRailButton extends StatelessWidget {
  const _IconRailButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.color,
    required this.muted,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final Color color;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 32, color: selected ? color : muted),
          ),
        ),
      ),
    );
  }
}

class _SubRail extends StatelessWidget {
  const _SubRail({
    required this.section,
    required this.page,
    required this.onSelect,
  });

  final ShellSection section;
  final AppPage page;
  final ValueChanged<AppPage> onSelect;

  @override
  Widget build(BuildContext context) {
    final def = sectionDef(section);
    if (def == null) return const SizedBox.shrink();
    final t = context.tokens;
    return SizedBox(
      width: 196,
      child: FrostChrome(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: Text(
                def.label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: t.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            for (final child in def.children)
              ListTile(
                dense: true,
                selected: child.page == page,
                leading: Icon(
                  child.page == page ? child.selectedIcon : child.icon,
                  size: 22,
                ),
                title: Text(child.label),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                onTap: () => onSelect(child.page),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.page,
    required this.openSection,
    required this.onToggleSection,
    required this.onSettings,
  });

  final AppPage page;
  final ShellSection? openSection;
  final ValueChanged<ShellSection> onToggleSection;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final selected = sectionForPage(page) ?? openSection;
    var sectionIndex = selected == null
        ? 0
        : kShellSections.indexWhere((s) => s.section == selected);
    if (sectionIndex < 0) sectionIndex = 0;
    return FrostChrome(
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        selectedIndex:
            page == AppPage.settings ? kShellSections.length : sectionIndex,
        onDestinationSelected: (i) {
          if (i >= kShellSections.length) {
            onSettings();
            return;
          }
          onToggleSection(kShellSections[i].section);
        },
        destinations: [
          for (final def in kShellSections)
            NavigationDestination(
              icon: Icon(def.icon),
              selectedIcon: Icon(def.selectedIcon),
              label: def.label,
            ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _SubjectChooser extends StatelessWidget {
  const _SubjectChooser({
    required this.subjects,
    required this.subjectId,
    required this.onSelectSubject,
    required this.onCreateSubject,
    this.compact = false,
  });

  final List<Subject> subjects;
  final String? subjectId;
  final ValueChanged<String?> onSelectSubject;
  final VoidCallback onCreateSubject;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    var label = 'All subjects';
    for (final s in subjects) {
      if (s.id == subjectId) {
        label = s.label;
        break;
      }
    }
    return MenuAnchor(
      builder: (context, controller, _) {
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? 108 : 200),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 13 : 14,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.expand_more, size: 20, color: t.textMuted),
              ],
            ),
          ),
        );
      },
      menuChildren: [
        MenuItemButton(
          onPressed: () => onSelectSubject(null),
          child: Text(
            'All subjects',
            style: TextStyle(
              fontWeight: subjectId == null ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        for (final s in subjects)
          MenuItemButton(
            onPressed: () => onSelectSubject(s.id),
            child: Text(
              s.label,
              style: TextStyle(
                fontWeight:
                    s.id == subjectId ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
          child: InkWell(
            onTap: onCreateSubject,
            child: Text(
              'Subjects — create a subject',
              style: TextStyle(
                fontSize: 12,
                color: t.textMuted,
                decoration: TextDecoration.underline,
                decorationColor: t.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
