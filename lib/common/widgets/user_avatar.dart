import 'dart:convert';

import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final String photoBase64;
  final double size;

  const UserAvatar({
    super.key,
    required this.name,
    this.photoBase64 = '',
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.32);

    if (photoBase64.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: radius,
          child: Image.memory(
            base64Decode(photoBase64),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true, // no flicker when it reloads
          ),
        );
      } catch (_) {
        // Broken data: fall through to the letter avatar.
      }
    }

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
