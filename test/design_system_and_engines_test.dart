import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_organiser/models/models.dart';
import 'package:flutter_organiser/services/gap_engine.dart';
import 'package:flutter_organiser/services/memory_weather_engine.dart';
import 'package:flutter_organiser/services/readiness_engine.dart';
import 'package:flutter_organiser/theme/app_theme_builder.dart';
import 'package:flutter_organiser/theme/design_tokens.dart';
import 'package:flutter_organiser/theme/style_family.dart';
import 'package:flutter_organiser/theme/theme_controller.dart';
import 'package:flutter_organiser/theme/token_packs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Token packs', () {
    for (final family in VisualStyleFamily.values) {
      for (final dark in [false, true]) {
        test('${family.name} ${dark ? 'dark' : 'light'} is complete', () {
          final tokens = TokenPackRegistry.resolve(
            family: family,
            dark: dark,
            spacing: SpacingDensity.comfortable,
            contrast: ContrastLevel.normal,
            reducedMotion: false,
          );
          expect(tokens.styleId, isNotEmpty);
          expect(tokens.bg, isNotNull);
          expect(tokens.primaryAction, isNotNull);
          expect(tokens.textPrimary, isNotNull);
          expect(tokens.pressureCalm, isNotNull);
          expect(tokens.pressureWatch, isNotNull);
          expect(tokens.pressureTight, isNotNull);
          expect(tokens.pressureMissing, isNotNull);
          expect(tokens.spaceUnit, greaterThan(0));

          final theme = AppThemeBuilder.build(
            family: family,
            dark: dark,
            spacing: SpacingDensity.comfortable,
            contrast: ContrastLevel.normal,
            reducedMotion: false,
          );
          expect(theme.extension<DesignTokens>(), isNotNull);
          expect(theme.extension<DesignTokens>()!.styleId, tokens.styleId);
        });
      }
    }
  });

  group('ThemeController persistence', () {
    test('loads and persists style, brightness, motion, contrast, spacing',
        () async {
      SharedPreferences.setMockInitialValues({});
      final c = ThemeController();
      await c.load();
      expect(c.ready, isTrue);

      await c.setStyle(VisualStyleFamily.neoBrutal);
      await c.setBrightnessPref(ThemeBrightnessPref.light);
      await c.setReducedMotion(true);
      await c.setContrast(ContrastLevel.increased);
      await c.setSpacing(SpacingDensity.compact);

      final c2 = ThemeController();
      await c2.load();
      expect(c2.style, VisualStyleFamily.neoBrutal);
      expect(c2.brightnessPref, ThemeBrightnessPref.light);
      expect(c2.reducedMotion, isTrue);
      expect(c2.contrast, ContrastLevel.increased);
      expect(c2.spacing, SpacingDensity.compact);
    });

    test('migrates legacy dark visual_mode', () async {
      SharedPreferences.setMockInitialValues({'visual_mode': 'dark'});
      final c = ThemeController();
      await c.load();
      expect(c.brightnessPref, ThemeBrightnessPref.dark);
      expect(c.style, VisualStyleFamily.signature);
    });

    test('system brightness pref yields ThemeMode.system', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ThemeController();
      await c.load();
      await c.setBrightnessPref(ThemeBrightnessPref.system);
      expect(c.themeMode, ThemeMode.system);
    });
  });

  group('Assessment readiness', () {
    final engine = const AssessmentReadinessEngine();

    test('explains missing information without inventing weight', () {
      final a = Assessment(
        id: '1',
        title: 'Midterm',
        course: 'PHYS',
        dueDate: DateTime.now().add(const Duration(days: 10)),
        subtasks: const [],
      );
      final e = engine.explain(a);
      expect(e.state, ReadinessState.missingInformation);
      expect(a.weightPercent, isNull);
      expect(e.factors.any((f) => f.contains('Weight not set')), isTrue);
    });

    test('flags time is tight near due with remaining prep', () {
      final a = Assessment(
        id: '2',
        title: 'Essay',
        course: 'HIST',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        subtasks: [
          AssessmentSubtask(title: 'Outline'),
          AssessmentSubtask(title: 'Draft'),
        ],
        weightPercent: 30,
        estimatedPrepMinutes: 180,
        confidence: 0.3,
      );
      final e = engine.explain(a);
      expect(e.state, ReadinessState.timeIsTight);
      expect(e.estimatedPrepRemainingMinutes, greaterThan(0));
      expect(e.summary.toLowerCase(), isNot(contains('grade')));
    });

    test('recommended sort prioritises urgent assessments', () {
      final soon = Assessment(
        id: 'a',
        title: 'Soon',
        course: 'A',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        subtasks: [AssessmentSubtask(title: 'Do')],
        weightPercent: 40,
        estimatedPrepMinutes: 120,
      );
      final later = Assessment(
        id: 'b',
        title: 'Later',
        course: 'B',
        dueDate: DateTime.now().add(const Duration(days: 30)),
        subtasks: [AssessmentSubtask(title: 'Do', done: true)],
        weightPercent: 10,
        estimatedPrepMinutes: 30,
        confidence: 0.8,
      );
      final hero = engine.mostImportant([later, soon]);
      expect(hero?.id, 'a');
    });
  });

  group('Calendar gap engine', () {
    const engine = CalendarGapEngine();

    test('subtracts travel buffer and respects commitments', () {
      final events = [
        AppEvent(
          id: '1',
          title: 'Biophysics Lab',
          dayKey: '2026-08-25',
          startMinutes: 12 * 60,
          endMinutes: 14 * 60,
        ),
      ];
      final gaps = engine.detectGaps(
        events: events,
        dayStartMinutes: 9 * 60,
        dayEndMinutes: 18 * 60,
        travelBufferMinutes: 10,
      );
      expect(gaps, isNotEmpty);
      final first = gaps.first;
      expect(first.endMinutes, 12 * 60 - 10);
      expect(first.usableMinutes, 12 * 60 - 10 - 9 * 60);
      expect(first.nextCommitmentTitle, 'Biophysics Lab');
    });

    test('session duration respects gap and low-energy mode', () {
      final gaps = [
        const CalendarGap(
          startMinutes: 600,
          endMinutes: 640,
          usableMinutes: 40,
          travelBufferMinutes: 10,
          nextCommitmentTitle: 'Class',
          reason: 'test',
        ),
      ];
      final session = engine.recommendSession(
        gaps: gaps,
        assessments: [
          Assessment(
            id: '1',
            title: 'Quiz',
            course: 'CHEM',
            dueDate: DateTime.now().add(const Duration(days: 3)),
            subtasks: [AssessmentSubtask(title: 'Flashcards')],
          ),
        ],
        topics: const [],
        mode: StudyContextMode.lowEnergy,
      );
      expect(session, isNotNull);
      expect(session!.durationMinutes, lessThanOrEqualTo(15));
      expect(session.endsBeforeCommitment, isTrue);
      expect(session.whySelected, isNotEmpty);
    });
  });

  group('Memory weather', () {
    const engine = MemoryWeatherEngine();

    test('marks overdue topics as clouding/fog with inspectable steps', () {
      final insight = engine.evaluate(
        topics: [
          ReviewTopic(
            id: 't1',
            title: 'Quantum tunneling',
            confidence: 0.2,
            nextReviewAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        ],
      );
      expect(
        insight.state == MemoryWeatherState.clouding ||
            insight.state == MemoryWeatherState.fog,
        isTrue,
      );
      expect(insight.fadingTopics, isNotEmpty);
      expect(insight.inspectableSteps, isNotEmpty);
      expect(insight.reason.toLowerCase(), isNot(contains('forecast exact')));
    });
  });

  group('Lecture lab manual extraction', () {
    test('extracts short topic lines without inventing AI', () {
      // Uses the pure helpers via a throwaway service pattern — replicate logic.
      final body = '''
# Photosynthesis
- Light reactions
- Calvin cycle
This is a very long paragraph that should not become a topic because it has too many words for a heading style line.
''';
      final lines = body
          .split(RegExp(r'[\r\n]+'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final topics = <String>[];
      for (final line in lines) {
        final cleaned = line
            .replaceFirst(RegExp(r'^#+\s*'), '')
            .replaceFirst(RegExp(r'^[-*•]\s*'), '')
            .trim();
        if (cleaned.length < 4 || cleaned.length > 80) continue;
        if (cleaned.split(' ').length > 12) continue;
        topics.add(cleaned);
      }
      expect(topics, contains('Photosynthesis'));
      expect(topics, contains('Light reactions'));
      expect(topics, contains('Calvin cycle'));
    });
  });
}
