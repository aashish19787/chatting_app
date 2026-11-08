import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/post_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../screens/post_view_screen.dart';

class PostsGrid extends StatefulWidget {
  final String uid;

  const PostsGrid({super.key, required this.uid});

  @override
  State<PostsGrid> createState() => _PostsGridState();
}

class _PostsGridState extends State<PostsGrid> {
  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();
  final _storageService = StorageService();

  bool _uploading = false;

  bool get _isMe => _authService.currentUser?.uid == widget.uid;

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Color(0xFFEF4444)),
    );
  }

  Future<String?> _askCaption() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a caption'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Write a caption...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPost() async {
    final myUid = _authService.currentUser?.uid;
    if (myUid == null || _uploading) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1440,
        imageQuality: 80,
      );
      if (picked == null) return;

      final caption = await _askCaption();
      if (caption == null) return; // cancelled

      setState(() => _uploading = true);

      final url = await _storageService.uploadChatImage(picked);
      await _firestoreService.createPost(
        authorId: myUid,
        imageUrl: url,
        caption: caption,
      );
    } catch (e) {
      debugPrint('Post failed: $e');
      if (!mounted) return;
      _showError('Could not create the post. Please try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Posts',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_isMe)
              _uploading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: _addPost,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add post'),
                    ),
          ],
        ),
        const SizedBox(height: 6),
        StreamBuilder<List<PostModel>>(
          stream: _firestoreService.userPostsStream(widget.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('Could not load posts.')),
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final posts = snapshot.data!;
            if (posts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No posts yet',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
              ),
              itemBuilder: (context, index) {
                final post = posts[index];
                return GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PostViewScreen(postId: post.id),
                    ),
                  ),
                  child: Image.network(
                    post.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      );
                    },
                    errorBuilder: (_, _, _) => Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
