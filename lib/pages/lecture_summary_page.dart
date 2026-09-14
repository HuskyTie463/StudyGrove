import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/lecture_lab_service.dart';
import '../theme/design_tokens.dart';
import '../ui/math_text.dart';
import '../ui/sg_primitives.dart';

class LectureSummaryPage extends StatelessWidget {
  const LectureSummaryPage({
    super.key,
    required this.lecture,
    required this.service,
  });

  final LectureNote lecture;
  final LectureLabService service;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Lecture summary'),
      ),
      body: StreamBuilder<List<ReviewTopic>>(
        stream: service.streamTopics(),
        builder: (context, snap) {
          final topics = (snap.data ?? const <ReviewTopic>[])
              .where(
                (topic) =>
                    topic.sourceLectureId == lecture.id ||
                    lecture.topicIds.contains(topic.id),
              )
              .toList();
          final ideas = lecture.keyIdeas.isNotEmpty
              ? lecture.keyIdeas
              : topics
                  .map(
                    (topic) => LectureKeyIdea(
                      title: topic.title,
                      detail: topic.questions
                          .map((q) => (q.answer ?? '').trim())
                          .where((s) => s.isNotEmpty)
                          .take(2)
                          .join(' '),
                    ),
                  )
                  .toList();
          final summary = (lecture.summary ?? '').trim().isNotEmpty
              ? lecture.summary!.trim()
              : (topics.isEmpty
                  ? null
                  : 'This lecture covers ${topics.map((e) => e.title).take(8).join(', ')}${topics.length > 8 ? '…' : ''}.');
          final objectives = lecture.learningObjectives.isNotEmpty
              ? lecture.learningObjectives
              : topics
                  .map((e) => (e.learningObjective ?? '').trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(
              t.gap(2.5),
              t.gap(1.5),
              t.gap(2.5),
              t.gap(4),
            ),
            children: [
              Text(
                lecture.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (lecture.course != null) ...[
                SizedBox(height: t.gap(0.5)),
                Text(lecture.course!, style: TextStyle(color: t.textMuted)),
              ],
              SizedBox(height: t.gap(2.5)),
              Text('Overview', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: t.gap(1)),
              SgCard(
                child: summary == null
                    ? Text(
                        'No overview yet. Extract with AI to build one from this lecture.',
                        style: TextStyle(color: t.textMuted, height: 1.45),
                      )
                    : MathText(summary, style: const TextStyle(height: 1.5)),
              ),
              if (objectives.isNotEmpty) ...[
                SizedBox(height: t.gap(2.5)),
                Text(
                  'Learning objectives',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: t.gap(1)),
                SgCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < objectives.length; i++) ...[
                        if (i > 0) SizedBox(height: t.gap(1)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${i + 1}.  ',
                              style: TextStyle(
                                color: t.primaryAction,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Expanded(child: MathText(objectives[i])),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (ideas.isNotEmpty) ...[
                SizedBox(height: t.gap(2.5)),
                Text(
                  'Key ideas and concepts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: t.gap(1)),
                ...ideas.map(
                  (idea) => Padding(
                    padding: EdgeInsets.only(bottom: t.gap(1.25)),
                    child: SgCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MathText(
                            idea.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (idea.detail.trim().isNotEmpty) ...[
                            SizedBox(height: t.gap(0.75)),
                            MathText(
                              idea.detail,
                              style: TextStyle(
                                color: t.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (lecture.tables.isNotEmpty) ...[
                SizedBox(height: t.gap(2.5)),
                Text('Tables', style: Theme.of(context).textTheme.titleLarge),
                SizedBox(height: t.gap(1)),
                ...lecture.tables.map(
                  (table) => Padding(
                    padding: EdgeInsets.only(bottom: t.gap(1.5)),
                    child: SgCard(child: _LectureTableView(table: table)),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LectureTableView extends StatelessWidget {
  const _LectureTableView({required this.table});

  final LectureTable table;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colCount = [
      table.headers.length,
      ...table.rows.map((r) => r.length),
    ].fold<int>(1, (m, n) => n > m ? n : m);

    Widget cell(String text, {required bool header}) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: MathText(
          text,
          style: TextStyle(
            fontWeight: header ? FontWeight.w700 : FontWeight.w500,
            fontSize: header ? 12 : 13,
            height: 1.35,
            color: header ? t.textMuted : t.textPrimary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((table.caption ?? '').trim().isNotEmpty) ...[
          MathText(
            table.caption!,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: t.gap(1)),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder(
              horizontalInside: BorderSide(
                color: t.border.withValues(alpha: 0.35),
              ),
              top: BorderSide(color: t.border.withValues(alpha: 0.35)),
              bottom: BorderSide(color: t.border.withValues(alpha: 0.35)),
              left: BorderSide(color: t.border.withValues(alpha: 0.35)),
              right: BorderSide(color: t.border.withValues(alpha: 0.35)),
            ),
            children: [
              if (table.headers.isNotEmpty)
                TableRow(
                  decoration: BoxDecoration(
                    color: t.bgMuted.withValues(alpha: 0.7),
                  ),
                  children: [
                    for (var c = 0; c < colCount; c++)
                      cell(
                        c < table.headers.length ? table.headers[c] : '',
                        header: true,
                      ),
                  ],
                ),
              for (final row in table.rows)
                TableRow(
                  children: [
                    for (var c = 0; c < colCount; c++)
                      cell(c < row.length ? row[c] : '', header: false),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
