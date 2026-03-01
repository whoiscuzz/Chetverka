import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.profile,
    required this.onLogout,
  });

  final Profile? profile;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.deepBlue,
                  foregroundImage:
                      (profile?.avatarUrl ?? '').trim().isEmpty ? null : NetworkImage(profile!.avatarUrl!),
                  child: (profile?.avatarUrl ?? '').trim().isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 32)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.fullName ?? 'Пользователь', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(profile?.className ?? 'Класс не указан'),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Классный руководитель', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(profile?.classTeacher ?? 'Не указан'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.deepBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Выйти'),
        )
      ],
    );
  }
}

