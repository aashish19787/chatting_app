import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';

class AddMembersScreen extends StatefulWidget {
  final String chatId;
  final List<String> existing;

  const AddMembersScreen({
    super.key,
    required this.chatId,
    required this.existing,
  });

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  static const _primary = Color(0xFF6366F1);

  final _searchController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _authService = FirebaseAuthService();

  Timer? _debounce;
  List<UserModel> _results = [];
  final Map<String, UserModel> _selected = {};
  bool _isSearching = false;
  bool _isAdding = false;

  @override
  void dispose() {
    _debounce?.cancel();
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
      setState(() {
        // Hide people who are already in the group.
        _results = users
            .where((u) => !widget.existing.contains(u.uid))
            .toList();
      });
    } catch (_) {
      // ignore
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
      SnackBar(content: Text(text), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _add() async {
    if (_selected.isEmpty || _isAdding) return;
    if (widget.existing.length + _selected.length > 50) {
      _showError('A group can have at most 50 people.');
      return;
    }

    setState(() => _isAdding = true);
    try {
      await _firestoreService.addGroupMembers(
        widget.chatId,
        _selected.keys.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _showError('Could not add people. Please try again.');
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Add people',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
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
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search people to add',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
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
                      style: TextStyle(color: Color(0xFF94A3B8)),
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
              onPressed: (_selected.isEmpty || _isAdding) ? null : _add,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isAdding
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text('Add ${_selected.length} people'),
            ),
          ),
        ),
      ),
    );
  }
}
