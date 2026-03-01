import 'package:flutter/material.dart';

import '../models/diary_models.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.weeks});

  final List<WeekDto> weeks;

  @override
  Widget build(BuildContext context) {
    final results = SubjectResult.fromWeeks(weeks);
    if (results.isEmpty) {
      return const Center(child: Text('Итогов пока нет'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (_, index) {
        final item = results[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.subject, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: item.marks
                      .map(
                        (mark) => Chip(
                          label: Text(mark.toString()),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Text('Средний: ${item.average.toStringAsFixed(2)} • Оценок: ${item.marksCount}'),
              ],
            ),
          ),
        );
      },
    );
  }
}

