import 'package:flutter/material.dart';

import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../screens/follow_requests_screen.dart';

/// "Private account" switch and "Follow requests" row for the Menu.
class PrivacyTiles extends StatelessWidget {
  const PrivacyTiles({super.key});

  Widget _icon(IconData icon) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFF6366F1), size: 22),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final myUid = FirebaseAuthService().currentUser?.uid ?? '';

    return Column(
      children: [
        StreamBuilder<UserModel?>(
          stream: service.userStream(myUid),
          builder: (context, snapshot) {
            final isPrivate = snapshot.data?.isPrivate ?? false;
            return SwitchListTile(
              secondary: _icon(Icons.lock_outline_rounded),
              title: const Text(
                'Private account',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Only approved people can follow you'),
              value: isPrivate,
              onChanged: (v) async {
                try {
                  await service.setPrivate(myUid, v);
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not change this setting.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
            );
          },
        ),
        StreamBuilder<List<String>>(
          stream: service.requestsStream(myUid),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return ListTile(
              leading: _icon(Icons.person_add_alt_1_outlined),
              title: const Text(
                'Follow requests',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: count > 0
                  ? Badge(label: Text('$count'))
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FollowRequestsScreen()),
              ),
            );
          },
        ),
      ],
    );
  }
}
