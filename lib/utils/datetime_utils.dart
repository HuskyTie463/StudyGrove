import 'package:flutter/material.dart';

String dayKey(DateTime d) {
  final dd = DateTime(d.year, d.month, d.day);
  final m = dd.month.toString().padLeft(2, '0');
  final day = dd.day.toString().padLeft(2, '0');
  return "${dd.year}-$m-$day";
}

int timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

TimeOfDay minutesToTimeOfDay(int minutes) {
  final clamped = minutes.clamp(0, 24 * 60 - 1);
  return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
}

/// Ensures end is after start; defaults missing end to +60 minutes.
int resolveEndMinutes(int startMinutes, int? endMinutes) {
  final fallback = (startMinutes + 60).clamp(0, 24 * 60);
  if (endMinutes == null) return fallback;
  if (endMinutes <= startMinutes) return fallback;
  return endMinutes.clamp(0, 24 * 60);
}

String formatTimeRange(BuildContext context, int startMinutes, int endMinutes) {
  final start = minutesToTimeOfDay(startMinutes).format(context);
  final end = minutesToTimeOfDay(endMinutes).format(context);
  return '$start – $end';
}

String formatDurationLabel(int startMinutes, int endMinutes) {
  final mins = (endMinutes - startMinutes).clamp(0, 24 * 60);
  if (mins < 60) return '${mins}m';
  final h = mins ~/ 60;
  final m = mins % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}
