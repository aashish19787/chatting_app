import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common/widgets/group_avatar.dart';
import '../../../common/widgets/user_avatar.dart';
import '../../../models/chat_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../profile/screens/user_profile_screen.dart';
import 'add_members_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;

  const GroupInfoScreen({super.key, required this.chatId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  static const _primary = Color(0xFF0F8A5D);

  final _service = FirestoreService();
  final _auth = FirebaseAuthService();

  bool _busy = false;

  void _msg(String text, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Color(0xFFEF4444) : Color(0xFF22C55E),
      ),
    );
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              action,
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _rename(ChatModel chat) async {
    final controller = TextEditingController(text: chat.groupName);

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Group name'),
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

    if (name == null || name.isEmpty || name == chat.groupName) return;
    if (name.length < 2) {
      _msg('The name needs at least 2 characters.');
      return;
    }

    try {
      await _service.renameGroup(widget.chatId, name);
    } catch (_) {
      if (!mounted) return;
      _msg('Could not rename the group.');
    }
  }

  Future<void> _changePhoto() async {
    if (_busy) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 60,
      );
      if (picked == null) return;

      setState(() => _busy = true);
      final bytes = await picked.readAsBytes();
      await _service.setGroupPhoto(widget.chatId, base64Encode(bytes));
      if (!mounted) return;
      _msg('Group photo updated!', error: false);
    } catch (_) {
      if (!mounted) return;
      _msg('Could not update the group photo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String uid, String name) async {
    final ok = await _confirm(
      'Remove $name?',
      'They will no longer see this group or its messages.',
      'Remove',
    );
    if (!ok) return;

    try {
      await _service.removeGroupMember(widget.chatId, uid);
    } catch (_) {
      if (!mounted) return;
      _msg('Could not remove $name.');
    }
  }

  Future<void> _makeAdmin(String uid, String name) async {
    final ok = await _confirm(
      'Make $name admin?',
      'You will no longer be able to rename the group, change its photo or remove people.',
      'Make admin',
    );
    if (!ok) return;
    try {
      await _service.transferAdmin(widget.chatId, uid);
    } catch (_) {
      if (!mounted) return;
      _msg('Could not transfer admin.');
    }
  }

  Future<void> _leave(String myUid) async {
    final ok = await _confirm(
      'Leave group?',
      'You will no longer receive messages from this group.',
      'Leave',
    );
    if (!ok || !mounted) return;

    final navigator = Navigator.of(context);
    try {
      await _service.leaveGroup(widget.chatId, myUid);
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      _msg('Could not leave the group.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Group info',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<ChatModel?>(
        stream: _service.chatStream(widget.chatId),
        builder: (context, snapshot) {
          final chat = snapshot.data;
          if (chat == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final isAdmin = chat.createdBy == myUid;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: GestureDetector(
                  onTap: isAdmin ? _changePhoto : null,
                  child: Stack(
                    children: [
                      GroupAvatar(photoBase64: chat.groupPhoto, size: 96),
                      if (isAdmin)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      chat.groupName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Rename',
                      onPressed: () => _rename(chat),
                    ),
                ],
              ),
              Center(
                child: Text(
                  '${chat.participants.length} members',
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
              if (!isAdmin)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Center(
                    child: Text(
                      'Only the admin can rename the group, change its photo or remove people.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Members',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: _primary,
                  child: Icon(Icons.person_add_rounded, color: Colors.white),
                ),
                title: const Text('Add people'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddMembersScreen(
                      chatId: widget.chatId,
                      existing: chat.participants,
                    ),
                  ),
                ),
              ),
              ...chat.participants.map(
                (uid) => StreamBuilder<UserModel?>(
                  stream: _service.userStream(uid),
                  builder: (context, userSnapshot) {
                    final user = userSnapshot.data;
                    final name = user?.name ?? 'Loading...';
                    final isCreator = uid == chat.createdBy;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(
                        name: name,
                        photoBase64: user?.photoBase64 ?? '',
                        size: 44,
                      ),
                      title: Text(uid == myUid ? '$name (You)' : name),
                      subtitle: Text(user?.email ?? ''),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(uid: uid),
                        ),
                      ),
                      trailing: isCreator
                          ? const Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 12,
                                color: _primary,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : (isAdmin && uid != myUid
                                ? PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'admin') _makeAdmin(uid, name);
                                      if (v == 'remove') _remove(uid, name);
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'admin',
                                        child: Text('Make admin'),
                                      ),
                                      PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Remove from group'),
                                      ),
                                    ],
                                  )
                                : null),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _leave(myUid),
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('Leave group'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
