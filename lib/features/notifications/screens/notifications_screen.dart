import '../../home/screens/follow_requests_screen.dart';

import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/notification_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../profile/screens/post_view_screen.dart';
import '../../profile/screens/user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final bool active;

  const NotificationsScreen({super.key, this.active = true});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();

  late final String _myUid;

  // Notifications that were unread when they arrived on this screen.
  // We keep them highlighted in the "New" section while marking them read.
  final Set<String> _newIds = {};

  @override
  void initState() {
    super.initState();
    _myUid = _authService.currentUser!.uid;
  }

  @override
  void didUpdateWidget(NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When you leave the tab, "New" items become "Earlier".
    if (oldWidget.active && !widget.active) _newIds.clear();
  }

  String _ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _row(NotificationModel n, bool isNew) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<UserModel?>(
      stream: _firestoreService.userStream(n.fromId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.name ?? 'Someone';
        final isFollow = n.type == 'follow';

        return ListTile(
          tileColor: isNew ? cs.primary.withValues(alpha: 0.08) : null,
          leading: UserAvatar(
            name: name,
            photoBase64: user?.photoBase64 ?? '',
            size: 46,
          ),
          title: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: isFollow
                      ? ' started following you.'
                      : (n.type == 'comment'
                            ? ' commented on your post.'
                            : ' liked your post.'),
                ),
                TextSpan(
                  text: '  ${_ago(n.createdAt)}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          trailing: isFollow
              ? _FollowBackButton(
                  myUid: _myUid,
                  otherUid: n.fromId,
                  service: _firestoreService,
                )
              : (n.postImageUrl.isEmpty
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          n.postImageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 48,
                            height: 48,
                            color: cs.surfaceContainerHighest,
                          ),
                        ),
                      )),
          onTap: () {
            if (isFollow || n.postId.isEmpty) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(uid: n.fromId),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PostViewScreen(postId: n.postId),
                ),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<List<String>>(
            stream: _firestoreService.requestsStream(_myUid),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return IconButton(
                tooltip: 'Follow requests',
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.person_add_alt_1_outlined),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FollowRequestsScreen(),
                  ),
                ),
              );
            },
          ),
        ],
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _firestoreService.notificationsStream(_myUid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load notifications.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;

          // Remember what is new, then mark everything as read.
          final unread = items.where((n) => !n.read).toList();
          if (unread.isNotEmpty) {
            _newIds.addAll(unread.map((n) => n.id));
            if (widget.active) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _firestoreService.markAllNotificationsRead(_myUid);
              });
            }
          }

          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 56,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'When someone follows you or likes your post, it shows up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            );
          }

          final fresh = items.where((n) => _newIds.contains(n.id)).toList();
          final earlier = items.where((n) => !_newIds.contains(n.id)).toList();

          return ListView(
            children: [
              if (fresh.isNotEmpty) ...[
                _header('New'),
                ...fresh.map((n) => _row(n, true)),
              ],
              if (earlier.isNotEmpty) ...[
                _header('Earlier'),
                ...earlier.map((n) => _row(n, false)),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

/// "Follow back" button (or "Following" once you do).
class _FollowBackButton extends StatefulWidget {
  final String myUid;
  final String otherUid;
  final FirestoreService service;

  const _FollowBackButton({
    required this.myUid,
    required this.otherUid,
    required this.service,
  });

  @override
  State<_FollowBackButton> createState() => _FollowBackButtonState();
}

class _FollowBackButtonState extends State<_FollowBackButton> {
  bool _busy = false;

  Future<void> _follow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.service.follow(widget.myUid, widget.otherUid);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: widget.service.followersStream(widget.otherUid),
      builder: (context, snapshot) {
        final following = snapshot.data?.contains(widget.myUid) ?? false;

        if (following) {
          return const Text(
            'Following',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w600,
            ),
          );
        }

        return ElevatedButton(
          onPressed: _busy ? null : _follow,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            minimumSize: const Size(0, 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Follow back'),
        );
      },
    );
  }
}
