import 'dart:math';

class DiaryResponse {
  const DiaryResponse({required this.weeks});

  final List<WeekDto> weeks;

  factory DiaryResponse.fromJson(Map<String, dynamic> json) {
    final rawWeeks = json['weeks'] as List<dynamic>? ?? const [];
    return DiaryResponse(
      weeks: rawWeeks
          .whereType<Map<String, dynamic>>()
          .map(WeekDto.fromJson)
          .toList(),
    );
  }
}

class WeekDto {
  const WeekDto({required this.monday, required this.days});

  final String monday;
  final List<DayDto> days;

  factory WeekDto.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? const [];
    return WeekDto(
      monday: (json['monday'] ?? '').toString(),
      days: rawDays
          .whereType<Map<String, dynamic>>()
          .map(DayDto.fromJson)
          .toList(),
    );
  }
}

class DayDto {
  const DayDto({required this.date, required this.name, required this.lessons});

  final String date;
  final String name;
  final List<LessonDto> lessons;

  factory DayDto.fromJson(Map<String, dynamic> json) {
    final rawLessons = json['lessons'] as List<dynamic>? ?? const [];
    return DayDto(
      date: (json['date'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      lessons: rawLessons
          .whereType<Map<String, dynamic>>()
          .map(LessonDto.fromJson)
          .toList(),
    );
  }
}

class LessonDto {
  const LessonDto({
    required this.subject,
    this.mark,
    this.hw,
    this.cabinet,
    this.attachments = const [],
  });

  final String subject;
  final String? mark;
  final String? hw;
  final String? cabinet;
  final List<LessonAttachment> attachments;

  factory LessonDto.fromJson(Map<String, dynamic> json) {
    final rawAttachments = json['attachments'] as List<dynamic>? ?? const [];
    return LessonDto(
      subject: (json['subject'] ?? '').toString(),
      mark: json['mark']?.toString(),
      hw: json['hw']?.toString(),
      cabinet: json['cabinet']?.toString(),
      attachments: rawAttachments
          .whereType<Map<String, dynamic>>()
          .map(LessonAttachment.fromJson)
          .toList(),
    );
  }

  int? get markInt {
    final raw = (mark ?? '').trim();
    if (raw.isEmpty) return null;

    if (raw.contains('/')) {
      final parts = raw.split('/');
      if (parts.length == 2) {
        final left = double.tryParse(parts.first.replaceAll(',', '.'));
        final right = double.tryParse(parts.last.replaceAll(',', '.'));
        if (left != null && right != null) {
          return ((left + right) / 2).round();
        }
      }
    }

    final direct = int.tryParse(raw);
    if (direct != null) return direct;

    final number = RegExp(r'\d+([\.,]\d+)?').firstMatch(raw)?.group(0);
    if (number == null) return null;
    final parsed = double.tryParse(number.replaceAll(',', '.'));
    if (parsed == null) return null;
    return parsed.round();
  }

  String get safeSubject {
    return subject.trim().toLowerCase();
  }
}

class LessonAttachment {
  const LessonAttachment({
    required this.name,
    this.url,
    this.type,
  });

  final String name;
  final String? url;
  final String? type;

  factory LessonAttachment.fromJson(Map<String, dynamic> json) {
    return LessonAttachment(
      name: (json['name'] ?? '').toString(),
      url: json['url']?.toString(),
      type: json['type']?.toString(),
    );
  }
}

class SubjectResult {
  const SubjectResult({
    required this.subject,
    required this.average,
    required this.marks,
  });

  final String subject;
  final double average;
  final List<int> marks;

  int get marksCount => marks.length;

  static List<SubjectResult> fromWeeks(List<WeekDto> weeks) {
    final map = <String, List<int>>{};

    for (final week in weeks) {
      for (final day in week.days) {
        for (final lesson in day.lessons) {
          final mark = lesson.markInt;
          if (mark == null) continue;
          map.putIfAbsent(lesson.safeSubject, () => []).add(mark);
        }
      }
    }

    final results = map.entries
        .map(
          (entry) => SubjectResult(
            subject: _capitalize(entry.key),
            average: entry.value.fold<int>(0, (a, b) => a + b) / entry.value.length,
            marks: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) => b.average.compareTo(a.average));

    return results;
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

double averageFromMarks(List<int> marks) {
  if (marks.isEmpty) return 0;
  return marks.reduce((a, b) => a + b) / marks.length;
}

int todayLessonsCount(List<WeekDto> weeks, DateTime now) {
  return _findTodayLessons(weeks, now).length;
}

int todayHomeworkCount(List<WeekDto> weeks, DateTime now) {
  final lessons = _findTodayLessons(weeks, now);
  return lessons.where((item) => (item.hw ?? '').trim().isNotEmpty).length;
}

List<LessonDto> _findTodayLessons(List<WeekDto> weeks, DateTime now) {
  final today =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  for (final week in weeks) {
    for (final day in week.days) {
      if (day.date == today) return day.lessons;
    }
  }
  return const [];
}

List<(String, String)> recentMarks(List<WeekDto> weeks) {
  final rows = <(String, String)>[];

  for (final week in weeks) {
    for (final day in week.days) {
      for (final lesson in day.lessons) {
        if ((lesson.mark ?? '').trim().isNotEmpty) {
          rows.add((SubjectResult._capitalize(lesson.safeSubject), lesson.mark!.trim()));
        }
      }
    }
  }

  return rows.reversed.take(4).toList();
}

List<(String, double)> weakSubjects(List<WeekDto> weeks) {
  final map = <String, List<int>>{};

  for (final week in weeks) {
    for (final day in week.days) {
      for (final lesson in day.lessons) {
        final mark = lesson.markInt;
        if (mark == null) continue;
        map.putIfAbsent(lesson.safeSubject, () => []).add(mark);
      }
    }
  }

  final weak = map.entries
      .map((entry) {
        final avg = averageFromMarks(entry.value);
        return (SubjectResult._capitalize(entry.key), avg);
      })
      .where((item) => item.$2 < 6.5)
      .toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));

  return weak.take(min(2, weak.length)).toList();
}

