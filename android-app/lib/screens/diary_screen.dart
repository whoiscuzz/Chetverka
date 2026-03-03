import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_models.dart';
import '../theme/app_theme.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key, required this.weeks});

  final List<WeekDto> weeks;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late int selectedWeek;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    selectedWeek = currentWeekIndex(widget.weeks, DateTime.now());
    _pageController = PageController(initialPage: selectedWeek);
  }

  @override
  void didUpdateWidget(covariant DiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.weeks.isEmpty) {
      selectedWeek = 0;
      _pageController?.dispose();
      _pageController = null;
      return;
    }

    if (_pageController == null) {
      selectedWeek = currentWeekIndex(widget.weeks, DateTime.now());
      _pageController = PageController(initialPage: selectedWeek);
      return;
    }

    if (oldWidget.weeks != widget.weeks) {
      final suggested = currentWeekIndex(widget.weeks, DateTime.now());
      selectedWeek = suggested.clamp(0, widget.weeks.length - 1);
      _pageController!.jumpToPage(selectedWeek);
      setState(() {});
    } else if (selectedWeek >= widget.weeks.length) {
      selectedWeek = widget.weeks.length - 1;
      _pageController!.jumpToPage(selectedWeek);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.weeks.isEmpty) {
      return const Center(child: Text('Данных нет'));
    }

    final week = widget.weeks[selectedWeek];
    final weekLabel = _weekRangeLabel(week);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: selectedWeek > 0 ? () => _jumpToWeek(selectedWeek - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                          .animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    weekLabel,
                    key: ValueKey(weekLabel),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                onPressed: selectedWeek < widget.weeks.length - 1 ? () => _jumpToWeek(selectedWeek + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 50,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemBuilder: (_, index) {
              final selected = index == selectedWeek;
              return GestureDetector(
                onTap: () => _jumpToWeek(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.deepBlue : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    widget.weeks[index].monday,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: widget.weeks.length,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.weeks.length,
            onPageChanged: (index) => setState(() => selectedWeek = index),
            itemBuilder: (_, index) {
              final pageWeek = widget.weeks[index];
              return ListView.builder(
                key: ValueKey(pageWeek.monday),
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                itemCount: pageWeek.days.length,
                itemBuilder: (_, dayIndex) {
                  final day = pageWeek.days[dayIndex];
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 220 + dayIndex * 55),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - t)),
                        child: child,
                      ),
                    ),
                    child: Card(
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
                                      ? null
                                      : Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.accent.withOpacity(0.16),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            lesson.mark!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.deepBlue,
                                            ),
                                          ),
                                        ),
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }

  void _jumpToWeek(int index) {
    if (_pageController == null) return;
    setState(() => selectedWeek = index);
    _pageController!.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  String _weekRangeLabel(WeekDto week) {
    final start = DateTime.tryParse(week.monday);
    if (start == null) return week.monday;
    final end = start.add(const Duration(days: 6));
    final dayFmt = DateFormat('d', 'ru');
    final endFmt = DateFormat('d MMMM', 'ru');
    return '${dayFmt.format(start)} - ${endFmt.format(end)}';
  }
}
