import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class VoiceBubble extends StatefulWidget {
  final String url;
  final int seconds;
  final Color color;

  const VoiceBubble({
    super.key,
    required this.url,
    required this.seconds,
    required this.color,
  });

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  StreamSubscription? _a, _b;

  @override
  void initState() {
    super.initState();
    _a = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    });
    _b = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _pos = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _a?.cancel();
    _b?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(widget.url));
      setState(() => _playing = true);
    }
  }

  String _fmt(int s) => '${(s ~/ 60)}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = widget.seconds <= 0 ? 1 : widget.seconds;
    final progress = (_pos.inMilliseconds / (total * 1000)).clamp(0.0, 1.0);

    return SizedBox(
      width: 210,
      child: Row(
        children: [
          IconButton(
            onPressed: _toggle,
            icon: Icon(
              _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: widget.color,
              size: 36,
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              color: widget.color,
              backgroundColor: widget.color.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmt(_playing ? _pos.inSeconds : widget.seconds),
            style: TextStyle(fontSize: 12, color: widget.color),
          ),
        ],
      ),
    );
  }
}
