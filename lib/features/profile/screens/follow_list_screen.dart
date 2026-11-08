import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';
import 'user_profile_screen.dart';

class FollowListScreen extends StatelessWidget {
  final String title;
  final Stream<List<String>> stream;

  const FollowListScreen({
    super.key,
    required this.title,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<String>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load the list.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final uids = snapshot.data!;
          if (uids.isEmpty) {
            return const Center(
              child: Text(
                'No one here yet',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: uids.length,
            itemBuilder: (context, index) {
              final uid = uids[index];
              return StreamBuilder<UserModel?>(
                stream: firestoreService.userStream(uid),
                builder: (context, userSnapshot) {
                  final user = userSnapshot.data;
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
                    subtitle: Text(
                      (user?.bio.isNotEmpty ?? false)
                          ? user!.bio
                          : (user?.email ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(uid: uid),
                      ),
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
