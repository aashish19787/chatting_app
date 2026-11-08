import 'dart:async';

import '../../share/share_sheet.dart';
import '../../../services/block_list.dart';
import '../widgets/posts_grid.dart';

import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../chats/screens/chat_screen.dart';
import 'follow_list_screen.dart';
import 'profile_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String uid;

  const UserProfileScreen({super.key, required this.uid});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const _primary = Color(0xFF0F8A5D);

  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();

  late final String _myUid;
  bool _busy = false;
  bool _requested = false;
  bool _hasRequestedMe = false;
  StreamSubscription<bool>? _incomingSub;
  StreamSubscription<bool>? _reqSub;

  bool get _isMe => widget.uid == _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = _authService.currentUser!.uid;
    if (widget.uid != _myUid) {
      _incomingSub = _firestoreService
          .requestedStream(widget.uid, _myUid)
          .listen((v) {
            if (mounted) setState(() => _hasRequestedMe = v);
          });
      _reqSub = _firestoreService.requestedStream(_myUid, widget.uid).listen((
        v,
      ) {
        if (mounted) setState(() => _requested = v);
      });
    }
  }

  @override
  void dispose() {
    _reqSub?.cancel();
    _incomingSub?.cancel();
    super.dispose();
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Color(0xFFEF4444)),
    );
  }

  Future<void> _answerRequest(bool accept) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (accept) {
        await _firestoreService.acceptRequest(_myUid, widget.uid);
      } else {
        await _firestoreService.declineRequest(_myUid, widget.uid);
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _requestBanner(String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${name.split(' ').first} requested to follow you',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: _busy ? null : () => _answerRequest(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 34),
            ),
            child: const Text('Confirm'),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: _busy ? null : () => _answerRequest(false),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 34)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFollow(bool isFollowing, UserModel user) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (isFollowing) {
        await _firestoreService.unfollow(_myUid, widget.uid);
      } else {
        if (_requested) {
          await _firestoreService.cancelRequest(_myUid, widget.uid);
        } else if (user.isPrivate) {
          await _firestoreService.requestFollow(_myUid, widget.uid);
        } else {
          await _firestoreService.follow(_myUid, widget.uid);
        }
      }
    } catch (_) {
      if (!mounted) return;
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editBio(UserModel user) async {
    final controller = TextEditingController(text: user.bio);

    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit bio'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 150,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Write something about yourself',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == null) return;
    try {
      await _firestoreService.updateBio(_myUid, saved);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not save your bio.');
    }
  }

  Future<void> _onMenu(String value) async {
    if (value == 'block') await _block();
    if (value == 'unblock') await _unblock();
    if (value == 'report') await _report();
  }

  Future<void> _block() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block this person?'),
        content: const Text(
          'They will not be able to message you, and you will stop following each other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Block',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _firestoreService.blockUser(_myUid, widget.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blocked.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Could not block this person.');
    }
  }

  Future<void> _unblock() async {
    try {
      await _firestoreService.unblockUser(_myUid, widget.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unblocked.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Could not unblock this person.');
    }
  }

  Future<void> _report() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Report this person'),
        children: [
          for (final r in ['Spam', 'Harassment', 'Fake account', 'Other'])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, r),
              child: Text(r),
            ),
        ],
      ),
    );
    if (reason == null) return;

    try {
      await _firestoreService.reportUser(_myUid, widget.uid, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks, your report was sent.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showError('Could not send the report.');
    }
  }

  String _short(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  Widget _stat(int count, String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _short(count),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  ButtonStyle get _outlinedStyle => OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isMe ? 'My profile' : 'Profile',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Share profile',
            onPressed: () => shareProfile(context, widget.uid),
          ),
          if (!_isMe)
            PopupMenuButton<String>(
              onSelected: _onMenu,
              itemBuilder: (_) {
                final blocked = BlockList.instance.ids.value.contains(
                  widget.uid,
                );
                return [
                  PopupMenuItem(
                    value: blocked ? 'unblock' : 'block',
                    child: Text(blocked ? 'Unblock' : 'Block'),
                  ),
                  const PopupMenuItem(value: 'report', child: Text('Report')),
                ];
              },
            ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: _firestoreService.userStream(widget.uid),
        builder: (context, userSnapshot) {
          final user = userSnapshot.data;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<List<String>>(
            stream: _firestoreService.followersStream(widget.uid),
            builder: (context, followersSnapshot) {
              final followers = followersSnapshot.data ?? const <String>[];
              final isFollowing = followers.contains(_myUid);

              return StreamBuilder<List<String>>(
                stream: _firestoreService.followingStream(widget.uid),
                builder: (context, followingSnapshot) {
                  final following = followingSnapshot.data ?? const <String>[];
                  final followsMe = following.contains(_myUid);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    children: [
                      Row(
                        children: [
                          UserAvatar(
                            name: user.name,
                            photoBase64: user.photoBase64,
                            size: 90,
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _stat(
                                  followers.length,
                                  'Followers',
                                  () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FollowListScreen(
                                        title: 'Followers',
                                        stream: _firestoreService
                                            .followersStream(widget.uid),
                                      ),
                                    ),
                                  ),
                                ),
                                _stat(
                                  following.length,
                                  'Following',
                                  () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FollowListScreen(
                                        title: 'Following',
                                        stream: _firestoreService
                                            .followingStream(widget.uid),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_isMe)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            user.email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      if (user.bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(user.bio),
                        ),
                      const SizedBox(height: 16),
                      if (!_isMe && _hasRequestedMe) _requestBanner(user.name),
                      if (_isMe)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: _outlinedStyle,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ProfileScreen(),
                                  ),
                                ),
                                child: const Text('Edit profile'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                style: _outlinedStyle,
                                onPressed: () => _editBio(user),
                                child: Text(
                                  user.bio.isEmpty ? 'Add bio' : 'Edit bio',
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: isFollowing
                                  ? OutlinedButton(
                                      style: _outlinedStyle,
                                      onPressed: _busy
                                          ? null
                                          : () => _toggleFollow(true, user),
                                      child: const Text('Following'),
                                    )
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      onPressed: _busy
                                          ? null
                                          : () => _toggleFollow(false, user),
                                      child: Text(
                                        _requested
                                            ? 'Requested'
                                            : (followsMe
                                                  ? 'Follow back'
                                                  : 'Follow'),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                style: _outlinedStyle,
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(otherUser: user),
                                  ),
                                ),
                                child: const Text('Message'),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      (!user.isPrivate || _isMe || isFollowing)
                          ? PostsGrid(uid: widget.uid)
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Icon(Icons.lock_outline_rounded, size: 48),
                                  SizedBox(height: 12),
                                  Text(
                                    'This account is private',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Follow this account to see their posts.',
                                    style: TextStyle(color: Color(0xFF6B7280)),
                                  ),
                                ],
                              ),
                            ),
                    ],
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
