import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'services/schools_by_web_client.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';

class ChetverkaApp extends StatefulWidget {
  const ChetverkaApp({super.key});

  @override
  State<ChetverkaApp> createState() => _ChetverkaAppState();
}

class _ChetverkaAppState extends State<ChetverkaApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController(SchoolsByWebClient())..bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Chetverka',
          theme: buildAppTheme(),
          home: _controller.bootLoading
              ? const _BootScreen()
              : _controller.isAuthenticated
                  ? AppShell(controller: _controller)
                  : LoginScreen(controller: _controller),
        );
      },
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

