import 'dart:convert';

import 'package:flutter/material.dart';

/// Round group picture, or a group icon when there is no photo.
class GroupAvatar extends StatelessWidget {
  final String photoBase64;
  final double size;

  const GroupAvatar({super.key, this.photoBase64 = '', this.size = 48});

  @override
  Widget build(BuildContext context) {
    if (photoBase64.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(photoBase64),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      } catch (_) {
        // Broken data: fall through to the icon.
      }
    }

    return Container(
      height: size,
      width: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.groups_rounded, color: Colors.white, size: size * 0.5),
    );
  }
}
