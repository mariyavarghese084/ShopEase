import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

/// Contract defining authentication operations.
abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> signOut();
}

/// Firebase implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth? _injectedAuth;

  FirebaseAuthRepository({FirebaseAuth? auth}) : _injectedAuth = auth;

  FirebaseAuth get _auth {
    if (_injectedAuth != null) return _injectedAuth;
    if (!FirebaseService.isInitialized) {
      throw 'Firebase is not configured yet. Run `flutterfire configure` to connect your project.';
    }
    return FirebaseService.auth;
  }

  @override
  Stream<User?> get authStateChanges {
    if (_injectedAuth == null && !FirebaseService.isInitialized) {
      return const Stream.empty();
    }
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  User? get currentUser {
    if (_injectedAuth == null && !FirebaseService.isInitialized) {
      return null;
    }
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Maps Firebase error codes to user-friendly messages.
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account exists with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or email. Please check your credentials.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'The email address is formatted incorrectly.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a few minutes.';
      default:
        return e.message ?? 'An unexpected authentication error occurred.';
    }
  }
}
