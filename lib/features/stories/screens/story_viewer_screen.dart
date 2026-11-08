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
  final _replyController = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _controller;
  late List<StoryModel> _stories;
  final Set<String> _marked = {};
  int _index = 0;
  bool _sending = false;

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

    _focus.addListener(() {
      if (_focus.hasFocus) {
        _controller.stop();
      } else if (!_sending) {
        _controller.forward();
      }
    });

    _markViewed();
  }

  @override
  void dispose() {
    _controller.dispose();
    _replyController.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Record that I saw this story (once per story, never for my own).
  void _markViewed() {
    if (_stories.isEmpty) return;
    final story = _stories[_index];
    if (story.authorId == widget.myUid) return;
    if (!_marked.add(story.id)) return;
    _service.markStoryViewed(story.id, widget.myUid);
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
    _markViewed();
  }

  String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }

  void _msg(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendToAuthor(String text) async {
    final story = _stories[_index];
    if (text.trim().isEmpty || _sending) return;

    setState(() => _sending = true);
    _controller.stop();
    try {
      await _service.sendMessage(
        senderId: widget.myUid,
        receiverId: story.authorId,
        text: text.trim(),
        replyToId: 'story_${story.id}',
        replyToText: '📸 Story',
        replyToSenderId: story.authorId,
      );
      _replyController.clear();
      _focus.unfocus();
      if (!mounted) return;
      _msg('Sent');
    } catch (e) {
      if (!mounted) return;
      _msg(
        e is BlockedException
            ? "You can't message this person."
            : 'Could not send. Please try again.',
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (!_focus.hasFocus) _controller.forward();
      }
    }
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
      _msg('Could not delete the story.', error: true);
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

  /// Bottom sheet with everyone who saw this story.
  Future<void> _showViewers(StoryModel story) async {
    _controller.stop();

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.55,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.storyViewsStream(story.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load viewers.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final views = snapshot.data!;

                return Column(
                  children: [
                    Text(
                      views.length == 1
                          ? '1 viewer'
                          : '${views.length} viewers',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: views.isEmpty
                          ? const Center(
                              child: Text(
                                'No one has seen this yet',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            )
                          : ListView.builder(
                              itemCount: views.length,
                              itemBuilder: (context, i) {
                                final uid = views[i]['uid'] as String;
                                final at = views[i]['viewedAt'] as DateTime?;
                                return StreamBuilder<UserModel?>(
                                  stream: _service.userStream(uid),
                                  builder: (context, userSnap) {
                                    final user = userSnap.data;
                                    final name = user?.name ?? 'Loading...';
                                    return ListTile(
                                      leading: UserAvatar(
                                        name: name,
                                        photoBase64: user?.photoBase64 ?? '',
                                        size: 44,
                                      ),
                                      title: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      trailing: Text(
                                        at == null ? '' : _ago(at),
                                        style: const TextStyle(
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (mounted) _controller.forward();
  }

  /// Shown on MY stories instead of the reply bar.
  Widget _seenBar(StoryModel story) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _service.storyViewsStream(story.id),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return InkWell(
          onTap: () => _showViewers(story),
          child: Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.remove_red_eye_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Seen by $count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _replyBar() {
    const emojis = ['❤️', '😂', '😮', '😢', '👍'];

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in emojis)
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _sending ? null : () => _sendToAuthor(e),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                ),
            ],
          ),
          TextField(
            controller: _replyController,
            focusNode: _focus,
            maxLength: 300,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: _sendToAuthor,
            decoration: InputDecoration(
              hintText: 'Reply to story...',
              hintStyle: const TextStyle(color: Colors.white54),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Colors.white54),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: Colors.white),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _sending
                    ? null
                    : () => _sendToAuthor(_replyController.text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = _stories[_index];
    final mine = story.authorId == widget.myUid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) {
                        if (_focus.hasFocus) {
                          _focus.unfocus();
                          return;
                        }
                        final w = MediaQuery.of(context).size.width;
                        _go(
                          d.localPosition.dx < w / 3 ? _index - 1 : _index + 1,
                        );
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _controller,
                                    builder: (_, _) => LinearProgressIndicator(
                                      value: i < _index
                                          ? 1
                                          : (i == _index
                                                ? _controller.value
                                                : 0),
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
            mine ? _seenBar(story) : _replyBar(),
          ],
        ),
      ),
    );
  }
}
