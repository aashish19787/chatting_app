import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../chats/screens/chat_screen.dart';
import '../../profile/screens/user_profile_screen.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final _searchController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();

  late final String _myUid;
  Timer? _debounce;
  List<UserModel> _results = [];
  bool _searching = false;
  bool _hasQuery = false;

  @override
  void initState() {
    super.initState();
    _myUid = _authService.currentUser!.uid;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _hasQuery = false;
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _hasQuery = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    setState(() => _searching = true);
    try {
      final users = await _firestoreService.searchUsers(value, _myUid);
      if (!mounted) return;
      setState(() => _results = users);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Widget _tile(UserModel user) {
    final active = user.isActive;

    return ListTile(
      leading: Stack(
        children: [
          UserAvatar(name: user.name, photoBase64: user.photoBase64, size: 50),
          if (active)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                height: 14,
                width: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        user.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: active
          ? const Text(
              'Active now',
              style: TextStyle(color: Color(0xFF22C55E), fontSize: 12),
            )
          : (user.bio.isNotEmpty
                ? Text(user.bio, maxLines: 1, overflow: TextOverflow.ellipsis)
                : null),
      trailing: IconButton(
        icon: const Icon(
          Icons.chat_bubble_outline_rounded,
          color: Color(0xFF0F8A5D),
        ),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => ChatScreen(otherUser: user))),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserProfileScreen(uid: user.uid)),
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) => _tile(_results[i]),
    );
  }

  Widget _buildFollowing() {
    return StreamBuilder<List<String>>(
      stream: _firestoreService.followingStream(_myUid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load people.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final uids = snapshot.data!;
        if (uids.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 56,
                    color: Color(0xFF6B7280),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No people yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Search above to find people, then follow them to see them here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: uids.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'Following',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              );
            }
            return StreamBuilder<UserModel?>(
              stream: _firestoreService.userStream(uids[index - 1]),
              builder: (context, userSnapshot) {
                final user = userSnapshot.data;
                if (user == null) return const SizedBox(height: 66);
                return _tile(user);
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'People',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search people',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _hasQuery ? _buildResults() : _buildFollowing()),
        ],
      ),
    );
  }
}
