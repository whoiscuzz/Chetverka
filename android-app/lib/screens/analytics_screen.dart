import 'package:flutter/material.dart';

import '../models/diary_models.dart';
import '../theme/app_theme.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key, required this.weeks});

  final List<WeekDto> weeks;

  @override
  Widget build(BuildContext context) {
    final results = SubjectResult.fromWeeks(weeks);
    final avg = results.isEmpty
        ? 0.0
        : results.map((e) => e.average).reduce((a, b) => a + b) / results.length;

    if (results.isEmpty) {
      return const Center(child: Text('Нет оценок для аналитики'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: (avg / 10).clamp(0, 1),
                        strokeWidth: 10,
                        color: AppColors.deepBlue,
                        backgroundColor: AppColors.line,
                      ),
                      Text(avg.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text('Текущий средний балл по всем предметам'),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...results.map(
          (item) {
            final widthFactor = (item.average / 10).clamp(0.05, 1.0);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(item.subject, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Text(item.average.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: widthFactor,
                        minHeight: 10,
                        color: AppColors.accent,
                        backgroundColor: AppColors.line,
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        )
      ],
    );
  }
}

