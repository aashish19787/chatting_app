import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../profile/screens/user_profile_screen.dart';

class FollowRequestsScreen extends StatelessWidget {
  const FollowRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final myUid = FirebaseAuthService().currentUser?.uid ?? '';

    Future<void> run(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Follow requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<String>>(
        stream: service.requestsStream(myUid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final uids = snapshot.data!;
          if (uids.isEmpty) {
            return const Center(
              child: Text(
                'No follow requests',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }

          return ListView.builder(
            itemCount: uids.length,
            itemBuilder: (context, i) {
              final uid = uids[i];
              return StreamBuilder<UserModel?>(
                stream: service.userStream(uid),
                builder: (context, userSnap) {
                  final user = userSnap.data;
                  final name = user?.name ?? 'Loading...';
                  return ListTile(
                    leading: UserAvatar(
                      name: name,
                      photoBase64: user?.photoBase64 ?? '',
                      size: 46,
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(uid: uid),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () =>
                              run(() => service.acceptRequest(myUid, uid)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F8A5D),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 34),
                          ),
                          child: const Text('Confirm'),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () =>
                              run(() => service.declineRequest(myUid, uid)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 34),
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
