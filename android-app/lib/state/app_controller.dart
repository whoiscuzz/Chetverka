import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diary_models.dart';
import '../models/profile.dart';
import '../services/schools_by_web_client.dart';

enum AppTab { dashboard, diary, analytics, results, profile }

class AppController extends ChangeNotifier {
  AppController(this._api);

  final SchoolsByWebClient _api;

  bool bootLoading = true;
  bool authLoading = false;
  bool isAuthenticated = false;
  bool diaryLoading = false;

  String? authError;
  String? diaryError;

  String? _sessionId;
  String? _pupilId;

  Profile? profile;
  List<WeekDto> weeks = const [];

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString('sessionid');
    _pupilId = prefs.getString('pupilid');

    final profileRaw = prefs.getString('profile');
    if (profileRaw != null && profileRaw.isNotEmpty) {
      profile = Profile.fromJson(jsonDecode(profileRaw) as Map<String, dynamic>);
    }

    if (_sessionId != null && _pupilId != null) {
      isAuthenticated = true;
      await reloadDiary();
    }

    bootLoading = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      authError = 'Заполни логин и пароль.';
      notifyListeners();
      return;
    }

    authLoading = true;
    authError = null;
    notifyListeners();

    try {
      final data = await _api.login(
        username: username.trim(),
        password: password,
      );

      _sessionId = data.sessionId;
      _pupilId = data.pupilId;
      profile = data.profile;
      isAuthenticated = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sessionid', data.sessionId);
      await prefs.setString('pupilid', data.pupilId);
      await prefs.setString('profile', jsonEncode(data.profile.toJson()));

      await reloadDiary();
    } catch (error) {
      authError = error.toString().replaceFirst('Exception: ', '');
      isAuthenticated = false;
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadDiary() async {
    if (_sessionId == null || _pupilId == null) return;

    diaryLoading = true;
    diaryError = null;
    notifyListeners();

    try {
      final response = await _api.fetchDiary(
        sessionId: _sessionId!,
        pupilId: _pupilId!,
      );
      weeks = response.weeks;
      if (weeks.isEmpty) {
        diaryError = 'Дневник пустой или не распарсился.';
      }
    } catch (error) {
      diaryError = error.toString().replaceFirst('Exception: ', '');
    } finally {
      diaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sessionid');
    await prefs.remove('pupilid');
    await prefs.remove('profile');

    await _api.clearSession();

    _sessionId = null;
    _pupilId = null;
    profile = null;
    weeks = const [];
    isAuthenticated = false;
    authError = null;
    diaryError = null;
    notifyListeners();
  }
}

