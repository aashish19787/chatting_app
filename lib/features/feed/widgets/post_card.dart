import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';
import '../../profile/screens/comments_screen.dart';
import '../../profile/screens/user_profile_screen.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final String myUid;
  final FirestoreService service;

  const PostCard({
    super.key,
    required this.post,
    required this.myUid,
    required this.service,
  });

  void _openComments(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CommentsScreen(post: post)));
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(uid: post.authorId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liked = post.isLikedBy(myUid);

    return StreamBuilder<UserModel?>(
      stream: service.userStream(post.authorId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.name ?? 'Loading...';

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: UserAvatar(
                  name: name,
                  photoBase64: user?.photoBase64 ?? '',
                  size: 40,
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => _openProfile(context),
              ),
              GestureDetector(
                onDoubleTap: () {
                  if (!liked) service.setPostLike(post, myUid, true);
                },
                child: Image.network(
                  post.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 280,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 160,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => service.setPostLike(post, myUid, !liked),
                      icon: Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: liked ? Colors.redAccent : null,
                        size: 28,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openComments(context),
                      icon: const Icon(Icons.mode_comment_outlined, size: 26),
                    ),
                    const Spacer(),
                    Text(
                      post.likeCount == 1
                          ? '1 like'
                          : '${post.likeCount} likes',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$name  ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: post.caption),
                      ],
                    ),
                  ),
                ),
              StreamBuilder<int>(
                stream: service.commentCountStream(post.id),
                builder: (context, countSnap) {
                  final count = countSnap.data ?? 0;
                  return InkWell(
                    onTap: () => _openComments(context),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                      child: Text(
                        count == 0
                            ? 'Add a comment...'
                            : (count == 1
                                  ? 'View 1 comment'
                                  : 'View all $count comments'),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
