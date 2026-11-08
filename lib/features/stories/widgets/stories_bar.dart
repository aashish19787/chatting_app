import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/story_model.dart';
import '../../../models/user_model.dart';
import '../../../services/block_list.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../screens/story_viewer_screen.dart';

/// Row of stories: "Your story" first, then people you follow.
class StoriesBar extends StatefulWidget {
  const StoriesBar({super.key});

  @override
  State<StoriesBar> createState() => _StoriesBarState();
}

class _StoriesBarState extends State<StoriesBar> {
  static const _primary = Color(0xFF6366F1);

  final _service = FirestoreService();
  final _auth = FirebaseAuthService();
  final _storage = StorageService();

  late final String _myUid;
  StreamSubscription<List<String>>? _followSub;
  Stream<List<StoryModel>>? _stream;
  String _key = '';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser!.uid;
    _setAuthors([_myUid]);
    _followSub = _service.followingStream(_myUid).listen((uids) {
      _setAuthors([_myUid, ...uids]);
    });
    BlockList.instance.ids.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _setAuthors(List<String> authors) {
    final key = (authors.take(30).toList()..sort()).join(',');
    if (key == _key) return;
    _key = key;
    final stream = _service.storiesStream(authors);
    if (mounted) {
      setState(() => _stream = stream);
    } else {
      _stream = stream;
    }
  }

  @override
  void dispose() {
    BlockList.instance.ids.removeListener(_refresh);
    _followSub?.cancel();
    super.dispose();
  }

  Future<void> _addStory() async {
    if (_uploading) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _uploading = true);
      final url = await _storage.uploadChatImage(picked);
      await _service.createStory(_myUid, url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add your story.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _open(List<StoryModel> stories) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(stories: stories, myUid: _myUid),
      ),
    );
  }

  Widget _ring({required Widget child, required bool active}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active
            ? const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFDB2777), _primary],
              )
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: child,
      ),
    );
  }

  Widget _myItem(List<StoryModel> mine) {
    return StreamBuilder<UserModel?>(
      stream: _service.userStream(_myUid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final hasStory = mine.isNotEmpty;

        return SizedBox(
          width: 78,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => hasStory ? _open(mine) : _addStory(),
                child: Stack(
                  children: [
                    _ring(
                      active: hasStory,
                      child: UserAvatar(
                        name: user?.name ?? '',
                        photoBase64: user?.photoBase64 ?? '',
                        size: 54,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _addStory,
                        child: Container(
                          height: 22,
                          width: 22,
                          decoration: BoxDecoration(
                            color: _primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: _uploading
                              ? const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your story',
                maxLines: 1,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _otherItem(String uid, List<StoryModel> stories) {
    return StreamBuilder<UserModel?>(
      stream: _service.userStream(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.name ?? '';

        return GestureDetector(
          onTap: () => _open(stories),
          child: SizedBox(
            width: 78,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ring(
                  active: true,
                  child: UserAvatar(
                    name: name,
                    photoBase64: user?.photoBase64 ?? '',
                    size: 54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StoryModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        debugPrint(
          'STORIES authors=$_key error=${snapshot.error} '
          'count=${snapshot.data?.length}',
        );
        final blocked = BlockList.instance.ids.value;
        debugPrint(
          'STORY AUTHORS: ${(snapshot.data ?? []).map((s) => s.authorId).toList()}'
          ' blocked=$blocked me=$_myUid',
        );
        final all = (snapshot.data ?? const <StoryModel>[])
            .where((s) => !blocked.contains(s.authorId))
            .toList();

        final byAuthor = <String, List<StoryModel>>{};
        for (final s in all) {
          byAuthor.putIfAbsent(s.authorId, () => []).add(s);
        }
        final mine = byAuthor.remove(_myUid) ?? <StoryModel>[];
        final others = byAuthor.entries.toList()
          ..sort(
            (a, b) => b.value.last.createdAt.compareTo(a.value.last.createdAt),
          );

        return SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              _myItem(mine),
              for (final e in others) _otherItem(e.key, e.value),
            ],
          ),
        );
      },
    );
  }
}
