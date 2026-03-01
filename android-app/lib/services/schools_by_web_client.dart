import 'dart:collection';
import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/diary_models.dart';
import '../models/profile.dart';

class SchoolsByError implements Exception {
  const SchoolsByError(this.message);

  final String message;

  @override
  String toString() => message;
}

class LoginResponse {
  const LoginResponse({
    required this.sessionId,
    required this.pupilId,
    required this.profile,
  });

  final String sessionId;
  final String pupilId;
  final Profile profile;
}

class SchoolsByWebClient {
  SchoolsByWebClient({http.Client? client}) : _client = client ?? http.Client();

  static const String _base = 'https://schools.by';
  static const String _fallbackBase = 'https://4minsk.schools.by';
  static const String _loginUrl = 'https://schools.by/login';
  static const String _defaultStartWeek = '2026-01-12';
  static const String _defaultQuarterId = '90';
  static const Set<String> _adminPupilIds = {'1106490'};

  final http.Client _client;
  final Map<String, String> _cookies = {};

  Future<void> clearSession() async {
    _cookies.clear();
  }

  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    final sessionId = await _performDirectLogin(username: username, password: password);
    _cookies['sessionid'] = sessionId;

    final (pupilId, activeBase) = await _resolvePupilId(sessionId: sessionId);
    final profileContext = await _resolveProfilePayload(
      pupilId: pupilId,
      preferredBase: activeBase,
    );

    final parsedTitle = _parseTitle(profileContext.$1.title);
    final fullName = parsedTitle.$1.trim().isEmpty ? 'Ученик' : parsedTitle.$1;

    final profile = Profile(
      fullName: fullName,
      className: parsedTitle.$2,
      avatarUrl: _absoluteUrlString(profileContext.$1.avatarUrl, profileContext.$2),
      classTeacher: profileContext.$1.classTeacher,
      role: _adminPupilIds.contains(pupilId) ? 'admin' : 'user',
    );

