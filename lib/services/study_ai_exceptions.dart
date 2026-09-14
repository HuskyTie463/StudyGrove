import 'subscription_catalog.dart';

class StudyAiProRequiredException implements Exception {
  @override
  String toString() =>
      'Study AI is included with Pro. Upgrade to unlock Lecture Lab, Review, '
      'Voice Chat, and Study AI.';
}

class StudyAiAllowanceException implements Exception {
  StudyAiAllowanceException({required this.resetsOn});

  final DateTime resetsOn;

  @override
  String toString() {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final when = '1 ${months[resetsOn.month - 1]} ${resetsOn.year}';
    return 'You have used this month’s ${SubscriptionCatalog.monthlyAiUses} '
        'Study AI uses. They reset on $when. Home, Plan, and Subjects stay open.';
  }
}
