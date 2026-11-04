import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/chats/screens/chat_list_screen.dart';
import 'services/firebase_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chatting App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFF),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Decides which screen to show based on whether someone is logged in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuthService().authStateChanges,
      builder: (context, snapshot) {
        // Still checking whether a user is saved on this device.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          );
        }

        // A user exists -> logged in, show the chat list.
        if (snapshot.hasData) {
          return const ChatListScreen();
        }

        // No user -> show login.
        return const LoginScreen();
      },
    );
  }
}