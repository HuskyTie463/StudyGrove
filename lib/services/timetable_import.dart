import 'package:flutter/material.dart';

import '../utils/datetime_utils.dart';

class TimetableEventDraft {
  TimetableEventDraft({
    required this.weekday,
    required this.time,
    required this.endTime,
    required this.title,
    this.location,
    this.subjectHint,
  });

  final int weekday; // 1=Mon .. 7=Sun
  final TimeOfDay time;
  final TimeOfDay endTime;
  final String title;
  final String? location;
  final String? subjectHint;
}

class TimetableImportParser {
  static const _dayMap = <String, int>{
    'mon': 1,
    'monday': 1,
    'tue': 2,
    'tues': 2,
    'tuesday': 2,
    'wed': 3,
    'wednesday': 3,
    'thu': 4,
    'thur': 4,
    'thurs': 4,
    'thursday': 4,
    'fri': 5,
    'friday': 5,
    'sat': 6,
    'saturday': 6,
    'sun': 7,
    'sunday': 7,
  };

  /// Parses free-text timetable lines.
  ///
  /// Supported examples:
  /// - `Mon 9:00 MATH101 Tutorial Room 204`
  /// - `Mon 9:00-10:00 MATH101 Tutorial Room 204`
  /// - `Mon 9:00 – 10:30 MATH101 Tutorial Room 204`
  /// - `Tuesday 14:30 Physics Lecture | Hall A`
  /// - `Wed 2pm CHEM Lab @ Building 12`
  static List<TimetableEventDraft> parse(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final out = <TimetableEventDraft>[];
    for (final line in lines) {
      final parsed = _parseLine(line);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  static ({int hour, int minute})? _parseClock(
    String hourStr,
    String? minuteStr,
    String? ampm,
  ) {
    var hour = int.parse(hourStr);
    final minute = int.parse(minuteStr ?? '0');
    final period = ampm?.toLowerCase();
    if (period == 'pm' && hour < 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return (hour: hour, minute: minute);
  }

  static TimetableEventDraft? _parseLine(String line) {
    final match = RegExp(
      r'^([A-Za-z]+)\s+'
      r'(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?'
      r'(?:\s*[-–—]\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|AM|PM)?)?'
      r'\s+(.+)$',
    ).firstMatch(line);
    if (match == null) return null;

    final dayToken = match.group(1)!.toLowerCase();
    final weekday = _dayMap[dayToken];
    if (weekday == null) return null;

    final startClock = _parseClock(match.group(2)!, match.group(3), match.group(4));
    if (startClock == null) return null;

    final start = TimeOfDay(hour: startClock.hour, minute: startClock.minute);
    final startMins = timeToMinutes(start);

    TimeOfDay endTime;
    if (match.group(5) != null) {
      // Inherit am/pm from start when end omits it (e.g. 9:00-10:00 am)
      final endAmpm = match.group(7) ?? match.group(4);
      final endClock = _parseClock(match.group(5)!, match.group(6), endAmpm);
      if (endClock == null) return null;
      endTime = minutesToTimeOfDay(
        resolveEndMinutes(
          startMins,
          endClock.hour * 60 + endClock.minute,
        ),
      );
    } else {
      endTime = minutesToTimeOfDay(resolveEndMinutes(startMins, null));
    }

    var rest = match.group(8)!.trim();
    String? location;

    final locSplit = RegExp(r'\s+[|@]\s+').firstMatch(rest);
    if (locSplit != null) {
      location = rest.substring(locSplit.end).trim();
      rest = rest.substring(0, locSplit.start).trim();
    } else {
      final room = RegExp(
        r'\s+((?:Room|Hall|Building|Lab|Theatre|Theater)\s+.+)$',
        caseSensitive: false,
      ).firstMatch(rest);
      if (room != null) {
        location = room.group(1)!.trim();
        rest = rest.substring(0, room.start).trim();
      }
    }

    if (rest.isEmpty) return null;

    final codeMatch =
        RegExp(r'\b([A-Z]{2,6}\d{2,5}[A-Z]?)\b').firstMatch(rest);
    final hint = codeMatch?.group(1);

    return TimetableEventDraft(
      weekday: weekday,
      time: start,
      endTime: endTime,
      title: rest,
      location: location,
      subjectHint: hint,
    );
  }
}
