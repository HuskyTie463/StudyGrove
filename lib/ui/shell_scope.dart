import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/profile_service.dart';
import 'shell_nav.dart';

class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.page,
    required this.subjectId,
    required this.subjects,
    required this.profile,
    required this.goTo,
    required this.setSubjectId,
    required super.child,
  });

  final AppPage page;
  final String? subjectId;
  final List<Subject> subjects;
  final ProfileService profile;
  final ValueChanged<AppPage> goTo;
  final ValueChanged<String?> setSubjectId;

  Subject? get subject {
    final id = subjectId;
    if (id == null) return null;
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool matches({String? itemSubjectId, String? course, String? title}) {
    return matchesSelectedSubject(
      selectedId: subjectId,
      subjects: subjects,
      itemSubjectId: itemSubjectId,
      course: course,
      title: title,
    );
  }

  static ShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>();
  }

  static ShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'ShellScope not found');
    return scope!;
  }

  @override
  bool updateShouldNotify(ShellScope old) {
    return page != old.page ||
        subjectId != old.subjectId ||
        subjects != old.subjects ||
        profile != old.profile;
  }
}

bool matchesSelectedSubject({
  required String? selectedId,
  required List<Subject> subjects,
  String? itemSubjectId,
  String? course,
  String? title,
}) {
  if (selectedId == null || selectedId.isEmpty) return true;
  if (itemSubjectId == selectedId) return true;
  if (itemSubjectId != null && itemSubjectId.isNotEmpty) return false;
  Subject? selected;
  for (final s in subjects) {
    if (s.id == selectedId) {
      selected = s;
      break;
    }
  }
  if (selected == null) return false;
  final hay = '${course ?? ''} ${title ?? ''}'.toLowerCase();
  if (hay.trim().isEmpty) return false;
  final needles = <String>[
    selected.name,
    if (selected.code != null && selected.code!.trim().isNotEmpty) selected.code!,
    selected.label,
  ].map((s) => s.toLowerCase().trim()).where((s) => s.isNotEmpty);
  for (final n in needles) {
    if (hay.contains(n)) return true;
  }
  return false;
}

List<T> scopedWhere<T>(
  BuildContext context,
  Iterable<T> items,
  String? Function(T) subjectId, {
  String? Function(T)? course,
  String? Function(T)? title,
}) {
  final scope = ShellScope.maybeOf(context);
  if (scope == null || scope.subjectId == null) return items.toList();
  return items
      .where(
        (item) => scope.matches(
          itemSubjectId: subjectId(item),
          course: course?.call(item),
          title: title?.call(item),
        ),
      )
      .toList();
}
