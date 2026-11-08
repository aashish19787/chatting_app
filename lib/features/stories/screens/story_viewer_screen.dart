import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/story_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';

/// Full-screen story viewer for ONE person. Tap right = next, left = back.
class StoryViewerScreen extends StatefulWidget {
  final List<StoryModel> stories; // oldest first
  final String myUid;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.myUid,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  final _service = FirestoreService();
  late final AnimationController _controller;
  late List<StoryModel> _stories;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _stories = List.of(widget.stories);
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) _go(_index + 1);
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (!mounted) return;
    if (i < 0) {
      _controller.forward(from: 0);
      return;
    }
    if (i >= _stories.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index = i);
    _controller.forward(from: 0);
  }

  String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }

  Future<void> _delete() async {
    _controller.stop();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete story?'),
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
    if (ok != true) {
      _controller.forward();
      return;
    }

    try {
      await _service.deleteStory(_stories[_index].id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete the story.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      _controller.forward();
      return;
    }
    if (!mounted) return;

    _stories.removeAt(_index);
    if (_stories.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      if (_index >= _stories.length) _index = _stories.length - 1;
    });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_index];
    final mine = story.authorId == widget.myUid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) {
                  final w = MediaQuery.of(context).size.width;
                  _go(d.localPosition.dx < w / 3 ? _index - 1 : _index + 1);
                },
                child: Center(
                  child: Image.network(
                    story.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const CircularProgressIndicator(
                        color: Colors.white,
                      );
                    },
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _stories.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (_, _) => LinearProgressIndicator(
                                value: i < _index
                                    ? 1
                                    : (i == _index ? _controller.value : 0),
                                minHeight: 3,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<UserModel?>(
                    stream: _service.userStream(story.authorId),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      final name = user?.name ?? '';
                      return Row(
                        children: [
                          UserAvatar(
                            name: name,
                            photoBase64: user?.photoBase64 ?? '',
                            size: 36,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _ago(story.createdAt),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const Spacer(),
                          if (mine)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                              onPressed: _delete,
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
