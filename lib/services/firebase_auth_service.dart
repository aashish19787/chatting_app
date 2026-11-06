import 'package:firebase_auth/firebase_auth.dart';

/// A simple error type that carries a friendly message for the user.
class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);

  @override
  String toString() => message;
}

class FirebaseAuthService {
  // The connection to Firebase Authentication.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// The user who is logged in right now (null if nobody is logged in).
  User? get currentUser => _auth.currentUser;

  /// Emits a new value every time someone logs in or out.
  /// We will use this later to decide which screen to show.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Create a new account with email and password.
  Future<User?> register({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    } catch (_) {
      throw AuthFailure('Something went wrong. Please try again.');
    }
  }

  /// Log in an existing user.
  Future<User?> login({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    } catch (_) {
      throw AuthFailure('Something went wrong. Please try again.');
    }
  }

  /// Log the current user out.
  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Send a password reset email.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    } catch (_) {
      throw AuthFailure('Something went wrong. Please try again.');
    }
  }

  /// Turn Firebase's technical error codes into messages a user understands.
  String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
