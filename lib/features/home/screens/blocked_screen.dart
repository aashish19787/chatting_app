import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final myUid = FirebaseAuthService().currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Blocked people',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<String>>(
        stream: service.blockedStream(myUid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final uids = snapshot.data!;
          if (uids.isEmpty) {
            return const Center(
              child: Text(
                'You have not blocked anyone.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }

          return ListView.builder(
            itemCount: uids.length,
            itemBuilder: (context, index) {
              final uid = uids[index];
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
                    trailing: OutlinedButton(
                      onPressed: () => service.unblockUser(myUid, uid),
                      child: const Text('Unblock'),
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
