import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'diary_screen.dart';
import 'profile_screen.dart';
import 'results_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.dashboard;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    Widget body;
    switch (_tab) {
      case AppTab.dashboard:
        body = DashboardScreen(
          weeks: c.weeks,
          onRefresh: c.reloadDiary,
          loading: c.diaryLoading,
          error: c.diaryError,
        );
      case AppTab.diary:
        body = DiaryScreen(weeks: c.weeks);
      case AppTab.analytics:
        body = AnalyticsScreen(weeks: c.weeks);
      case AppTab.results:
        body = ResultsScreen(weeks: c.weeks);
      case AppTab.profile:
        body = ProfileScreen(profile: c.profile, onLogout: c.logout);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(_tab)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.accent.withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Дневник'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Аналитика'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Итоги'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Профиль'),
        ],
        onDestinationSelected: (index) => setState(() => _tab = AppTab.values[index]),
      ),
    );
  }

  String _title(AppTab tab) {
    switch (tab) {
      case AppTab.dashboard:
        return 'Главная';
      case AppTab.diary:
        return 'Дневник';
      case AppTab.analytics:
        return 'Аналитика';
      case AppTab.results:
        return 'Итоги';
      case AppTab.profile:
        return 'Профиль';
    }
  }
}

