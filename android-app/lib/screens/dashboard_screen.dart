import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_models.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.weeks,
    required this.onRefresh,
    required this.loading,
    required this.error,
  });

  final List<WeekDto> weeks;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayLessons = todayLessonsCount(weeks, now);
    final todayHw = todayHomeworkCount(weeks, now);
    final subjectResults = SubjectResult.fromWeeks(weeks);
    final avg = subjectResults.isEmpty
        ? 0.0
        : subjectResults.map((e) => e.average).reduce((a, b) => a + b) /
            subjectResults.length;
    final recent = recentMarks(weeks);
    final weak = weakSubjects(weeks);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(dateText: DateFormat('d MMMM, EEEE', 'ru').format(now)),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatCard(title: 'Уроков', value: '$todayLessons', icon: Icons.menu_book),
              const SizedBox(width: 10),
              _StatCard(title: 'ДЗ', value: '$todayHw', icon: Icons.assignment_turned_in),
              const SizedBox(width: 10),
              _StatCard(title: 'Средний', value: avg == 0 ? '—' : avg.toStringAsFixed(2), icon: Icons.star),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Последние оценки',
            child: recent.isEmpty
                ? const Text('Оценок пока нет')
                : Column(
                    children: recent
                        .map((item) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.$1),
                              trailing: CircleAvatar(
                                backgroundColor: AppColors.accent.withOpacity(0.15),
                                child: Text(item.$2, style: const TextStyle(color: AppColors.deepBlue)),
                              ),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Требуют внимания',
            child: weak.isEmpty
                ? const Text('Все предметы в норме')
                : Column(
                    children: weak
                        .map((item) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.warning_amber, color: AppColors.warn),
                              title: Text(item.$1),
                              trailing: Text(item.$2.toStringAsFixed(2)),
                            ))
                        .toList(),
                  ),
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          if (loading) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ]
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.dateText});

  final String dateText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.deepBlue, AppColors.ocean],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Health-style layout, school flow',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'Главная',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(dateText, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: AppColors.deepBlue),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