    return LoginResponse(
      sessionId: sessionId,
      pupilId: pupilId,
      profile: profile,
    );
  }

  Future<DiaryResponse> fetchDiary({
    required String pupilId,
    String? sessionId,
  }) async {
    if (sessionId != null && sessionId.isNotEmpty) {
      _cookies['sessionid'] = sessionId;
    }

    var activeBase = _base;
    final diaryContext = await _resolveDiaryContext(pupilId: pupilId, preferredBase: activeBase);
    activeBase = diaryContext.base;

    final quarterId = diaryContext.quarterId ?? _defaultQuarterId;
    final discoveredWeek = await _discoverStartWeek(
      pupilId: pupilId,
      quarterId: quarterId,
      activeBase: activeBase,
    );
    final startWeek = diaryContext.weekId ?? discoveredWeek ?? _defaultStartWeek;

    final visited = <String>{};
    final pending = Queue<String>()..add(startWeek);
    final weeksByMonday = <String, WeekDto>{};

    var safetyCounter = 0;
    while (pending.isNotEmpty) {
      final weekId = pending.removeFirst();
      if (visited.contains(weekId)) continue;
      visited.add(weekId);

      safetyCounter += 1;
      if (safetyCounter > 160) break;

      final payload = await _loadWeekPayload(
        pupilId: pupilId,
        quarterId: quarterId,
        weekId: weekId,
        activeBase: activeBase,
      );

      if (!payload.ok) {
        if (weeksByMonday.isEmpty) {
          throw const SchoolsByError(
            'Дневник недоступен: блок расписания не найден.',
          );
        }
        continue;
      }

      final days = <DayDto>[];
      for (var i = 0; i < payload.days.length; i++) {
        final sourceDay = payload.days[i];
        final dayDate = _addDays(weekId, i);

        final lessons = sourceDay.lessons
            .map(
              (lesson) => LessonDto(
                subject: lesson.subject,
                mark: lesson.mark,
                hw: lesson.hw,
                cabinet: lesson.cabinet,
                attachments: lesson.attachments
                    .map(
                      (a) => LessonAttachment(
                        name: a.name,
                        url: _absoluteUrlString(a.url, activeBase),
                        type: a.type,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();

        days.add(DayDto(date: dayDate, name: sourceDay.name, lessons: lessons));
      }

      final resolvedDays = await _resolveAttachmentLinks(days: days, activeBase: activeBase);
      weeksByMonday[weekId] = WeekDto(monday: weekId, days: resolvedDays);

      for (final candidate in [payload.nextWeek, payload.prevWeek]) {
        if (candidate == null || !_isIsoWeek(candidate)) continue;
        if (!visited.contains(candidate) && !pending.contains(candidate)) {
          pending.add(candidate);
        }
      }
    }

    final weeks = weeksByMonday.values.toList()..sort((a, b) => a.monday.compareTo(b.monday));
    return DiaryResponse(weeks: weeks);
  }

  Future<String> _performDirectLogin({
    required String username,
    required String password,
  }) async {
    final getResponse = await _client.get(
      Uri.parse(_loginUrl),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8',
      },
    );
    _storeCookiesFromResponse(getResponse);

    if (getResponse.statusCode < 200 || getResponse.statusCode > 299) {
      throw const SchoolsByError('Не удалось открыть страницу входа.');
    }

    final csrf = _firstRegexCapture(
      getResponse.body,
      r'name=["\']csrfmiddlewaretoken["\'][^>]*value=["\']([^"\']+)["\']',
    );
    if (csrf == null || csrf.isEmpty) {
      throw const SchoolsByError('Не удалось получить CSRF токен.');
    }

    final csrfCookie = _cookies['csrftoken'] ?? csrf;

    final postResponse = await _client.post(
      Uri.parse(_loginUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': 'https://schools.by',
        'Referer': 'https://schools.by/login',
        'User-Agent': 'Mozilla/5.0',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8',
        'X-CSRFToken': csrf,
        'Cookie': _cookieHeader(extra: {
          'csrftoken': csrfCookie,
          'function-cookie': 'on',
          'static_cookie': 'on',
          'advertising_cookie': 'on',
        }),
      },
      body: {
        'csrfmiddlewaretoken': csrf,
        'username': username,
        'password': password,
        'function-cookie': 'on',
        'static_cookie': 'on',
        'advertising_cookie': 'on',
        '|123': '|123',
      },
      encoding: utf8,
    );
    _storeCookiesFromResponse(postResponse);

    if (postResponse.statusCode < 200 || postResponse.statusCode > 399) {
      throw SchoolsByError('Ошибка входа (${postResponse.statusCode}).');
    }

    if (postResponse.body.contains('Пожалуйста, введите правильные имя пользователя и пароль')) {
      throw const SchoolsByError('Неверный логин или пароль.');
    }

    final sessionId = _cookies['sessionid'];
    if (sessionId != null && sessionId.isNotEmpty) {
      return sessionId;
    }

    final warmed = await _warmupAndReadSessionCookie(csrfCookie: csrfCookie);
    if (warmed != null && warmed.isNotEmpty) {
      return warmed;
    }

    throw const SchoolsByError('Не удалось получить sessionid.');
  }

  Future<String?> _warmupAndReadSessionCookie({required String csrfCookie}) async {
    final urls = [
      Uri.parse('https://schools.by/m/'),
      Uri.parse('https://4minsk.schools.by/m/'),
    ];

    for (final url in urls) {
      final response = await _client.get(
        url,
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8',
          'Cookie': _cookieHeader(extra: {
            'csrftoken': csrfCookie,
            'function-cookie': 'on',
            'static_cookie': 'on',
            'advertising_cookie': 'on',
          }),
        },
      );
      _storeCookiesFromResponse(response);

      final session = _cookies['sessionid'];
      if (session != null && session.isNotEmpty) {
        return session;
      }
    }

    return null;
  }

  Future<(String, String)> _resolvePupilId({required String sessionId}) async {
    final viaHttp = await _fetchPupilIdViaHttp(sessionId: sessionId);
    if (viaHttp != null) return viaHttp;
    throw const SchoolsByError('Не удалось определить pupilid.');
  }

  Future<(String, String)?> _fetchPupilIdViaHttp({required String sessionId}) async {
    for (final host in [_base, _fallbackBase]) {
      final response = await _client.get(
        Uri.parse('$host/m/'),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Cookie': _cookieHeader(extra: {'sessionid': sessionId}),
        },
      );
      _storeCookiesFromResponse(response);

      if (response.statusCode < 200 || response.statusCode > 399) continue;

      final href = _firstRegexCapture(response.body, r'(\/pupil\/\d+[^"\']*)');
      final pupilId = href == null ? null : _extractPupilId(href);
      if (pupilId != null && pupilId.isNotEmpty) {
        return (pupilId, host);
      }
    }

    return null;
  }

  Future<(_ProfilePayload, String)> _resolveProfilePayload({
    required String pupilId,
    required String preferredBase,
  }) async {
    final primaryBase = await _loadWithHostFallback(
      path: '/pupil/$pupilId/',
      preferredBase: preferredBase,
    );

    var payload = await _readProfilePayloadFromPath(
      base: primaryBase,
      path: '/pupil/$pupilId/',
    );

    if (payload.title.trim().isEmpty) {
      final menuName = await _readMenuDisplayNameFromPath(base: primaryBase, path: '/m/');
      if (menuName != null && menuName.isNotEmpty) {
        payload = _ProfilePayload(
          title: menuName,
          avatarUrl: payload.avatarUrl,
          classTeacher: payload.classTeacher,
        );
      }
    }

    if (payload.title.trim().isNotEmpty) {
      return (payload, primaryBase);
    }

    if (primaryBase != _fallbackBase) {
      final fallbackPayload = await _readProfilePayloadFromPath(
        base: _fallbackBase,
        path: '/pupil/$pupilId/',
      );
      if (fallbackPayload.title.trim().isNotEmpty) {
        return (fallbackPayload, _fallbackBase);
      }
    }

    return (payload, primaryBase);
  }

  Future<_ProfilePayload> _readProfilePayloadFromPath({
    required String base,
    required String path,
  }) async {
    final response = await _client.get(
      Uri.parse('$base$path'),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Cookie': _cookieHeader(),
      },
    );
    _storeCookiesFromResponse(response);

    if (response.statusCode < 200 || response.statusCode > 399) {
      throw SchoolsByError('Ошибка загрузки профиля (${response.statusCode}).');
    }

    final document = html_parser.parse(response.body);

    final title = _normalizeSpaces(
      document.querySelector('div.title_box h1')?.text ??
          document.querySelector('h1')?.text ??
          document.querySelector('a.u_name, a.user_name, a.profile-link')?.text ??
          '',
    );

    final avatar = document.querySelector('div.profile-photo__box img')?.attributes['src'] ??
        document.querySelector('img.profile-photo, img.avatar, img.userpic')?.attributes['src'];

    String? teacher;
    for (final line in document.querySelectorAll('div.pp_line_new')) {
      final text = _normalizeSpaces(line.text);
      if (text.contains('Классный руководитель:')) {
        teacher = _normalizeSpaces(text.replaceFirst('Классный руководитель:', ''));
        break;
      }
    }

    if (teacher == null || teacher.isEmpty) {
      final bodyText = _normalizeSpaces(document.body?.text ?? '');
      final match = RegExp(r'Классный\s+руководитель:\s*([^\n\r]+)', caseSensitive: false)
          .firstMatch(bodyText);
      teacher = match?.group(1)?.trim();
    }

    return _ProfilePayload(title: title, avatarUrl: avatar, classTeacher: teacher);
  }

  Future<String?> _readMenuDisplayNameFromPath({
    required String base,
    required String path,
  }) async {
    final response = await _client.get(
      Uri.parse('$base$path'),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Cookie': _cookieHeader(),
      },
    );
    _storeCookiesFromResponse(response);

    if (response.statusCode < 200 || response.statusCode > 399) return null;

    final document = html_parser.parse(response.body);
    final title = _normalizeSpaces(
      document.querySelector('a.u_name, a.user_name, a.profile-link')?.text ?? '',
    );
    return title.isEmpty ? null : title;
  }

  Future<_DiaryContext> _resolveDiaryContext({
    required String pupilId,
    required String preferredBase,
  }) async {
    final primaryBase = await _loadWithHostFallback(
      path: '/m/pupil/$pupilId/dnevnik',
      preferredBase: preferredBase,
    );

    final primaryPaths = await _readDiaryPaths(base: primaryBase, pupilId: pupilId);
    final primaryContext = _buildDiaryContext(paths: primaryPaths, base: primaryBase);
    if (primaryContext.quarterId != null || primaryContext.weekId != null) {
      return primaryContext;
    }

    if (primaryBase != _fallbackBase) {
      final fallbackPaths = await _readDiaryPaths(base: _fallbackBase, pupilId: pupilId);
      final fallbackContext = _buildDiaryContext(paths: fallbackPaths, base: _fallbackBase);
      if (fallbackContext.quarterId != null || fallbackContext.weekId != null) {
        return fallbackContext;
      }
    }

    return primaryContext;
  }

  Future<List<String>> _readDiaryPaths({
    required String base,
    required String pupilId,
  }) async {
    final path = '/m/pupil/$pupilId/dnevnik';
    final response = await _client.get(
      Uri.parse('$base$path'),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Cookie': _cookieHeader(),
      },
    );
    _storeCookiesFromResponse(response);

    if (response.statusCode < 200 || response.statusCode > 399) return [];

    final document = html_parser.parse(response.body);
    final paths = <String>{path};

    final nextWeekId = document.querySelector('a.next')?.attributes['next_week_id'];
    if (nextWeekId != null && _isIsoWeek(nextWeekId)) {
      paths.add('/m/pupil/$pupilId/dnevnik/week/$nextWeekId');
    }

    for (final link in document.querySelectorAll('a[href*="/dnevnik/quarter/"][href*="/week/"]')) {
      final href = link.attributes['href'];
      if (href != null && href.trim().isNotEmpty) {
        paths.add(href.trim());
      }
    }

    return paths.toList();
  }

  _DiaryContext _buildDiaryContext({
    required List<String> paths,
    required String base,
  }) {
    for (final path in paths) {
      final match = RegExp(
        r'/dnevnik/quarter/(\d+)/week/(\d{4}-\d{2}-\d{2})',
        caseSensitive: false,
      ).firstMatch(path);
      if (match != null) {
        return _DiaryContext(
          base: base,
          quarterId: match.group(1),
          weekId: match.group(2),
        );
      }
    }

    for (final path in paths) {
      final quarterMatch = RegExp(r'/dnevnik/quarter/(\d+)', caseSensitive: false).firstMatch(path);
      if (quarterMatch != null) {
        return _DiaryContext(base: base, quarterId: quarterMatch.group(1), weekId: null);
      }
    }

    return _DiaryContext(base: base, quarterId: null, weekId: null);
  }

  Future<String?> _discoverStartWeek({
    required String pupilId,
    required String quarterId,
    required String activeBase,
  }) async {
    final path = '/m/pupil/$pupilId/dnevnik/quarter/$quarterId';
    final response = await _client.get(
      Uri.parse('$activeBase$path'),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Cookie': _cookieHeader(),
      },
    );
    _storeCookiesFromResponse(response);

    if (response.statusCode < 200 || response.statusCode > 399) return null;

    final document = html_parser.parse(response.body);

    final weekFromPath = _extractWeekId(path);
    if (weekFromPath != null) return weekFromPath;

    final weekLinks = <String>{};
    for (final a in document.querySelectorAll('a[href*="/week/"]')) {
      final week = _weekFromRef(a.attributes['href']);
      if (week != null) weekLinks.add(week);
    }
    if (weekLinks.isNotEmpty) {
      final sorted = weekLinks.toList()..sort();
      return sorted.first;
    }

    final nextWeek = document.querySelector('a.next')?.attributes['next_week_id'];
    if (nextWeek != null && _isIsoWeek(nextWeek)) {
      return _addDays(nextWeek, -7);
    }

    final prevWeek = document.querySelector('a.prev')?.attributes['prev_week_id'];
    if (prevWeek != null && _isIsoWeek(prevWeek)) {
      return _addDays(prevWeek, 7);
    }

    return null;
  }

  Future<_WeekPayload> _loadWeekPayload({
    required String pupilId,
    required String quarterId,
    required String weekId,
    required String activeBase,
  }) async {
    final response = await _client.get(
      Uri.parse('$activeBase/m/pupil/$pupilId/dnevnik/quarter/$quarterId/week/$weekId'),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Cookie': _cookieHeader(),
      },
    );
    _storeCookiesFromResponse(response);

    if (response.statusCode < 200 || response.statusCode > 399) {
      return _WeekPayload(ok: false, nextWeek: null, prevWeek: null, days: const []);
    }

    final document = html_parser.parse(response.body);

    final weekBlock = _pickWeekBlock(document: document, requestedWeekId: weekId);
    final blockRoot = weekBlock ?? document.querySelector('body');

    final nextWeek = _readWeekFromNode(blockRoot?.querySelector('a.next'));
    final prevWeek = _readWeekFromNode(blockRoot?.querySelector('a.prev'));

    final daysRoot = weekBlock?.querySelector('div.db_days') ?? document.querySelector('div.db_days');
    if (daysRoot == null) {
      return _WeekPayload(ok: false, nextWeek: nextWeek, prevWeek: prevWeek, days: const []);
    }

    final payloadDays = <_WeekDayPayload>[];
    for (final day in daysRoot.querySelectorAll('div.db_day')) {
      final table = day.querySelector('table.db_table');
      if (table == null) {
        payloadDays.add(const _WeekDayPayload(name: '?', lessons: []));
        continue;
      }

      final dayName = _normalizeSpaces(table.querySelector('th.lesson')?.text ?? '?');
      final lessons = <_WeekLessonPayload>[];

      for (final row in table.querySelectorAll('tbody tr')) {
        var subject = _normalizeSpaces(
          row.querySelector('td.lesson span')?.text ??
              row.querySelector('td.lesson a')?.text ??
              row.querySelector('td.lesson')?.text ??
              '',
        );
        subject = subject.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');

        final hw = _toNullable(_normalizeSpaces(
          row.querySelector('div.ht-text')?.text ?? row.querySelector('td.ht')?.text ?? '',
        ));

        final mark = _toNullable(_normalizeSpaces(
          row.querySelector('td.mark strong')?.text ?? row.querySelector('td.mark')?.text ?? '',
        ));

        final cabinet = _toNullable(_normalizeSpaces(row.querySelector('span.cabinet')?.text ?? ''));

        final attachments = <_AttachmentPayload>[];
        void pushAttachment({required String name, String? href, String? type}) {
          final normalizedHref = (href ?? '').trim();
          if (normalizedHref.isEmpty) return;
          attachments.add(
            _AttachmentPayload(
              name: _normalizeSpaces(name).isEmpty ? 'Файл' : _normalizeSpaces(name),
              url: normalizedHref,
              type: type,
            ),
          );
        }

        final toggle = row.querySelector('a.attachments_dropdown_toggle[href]');
        if (toggle != null) {
          pushAttachment(
            name: 'Файлы к уроку',
            href: toggle.attributes['href'],
            type: 'lesson_attribute',
          );
        }

        for (final link in row.querySelectorAll('.attachments_dropdown_menu a[href]')) {
          pushAttachment(
            name: link.text,
            href: link.attributes['href'],
            type: 'lesson_attachment',
          );
        }

        for (final link in row.querySelectorAll('div.ht-text a[href]')) {
          pushAttachment(
            name: link.text,
            href: link.attributes['href'],
            type: 'hw_link',
          );
        }

        final dedupAttachments = _dedupRawAttachments(attachments);

        if (subject.isEmpty && hw == null && mark == null && cabinet == null) {
          continue;
        }

        lessons.add(
          _WeekLessonPayload(
            subject: subject,
            mark: mark,
            hw: hw,
            cabinet: cabinet,
            attachments: dedupAttachments,
          ),
        );
      }

      payloadDays.add(_WeekDayPayload(name: dayName, lessons: lessons));
    }

    return _WeekPayload(ok: true, nextWeek: nextWeek, prevWeek: prevWeek, days: payloadDays);
  }

  Future<List<DayDto>> _resolveAttachmentLinks({
    required List<DayDto> days,
    required String activeBase,
  }) async {
    final resolved = <DayDto>[];

    for (final day in days) {
      final lessons = <LessonDto>[];
      for (final lesson in day.lessons) {
        final parsed = await _resolveAttachments(
          attachments: lesson.attachments,
          activeBase: activeBase,
        );

        lessons.add(
          LessonDto(
            subject: lesson.subject,
            mark: lesson.mark,
            hw: lesson.hw,
            cabinet: lesson.cabinet,
            attachments: parsed,
          ),
        );
      }

      resolved.add(DayDto(date: day.date, name: day.name, lessons: lessons));
    }

    return resolved;
  }

  Future<List<LessonAttachment>> _resolveAttachments({
    required List<LessonAttachment> attachments,
    required String activeBase,
  }) async {
    final resolved = <LessonAttachment>[];

    for (final attachment in attachments) {
      final rawUrl = attachment.url;
      final mustExpand = attachment.type == 'lesson_attribute' &&
          rawUrl != null &&
          rawUrl.contains('/attachments/LessonAttribute/') &&
          rawUrl.endsWith('/list');

      if (!mustExpand) {
        resolved.add(attachment);
        continue;
      }

      try {
        final direct = await _fetchDirectAttachments(url: rawUrl!, activeBase: activeBase);
        if (direct.isEmpty) {
          resolved.add(attachment);
        } else {
          resolved.addAll(direct);
        }
      } catch (_) {
        resolved.add(attachment);
      }
    }

    return _dedupAttachments(resolved);
  }

  Future<List<LessonAttachment>> _fetchDirectAttachments({
    required String url,
    required String activeBase,
  }) async {
    final absolute = _absoluteUrlString(url, activeBase);
    if (absolute == null) return const [];

    final response = await _client.get(
      Uri.parse(absolute),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Cookie': _cookieHeader(),
      },
    );
    _storeCookiesFromResponse(response);

    if (response.statusCode < 200 || response.statusCode > 399) {
      return const [];
    }

    final document = html_parser.parse(response.body);
    final links = document.querySelectorAll(
      '#saved_attachments_list a[href], .attachments_container a[href], a[href*="/attachment/"][href*="/download"]',
    );

    final result = <LessonAttachment>[];
    for (final link in links) {
      final href = link.attributes['href'];
      if (href == null || href.trim().isEmpty) continue;
      result.add(
        LessonAttachment(
          name: _normalizeSpaces(link.text).isEmpty ? 'Файл' : _normalizeSpaces(link.text),
          url: _absoluteUrlString(href, activeBase),
          type: 'lesson_attachment',
        ),
      );
    }

    return _dedupAttachments(result);
  }

  Future<String> _loadWithHostFallback({
    required String path,
    String? preferredBase,
  }) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final primary = preferredBase ?? _base;

    try {
      final response = await _client.get(
        Uri.parse('$primary$normalizedPath'),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Cookie': _cookieHeader(),
        },
      );
      _storeCookiesFromResponse(response);
      if (response.statusCode >= 200 && response.statusCode <= 399) {
        return primary;
      }
      if (primary == _fallbackBase) {
        throw SchoolsByError('Ошибка загрузки страницы (${response.statusCode}).');
      }
    } catch (_) {
      if (primary == _fallbackBase) rethrow;
    }

    final fallbackResponse = await _client.get(
      Uri.parse('$_fallbackBase$normalizedPath'),
      headers: {
        'User-Agent': 'Mozilla/5.0',
        'Cookie': _cookieHeader(),
      },
    );
    _storeCookiesFromResponse(fallbackResponse);

    if (fallbackResponse.statusCode >= 200 && fallbackResponse.statusCode <= 399) {
      return _fallbackBase;
    }

    throw SchoolsByError('Ошибка загрузки страницы (${fallbackResponse.statusCode}).');
  }

  void _storeCookiesFromResponse(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;

    final rawCookies = raw.split(RegExp(r',(?=\s*[^;=]+=[^;]+)'));
    for (final rawCookie in rawCookies) {
      final firstPart = rawCookie.split(';').first.trim();
      final eq = firstPart.indexOf('=');
      if (eq <= 0) continue;
      final name = firstPart.substring(0, eq).trim();
      final value = firstPart.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      _cookies[name] = value;
    }
  }

  String _cookieHeader({Map<String, String>? extra}) {
    final all = <String, String>{..._cookies, if (extra != null) ...extra};
    return all.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
  }

  String? _firstRegexCapture(String text, String pattern) {
    final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
    return match?.group(1);
  }

  String? _extractPupilId(String href) {
    final match = RegExp(r'/pupil/(\d+)').firstMatch(href);
    return match?.group(1);
  }

  (String, String?) _parseTitle(String fullTitle) {
    final trimmed = fullTitle.trim();
    final fullName = trimmed.split(',').first.trim().isEmpty ? trimmed : trimmed.split(',').first.trim();

    final classMatch = RegExp(r',\s*(.*?)\s*класс', caseSensitive: false).firstMatch(trimmed);
    final className = classMatch?.group(1)?.trim();
    return (fullName, className?.isEmpty == true ? null : className);
  }

  String? _absoluteUrlString(String? raw, String base) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }

    return Uri.parse(base).resolve(value).toString();
  }

  String _normalizeSpaces(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _toNullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isIsoWeek(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  }

  String? _extractWeekId(String path) {
    return RegExp(r'/week/(\d{4}-\d{2}-\d{2})', caseSensitive: false).firstMatch(path)?.group(1);
  }

  String? _weekFromRef(String? value) {
    if (value == null) return null;
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    if (_isIsoWeek(normalized)) return normalized;
    return RegExp(r'/week/(\d{4}-\d{2}-\d{2})').firstMatch(normalized)?.group(1);
  }

  String? _readWeekFromNode(dynamic node) {
    if (node == null) return null;
    final attrs = (node.attributes as Map<String, String>);

    for (final key in ['next_week_id', 'prev_week_id', 'send_to', 'href', 'data-week']) {
      final week = _weekFromRef(attrs[key]);
      if (week != null) return week;
    }
    return null;
  }

  dynamic _pickWeekBlock({required dynamic document, required String requestedWeekId}) {
    final blocks = document.querySelectorAll('[id^="db_week_"]');
    if (blocks.isEmpty) return null;

    for (final block in blocks) {
      final id = block.id?.toString() ?? '';
      if (id.endsWith('_$requestedWeekId')) return block;
    }

    for (final block in blocks) {
      final style = (block.attributes['style'] ?? '').toLowerCase();
      if (!style.contains('display: none')) return block;
    }

    return blocks.first;
  }

  List<_AttachmentPayload> _dedupRawAttachments(List<_AttachmentPayload> attachments) {
    final seen = <String>{};
    final result = <_AttachmentPayload>[];

    for (final item in attachments) {
      final key = '${item.url}|${item.name}|${item.type ?? ''}';
      if (!seen.add(key)) continue;
      result.add(item);
    }

    return result;
  }

  List<LessonAttachment> _dedupAttachments(List<LessonAttachment> attachments) {
    final seen = <String>{};
    final result = <LessonAttachment>[];

    for (final item in attachments) {
      final key = '${item.url ?? ''}|${item.name}|${item.type ?? ''}';
      if (!seen.add(key)) continue;
      result.add(item);
    }

    return result;
  }

  String _addDays(String isoDate, int days) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    final shifted = date.add(Duration(days: days));
    final y = shifted.year.toString().padLeft(4, '0');
    final m = shifted.month.toString().padLeft(2, '0');
    final d = shifted.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _ProfilePayload {
  const _ProfilePayload({
    required this.title,
    required this.avatarUrl,
    required this.classTeacher,
  });

  final String title;
  final String? avatarUrl;
  final String? classTeacher;
}

class _DiaryContext {
  const _DiaryContext({
    required this.base,
    required this.quarterId,
    required this.weekId,
  });

  final String base;
  final String? quarterId;
  final String? weekId;
}

class _WeekPayload {
  const _WeekPayload({
    required this.ok,
    required this.nextWeek,
    required this.prevWeek,
    required this.days,
  });

  final bool ok;
  final String? nextWeek;
  final String? prevWeek;
  final List<_WeekDayPayload> days;
}

class _WeekDayPayload {
  const _WeekDayPayload({required this.name, required this.lessons});

  final String name;
  final List<_WeekLessonPayload> lessons;
}

class _WeekLessonPayload {
  const _WeekLessonPayload({
    required this.subject,
    required this.mark,
    required this.hw,
    required this.cabinet,
    required this.attachments,
  });

  final String subject;
  final String? mark;
  final String? hw;
  final String? cabinet;
  final List<_AttachmentPayload> attachments;
}

class _AttachmentPayload {
  const _AttachmentPayload({
    required this.name,
    required this.url,
    required this.type,
  });

  final String name;
  final String? url;
  final String? type;
}

