import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  static const _primary = Color(0xFF0F8A5D);

  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();

  Timer? _debounce;
  List<UserModel> _results = [];
  final Map<String, UserModel> _selected = {};
  bool _isSearching = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSearching = true);
    try {
      final users = await _firestoreService.searchUsers(value, uid);
      if (!mounted) return;
      setState(() => _results = users);
    } catch (_) {
      // ignore search errors here
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _toggle(UserModel user) {
    setState(() {
      if (_selected.containsKey(user.uid)) {
        _selected.remove(user.uid);
      } else {
        _selected[user.uid] = user;
      }
    });
  }

  void _showError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Color(0xFFEF4444)),
    );
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    final myUid = _authService.currentUser?.uid;
    if (myUid == null || _isCreating) return;

    if (name.length < 2) {
      _showError('Please enter a group name.');
      return;
    }
    // Creator + at least 2 others = 3 people (matches the security rules).
    if (_selected.length < 2) {
      _showError('Pick at least 2 people.');
      return;
    }
    if (_selected.length > 49) {
      _showError('A group can have at most 50 people.');
      return;
    }

    setState(() => _isCreating = true);
    try {
      await _firestoreService.createGroup(
        creatorId: myUid,
        name: name,
        memberIds: _selected.keys.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group created! It will appear in your chat list.'),
          backgroundColor: Color(0xFF22C55E),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _showError('Could not create the group. Please try again.');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'New Group',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: InputDecoration(
                hintText: 'Group name',
                prefixIcon: const Icon(Icons.groups_rounded),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Selected members as chips
          if (_selected.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _selected.values
                    .map(
                      (u) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text(u.name),
                          onDeleted: () => _toggle(u),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search people to add',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: _primary),
                  )
                : _results.isEmpty
                ? const Center(
                    child: Text(
                      'Search for people by name',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final user = _results[index];
                      final picked = _selected.containsKey(user.uid);
                      return ListTile(
                        leading: UserAvatar(
                          name: user.name,
                          photoBase64: user.photoBase64,
                          size: 44,
                        ),
                        title: Text(user.name),
                        subtitle: Text(user.email),
                        trailing: Icon(
                          picked
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: picked ? _primary : null,
                        ),
                        onTap: () => _toggle(user),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text('Create group (${_selected.length} selected)'),
            ),
          ),
        ),
      ),
    );
  }
}
