import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/post_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../stories/widgets/stories_bar.dart';
import '../widgets/post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _service = FirestoreService();
  final _auth = FirebaseAuthService();

  late final String _myUid;
  StreamSubscription<List<String>>? _followSub;
  Stream<List<PostModel>>? _feed;
  String _authorKey = '';

  @override
  void initState() {
    super.initState();
    _myUid = _auth.currentUser!.uid;
    _setAuthors([_myUid]);

    _followSub = _service.followingStream(_myUid).listen((uids) {
      _setAuthors([_myUid, ...uids]);
    });
  }

  void _setAuthors(List<String> authors) {
    final key = (authors.take(30).toList()..sort()).join(',');
    if (key == _authorKey) return;
    _authorKey = key;
    final stream = _service.feedStream(authors);
    if (mounted) {
      setState(() => _feed = stream);
    } else {
      _feed = stream;
    }
  }

  @override
  void dispose() {
    _followSub?.cancel();
    super.dispose();
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 56,
              color: Color(0xFF6B7280),
            ),
            SizedBox(height: 16),
            Text(
              'Nothing to see yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Follow people from the People tab, or add your own post from your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Home',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      body: Column(
        children: [
          const StoriesBar(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<PostModel>>(
              stream: _feed,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load the feed.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final posts = snapshot.data!;
                if (posts.isEmpty) return _empty();

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: posts.length,
                  itemBuilder: (context, index) => PostCard(
                    post: posts[index],
                    myUid: _myUid,
                    service: _service,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
