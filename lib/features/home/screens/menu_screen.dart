import 'saved_posts_screen.dart';
import '../widgets/privacy_tiles.dart';
import 'blocked_screen.dart';

import 'package:flutter/material.dart';

import '../../../common/widgets/user_avatar.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/user_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../chats/screens/new_group_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../profile/screens/user_profile_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Log out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final auth = FirebaseAuthService();
    final uid = auth.currentUser?.uid;
    // Must happen BEFORE signing out, because the write needs a login.
    if (uid != null) {
      await FirestoreService().setOnlineStatus(uid, false);
    }
    await auth.logout();
  }

  Widget _item({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFF6366F1)).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? const Color(0xFF6366F1), size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuthService().currentUser?.uid ?? '';
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Menu',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          StreamBuilder<UserModel?>(
            stream: service.userStream(myUid),
            builder: (context, snapshot) {
              final user = snapshot.data;
              final name = user?.name ?? 'Loading...';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: UserAvatar(
                  name: name,
                  photoBase64: user?.photoBase64 ?? '',
                  size: 56,
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text('View your profile'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(uid: myUid),
                  ),
                ),
              );
            },
          ),
          const Divider(height: 24),
          _item(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          _item(
            icon: Icons.group_add_outlined,
            title: 'New group',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const NewGroupScreen())),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (context, mode, _) {
              return ListTile(
                leading: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.dark_mode_outlined,
                    color: Color(0xFF6366F1),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Dark mode',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: Switch(
                  value: mode == ThemeMode.dark,
                  onChanged: (_) => ThemeController.instance.toggle(),
                ),
                onTap: ThemeController.instance.toggle,
              );
            },
          ),
          const Divider(height: 24),
          const PrivacyTiles(),
          _item(
            icon: Icons.bookmark_border_rounded,
            title: 'Saved posts',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SavedPostsScreen())),
          ),
          _item(
            icon: Icons.block_rounded,
            title: 'Blocked people',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BlockedScreen())),
          ),
          _item(
            icon: Icons.logout_rounded,
            title: 'Log out',
            color: Colors.redAccent,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
