import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';
import '../screens/chat_screen.dart';

/// Row of "Your note" + people who are online or have a note.
class ActiveNowStrip extends StatefulWidget {
  final String myUid;

  /// People you already chat with (1-to-1 chats).
  final List<String> partnerUids;

  const ActiveNowStrip({
    super.key,
    required this.myUid,
    required this.partnerUids,
  });

  @override
  State<ActiveNowStrip> createState() => _ActiveNowStripState();
}

class _ActiveNowStripState extends State<ActiveNowStrip> {
  static const _maxPeople = 40;
  static const _primary = Color(0xFF6366F1);

  final _service = FirestoreService();

  final Map<String, StreamSubscription<UserModel?>> _subs = {};
  final Map<String, UserModel> _users = {};
  UserModel? _me;
  StreamSubscription<UserModel?>? _meSub;
  Set<String> _following = {};
  StreamSubscription<List<String>>? _followSub;
  Timer? _tick;

  @override
  void initState() {
    super.initState();

    _meSub = _service.userStream(widget.myUid).listen((user) {
      if (mounted) setState(() => _me = user);
    });

    _followSub = _service.followingStream(widget.myUid).listen((uids) {
      _following = uids.toSet();
      _sync();
    });

    // Re-check every 30 seconds so people drop off when they go quiet.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });

    _sync();
  }

  @override
  void didUpdateWidget(ActiveNowStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _meSub?.cancel();
    _followSub?.cancel();
    for (final sub in _subs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _sync() {
    final wanted = <String>{
      ...widget.partnerUids,
      ..._following,
    }.where((u) => u.isNotEmpty && u != widget.myUid).take(_maxPeople).toSet();

    for (final uid in _subs.keys.toList()) {
      if (!wanted.contains(uid)) {
        _subs.remove(uid)?.cancel();
        _users.remove(uid);
      }
    }

    for (final uid in wanted) {
      if (_subs.containsKey(uid)) continue;
      _subs[uid] = _service.userStream(uid).listen((user) {
        if (!mounted) return;
        setState(() {
          if (user == null) {
            _users.remove(uid);
          } else {
            _users[uid] = user;
          }
        });
      });
    }

    if (mounted) setState(() {});
  }

  /// A posted note can't be edited for 24 hours. It can only be deleted.
  Future<void> _showLockedNote() async {
    final me = _me!;
    String remaining = '';
    if (me.noteAt != null) {
      final left =
          const Duration(hours: 24) - DateTime.now().difference(me.noteAt!);
      final hours = left.inHours;
      final minutes = left.inMinutes % 60;
      remaining = hours > 0 ? 'in ${hours}h ${minutes}m' : 'in ${minutes}m';
    }

    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(me.note, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text(
              remaining.isEmpty
                  ? 'Notes can\'t be edited. You can delete it.'
                  : 'Notes can\'t be edited. It disappears $remaining, or you can delete it now.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Close'),
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

    if (delete != true) return;
    try {
      await _service.deleteNote(widget.myUid);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete your note.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _editMyNote() async {
    if (_me?.hasNote ?? false) {
      await _showLockedNote();
      return;
    }
    final controller = TextEditingController(
      text: (_me?.hasNote ?? false) ? _me!.note : '',
    );
    final hasNote = _me?.hasNote ?? false;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Share a thought...',
            helperText: 'Visible to people for 24 hours',
          ),
        ),
        actions: [
          if (hasNote)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, '\u0000delete'),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Share'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      if (result == '\u0000delete') {
        await _service.deleteNote(widget.myUid);
      } else {
        await _service.setNote(widget.myUid, result);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update your note.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// The speech-bubble above a photo. Same height whether or not it has text,
  /// so all photos line up.
  Widget _bubble(String? text, {bool placeholder = false}) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: text == null
            ? const SizedBox.shrink()
            : Container(
                constraints: const BoxConstraints(maxWidth: 74),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    color: placeholder ? const Color(0xFF94A3B8) : null,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _myItem() {
    final me = _me;
    final hasNote = me?.hasNote ?? false;
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _editMyNote,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _bubble(hasNote ? me!.note : 'Add note', placeholder: !hasNote),
            Stack(
              children: [
                UserAvatar(
                  name: me?.name ?? '',
                  photoBase64: me?.photoBase64 ?? '',
                  size: 56,
                ),
                if (!hasNote)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 20,
                      width: 20,
                      decoration: BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Your note',
              maxLines: 1,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _personItem(UserModel user) {
    final cs = Theme.of(context).colorScheme;
    final firstName = user.name.split(' ').first;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ChatScreen(otherUser: user))),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _bubble(user.hasNote ? user.note : null),
            Stack(
              children: [
                UserAvatar(
                  name: user.name,
                  photoBase64: user.photoBase64,
                  size: 56,
                ),
                if (user.isActive)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      height: 15,
                      width: 15,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final people = _users.values.where((u) => u.isActive || u.hasNote).toList()
      ..sort((a, b) {
        // People with a note first, then by name.
        if (a.hasNote != b.hasNote) return a.hasNote ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return SizedBox(
      height: 122,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: people.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _myItem();
          return _personItem(people[index - 1]);
        },
      ),
    );
  }
}
