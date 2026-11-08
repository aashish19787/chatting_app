import 'package:flutter/material.dart';

import '../../../models/message_model.dart';
import '../../../services/firestore_service.dart';

class MessageSearchScreen extends StatefulWidget {
  final String chatId;

  /// uid -> display name (use "You" for yourself)
  final Map<String, String> names;

  const MessageSearchScreen({
    super.key,
    required this.chatId,
    required this.names,
  });

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  final _controller = TextEditingController();
  final _service = FirestoreService();

  List<MessageModel> _all = [];
  bool _loading = true;
  bool _failed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _service.fetchRecentMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _all = list.where((m) => !m.deleted && m.text.isNotEmpty).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  String _date(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $h:$m';
  }

  /// Bold the part of the text that matches.
  Widget _highlight(String text, String q) {
    final i = text.toLowerCase().indexOf(q.toLowerCase());
    if (i == -1) {
      return Text(text, maxLines: 3, overflow: TextOverflow.ellipsis);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, i)),
          TextSpan(
            text: text.substring(i, i + q.length),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F8A5D),
            ),
          ),
          TextSpan(text: text.substring(i + q.length)),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final results = q.isEmpty
        ? <MessageModel>[]
        : _all
              .where((m) => m.text.toLowerCase().contains(q.toLowerCase()))
              .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search in conversation',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? const Center(child: Text('Could not load messages.'))
          : q.isEmpty
          ? const Center(
              child: Text(
                'Type a word to search',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          : results.isEmpty
          ? const Center(
              child: Text(
                'No messages found',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          : ListView.separated(
              itemCount: results.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = results[i];
                return ListTile(
                  title: Text(
                    widget.names[m.senderId] ?? 'Someone',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: _highlight(m.text, q),
                  trailing: Text(
                    _date(m.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
