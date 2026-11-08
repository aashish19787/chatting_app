import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Hold to record, release to send. Slide away and release to cancel
/// is not supported: release always sends (under 1 second is discarded).
class VoiceRecorderButton extends StatefulWidget {
  final Future<void> Function(String path, int seconds) onRecorded;
  final void Function(String message) onError;

  const VoiceRecorderButton({
    super.key,
    required this.onRecorded,
    required this.onError,
  });

  @override
  State<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends State<VoiceRecorderButton> {
  final _recorder = AudioRecorder();
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      if (!await _recorder.hasPermission()) {
        widget.onError('Microphone permission is needed.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 120) _stop(); // 2 minute limit
      });
    } catch (e) {
      debugPrint('RECORD START ERROR: $e');
      widget.onError('Could not start recording.');
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _timer?.cancel();
    final seconds = _seconds;
    setState(() => _recording = false);
    try {
      final path = await _recorder.stop();
      if (path == null || seconds < 1) return;
      debugPrint(
        'VOICE FILE: $path size=${await File(path).length()} bytes, ${seconds}s',
      );
      await widget.onRecorded(path, seconds);
    } catch (_) {
      widget.onError('Could not send the voice message.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stop(),
      onTap: () => widget.onError('Hold the mic to record.'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: _recording
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.fiber_manual_record,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}',
                  ),
                ],
              )
            : const Icon(Icons.mic_rounded, color: Color(0xFF6366F1)),
      ),
    );
  }
}
