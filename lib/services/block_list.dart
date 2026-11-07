import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Keeps the list of people I blocked, so every screen can hide them.
class BlockList {
  BlockList._();
  static final BlockList instance = BlockList._();

  final ValueNotifier<Set<String>> ids = ValueNotifier<Set<String>>({});
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;

  void start(String uid) {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .snapshots()
        .listen(
          (s) => ids.value = s.docs.map((d) => d.id).toSet(),
          onError: (_) {},
        );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    ids.value = {};
  }
}
