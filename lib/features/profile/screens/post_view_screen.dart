import '../widgets/save_button.dart';
import '../../share/share_sheet.dart';
import 'comments_screen.dart';

import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import 'user_profile_screen.dart';

class PostViewScreen extends StatelessWidget {
  final String postId;

  PostViewScreen({super.key, required this.postId});

  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _firestoreService.deletePost(postId);
      navigator.pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not delete the post.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _authService.currentUser?.uid ?? '';

    return StreamBuilder<PostModel?>(
      stream: _firestoreService.postStream(postId),
      builder: (context, snapshot) {
        final post = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Post',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              if (post != null) SaveButton(postId: post.id),
              if (post != null && post.authorId == myUid)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _delete(context),
                ),
            ],
          ),
          body: post == null
              ? Center(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const CircularProgressIndicator()
                      : const Text('This post is no longer available.'),
                )
              : _buildBody(context, post, myUid),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, PostModel post, String myUid) {
    final liked = post.isLikedBy(myUid);

    return ListView(
      children: [
        StreamBuilder<UserModel?>(
          stream: _firestoreService.userStream(post.authorId),
          builder: (context, userSnapshot) {
            final user = userSnapshot.data;
            final name = user?.name ?? 'Loading...';
            return ListTile(
              leading: UserAvatar(
                name: name,
                photoBase64: user?.photoBase64 ?? '',
                size: 40,
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(uid: post.authorId),
                ),
              ),
            );
          },
        ),
        GestureDetector(
          onDoubleTap: () {
            if (!liked) _firestoreService.setPostLike(post, myUid, true);
          },
          child: Image.network(
            post.imageUrl,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (_, _, _) => const SizedBox(
              height: 200,
              child: Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () =>
                    _firestoreService.setPostLike(post, myUid, !liked),
                icon: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: liked ? Colors.redAccent : null,
                  size: 28,
                ),
              ),
              Text(
                post.likeCount == 1 ? '1 like' : '${post.likeCount} likes',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.ios_share_rounded),
          title: const Text('Share'),
          onTap: () => sharePost(context, post),
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.mode_comment_outlined),
          title: const Text('View comments'),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => CommentsScreen(post: post))),
        ),
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(post.caption),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Text(
            '${post.createdAt.day}/${post.createdAt.month}/${post.createdAt.year}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }
}
