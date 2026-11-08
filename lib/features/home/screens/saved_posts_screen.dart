import 'package:flutter/material.dart';

import '../../../models/post_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../profile/screens/post_view_screen.dart';

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final myUid = FirebaseAuthService().currentUser?.uid ?? '';
    final empty = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Saved posts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<String>>(
        stream: service.savedIdsStream(myUid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load saved posts.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final ids = snapshot.data!;
          if (ids.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'Nothing saved yet.\nTap the bookmark on a post to save it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(3),
            itemCount: ids.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemBuilder: (context, i) {
              return StreamBuilder<PostModel?>(
                stream: service.postStream(ids[i]),
                builder: (context, postSnap) {
                  final post = postSnap.data;
                  // Post was deleted by its author.
                  if (post == null) return Container(color: empty);
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostViewScreen(postId: post.id),
                      ),
                    ),
                    child: Image.network(
                      post.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: empty),
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
