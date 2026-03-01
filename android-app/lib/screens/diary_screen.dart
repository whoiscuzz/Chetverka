import 'package:flutter/material.dart';

import '../models/diary_models.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.weeks});

  final List<WeekDto> weeks;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  int selectedWeek = 0;

  @override
  void didUpdateWidget(covariant DiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selectedWeek >= widget.weeks.length) {
      selectedWeek = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.weeks.isEmpty) {
      return const Center(child: Text('Данных нет'));
    }

    final week = widget.weeks[selectedWeek];

    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, index) {
              final selected = index == selectedWeek;
              return ChoiceChip(
                selected: selected,
                label: Text(widget.weeks[index].monday),
                onSelected: (_) => setState(() => selectedWeek = index),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: widget.weeks.length,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
            itemCount: week.days.length,
            itemBuilder: (_, dayIndex) {
              final day = week.days[dayIndex];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${day.name} • ${day.date}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      if (day.lessons.isEmpty)
                        const Text('Уроков нет')
                      else
                        ...day.lessons.map(
                          (lesson) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(lesson.subject),
                            subtitle: (lesson.hw ?? '').trim().isEmpty
                                ? null
                                : Text('ДЗ: ${lesson.hw}'),
                            trailing: (lesson.mark ?? '').trim().isEmpty
                                ? const Text('—')
                                : Text(
                                    lesson.mark!,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                          ),
                        )
                    ],
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}

