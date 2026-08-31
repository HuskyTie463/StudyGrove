import 'package:flutter/material.dart';

enum AppPage {
  dashboard,
  planner,
  notes,
  calendar,
  weeklyPlanner,
  subjects,
  assessments,
  pomodoro,
  studyTime,
  studyRoulette,
  lectureLab,
  voiceChat,
  consolidation,
  settings,
  profile,
  backgrounds,
}

enum ShellSection { home, plan, study, courses }

class ShellDest {
  const ShellDest({
    required this.page,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final AppPage page;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class ShellSectionDef {
  const ShellSectionDef({
    required this.section,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.children,
  });

  final ShellSection section;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final List<ShellDest> children;
}

const kShellSections = <ShellSectionDef>[
  ShellSectionDef(
    section: ShellSection.home,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
    children: [
      ShellDest(
        page: AppPage.dashboard,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Dashboard',
      ),
      ShellDest(
        page: AppPage.studyTime,
        icon: Icons.bar_chart_outlined,
        selectedIcon: Icons.bar_chart,
        label: 'Time',
      ),
      ShellDest(
        page: AppPage.notes,
        icon: Icons.sticky_note_2_outlined,
        selectedIcon: Icons.sticky_note_2,
        label: 'Notes',
      ),
    ],
  ),
  ShellSectionDef(
    section: ShellSection.plan,
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note,
    label: 'Plan',
    children: [
      ShellDest(
        page: AppPage.planner,
        icon: Icons.checklist_outlined,
        selectedIcon: Icons.checklist,
        label: 'Planner',
      ),
      ShellDest(
        page: AppPage.calendar,
        icon: Icons.calendar_month_outlined,
        selectedIcon: Icons.calendar_month,
        label: 'Calendar',
      ),
      ShellDest(
        page: AppPage.weeklyPlanner,
        icon: Icons.view_week_outlined,
        selectedIcon: Icons.view_week,
        label: 'Weekly Planner',
      ),
      ShellDest(
        page: AppPage.assessments,
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        label: 'Assessments',
      ),
    ],
  ),
  ShellSectionDef(
    section: ShellSection.study,
    icon: Icons.auto_stories_outlined,
    selectedIcon: Icons.auto_stories,
    label: 'Study',
    children: [
      ShellDest(
        page: AppPage.lectureLab,
        icon: Icons.science_outlined,
        selectedIcon: Icons.science,
        label: 'Lecture Lab',
      ),
      ShellDest(
        page: AppPage.consolidation,
        icon: Icons.spa_outlined,
        selectedIcon: Icons.spa,
        label: 'Review',
      ),
      ShellDest(
        page: AppPage.voiceChat,
        icon: Icons.graphic_eq,
        selectedIcon: Icons.graphic_eq,
        label: 'Voice Chat',
      ),
      ShellDest(
        page: AppPage.studyRoulette,
        icon: Icons.casino_outlined,
        selectedIcon: Icons.casino,
        label: 'Study Roulette',
      ),
      ShellDest(
        page: AppPage.pomodoro,
        icon: Icons.timer_outlined,
        selectedIcon: Icons.timer,
        label: 'Pomodoro',
      ),
    ],
  ),
  ShellSectionDef(
    section: ShellSection.courses,
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    label: 'Courses',
    children: [
      ShellDest(
        page: AppPage.subjects,
        icon: Icons.class_outlined,
        selectedIcon: Icons.class_,
        label: 'Subjects',
      ),
    ],
  ),
];

/// Width at which the icon rail + second column is usable.
/// Same rule on every platform so a phone, or a skinny desktop window,
/// never gets the Cursor-style rail stacked beside the page.
const kDesktopChromeMinWidth = 800.0;

bool useDesktopChrome(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= kDesktopChromeMinWidth;
}

String titleForPage(AppPage page) {
  switch (page) {
    case AppPage.dashboard:
      return 'Dashboard';
    case AppPage.planner:
      return 'Planner';
    case AppPage.notes:
      return 'Notes';
    case AppPage.calendar:
      return 'Calendar';
    case AppPage.weeklyPlanner:
      return 'Weekly Planner';
    case AppPage.subjects:
      return 'Subjects';
    case AppPage.assessments:
      return 'Assessments';
    case AppPage.pomodoro:
      return 'Pomodoro';
    case AppPage.studyTime:
      return 'Time';
    case AppPage.studyRoulette:
      return 'Study Roulette';
    case AppPage.lectureLab:
      return 'Lecture Lab';
    case AppPage.voiceChat:
      return 'Voice Chat';
    case AppPage.consolidation:
      return 'Review';
    case AppPage.settings:
      return 'Settings';
    case AppPage.profile:
      return 'Profile';
    case AppPage.backgrounds:
      return 'Backgrounds';
  }
}

ShellSection? sectionForPage(AppPage page) {
  for (final def in kShellSections) {
    for (final child in def.children) {
      if (child.page == page) return def.section;
    }
  }
  return null;
}

ShellSectionDef? sectionDef(ShellSection section) {
  for (final def in kShellSections) {
    if (def.section == section) return def;
  }
  return null;
}
