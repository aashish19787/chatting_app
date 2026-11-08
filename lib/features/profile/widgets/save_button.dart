import 'package:flutter/material.dart';

import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';

/// Bookmark icon: tap to save or unsave a post.
class SaveButton extends StatelessWidget {
  final String postId;

  const SaveButton({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final myUid = FirebaseAuthService().currentUser?.uid ?? '';

    return StreamBuilder<bool>(
      stream: service.isSavedStream(myUid, postId),
      builder: (context, snapshot) {
        final saved = snapshot.data ?? false;
        return IconButton(
          tooltip: saved ? 'Unsave' : 'Save',
          icon: Icon(
            saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            size: 27,
          ),
          onPressed: () async {
            try {
              await service.setSaved(myUid, postId, !saved);
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not update saved posts.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
        );
      },
    );
  }
}
