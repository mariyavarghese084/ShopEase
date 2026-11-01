import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/routes/app_routes.dart';
import '../models/customer_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/customer_repository.dart';

/// Manages authentication state, sign in, registration, and password resets.
class AuthController extends ChangeNotifier {
  final AuthRepository _authRepository;
  final CustomerRepository _customerRepository;
  StreamSubscription<User?>? _authSubscription;

  User? _currentUser;
  CustomerModel? _customerProfile;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _needsProfileCompletion = false;

  AuthController({
    AuthRepository? authRepository,
    CustomerRepository? customerRepository,
  })  : _authRepository = authRepository ?? FirebaseAuthRepository(),
        _customerRepository = customerRepository ?? FirestoreCustomerRepository() {
    _initAuthState();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  User? get currentUser => _currentUser;
  CustomerModel? get customerProfile => _customerProfile;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _customerProfile?.isAdmin ?? false;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get needsProfileCompletion => _needsProfileCompletion;

  /// Returns the post-authentication destination route based on verified role.
  /// Verified admin -> [AppRoutes.adminDashboard].
  /// Regular customer, missing profile, or unknown role -> safe fallback [AppRoutes.customerHome].
  String get postLoginRoute {
    if (isAdmin) {
      return AppRoutes.adminDashboard;
    }
    return AppRoutes.customerHome;
  }

  void _initAuthState() {
    try {
      _currentUser = _authRepository.currentUser;
      _authSubscription = _authRepository.authStateChanges.listen((user) async {
        _currentUser = user;
        if (user != null) {
          try {
            _customerProfile =
                await _customerRepository.getCustomerProfile(user.uid);
            _needsProfileCompletion = _customerProfile == null;
          } catch (e) {
            debugPrint('[ShopEase:Auth] Notice fetching profile in auth-state stream: $e');
            _needsProfileCompletion = true;
          }
        } else {
          _customerProfile = null;
          _needsProfileCompletion = false;
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('[ShopEase:Auth] Auth state initialization notice: $e');
    }
  }

  Future<void> _loadCustomerProfile(String uid) async {
    try {
      _customerProfile = await _customerRepository.getCustomerProfile(uid);
      _needsProfileCompletion = _customerProfile == null;
    } catch (e) {
      debugPrint('[ShopEase:Auth] Error in _loadCustomerProfile: $e');
      _needsProfileCompletion = true;
    }
  }

  /// Verifies administrator privileges against the trusted Firestore profile.
  /// Does not trust client-supplied input and always fetches from the repository.
  Future<bool> verifyAdminPrivilege() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      _customerProfile = null;
      notifyListeners();
      return false;
    }
    try {
      final profile = await _customerRepository.getCustomerProfile(user.uid);
      _customerProfile = profile;
      notifyListeners();
      return profile?.isAdmin ?? false;
    } catch (e) {
      debugPrint('[ShopEase:Auth] Error verifying admin privileges: $e');
      return false;
    }
  }

  /// Sign in with email and password.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      debugPrint('[ShopEase:Auth] Signing in with: $email');
      final credential = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _currentUser = credential.user;
      if (_currentUser != null) {
        await _loadCustomerProfile(_currentUser!.uid);
      }
      return true;
    } catch (e, stack) {
      debugPrint('[ShopEase:Auth] Sign in error: $e\n$stack');
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register a new customer and create their Firestore customer document.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    // Prevent repeated submissions while loading
    if (_isLoading) {
      debugPrint('[ShopEase:Auth] Sign Up already in progress, ignoring duplicate submission.');
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      // ── Step 3: Firebase Authentication request started ───────────────────
      debugPrint('[ShopEase:Auth] Step 3: Firebase Authentication request started for $email');
      final credential = await _authRepository.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw 'User account could not be created by Firebase Auth.';
      }

      // ── Step 4: Firebase Authentication user created ──────────────────────
      debugPrint('[ShopEase:Auth] Step 4: Firebase Authentication user created with UID: ${user.uid}');

      // ── Step 5: Firebase display name updated ─────────────────────────────
      try {
        await user.updateDisplayName(fullName.trim());
        debugPrint('[ShopEase:Auth] Step 5: Firebase display name updated to "$fullName"');
      } catch (displayNameError) {
        debugPrint('[ShopEase:Auth] Step 5 notice: Display name update non-fatal: $displayNameError');
      }

      // ── Step 6: Firestore customer-profile write started ──────────────────
      final now = DateTime.now();
      final customer = CustomerModel(
        uid: user.uid,
        fullName: fullName.trim(),
        email: email.trim(),
        role: 'customer',
        createdAt: now,
        updatedAt: now,
      );

      debugPrint('[ShopEase:Auth] Step 6: Firestore customer-profile write started at customers/${user.uid}');
      await _customerRepository.createCustomerProfile(customer);

      // ── Step 7: Firestore customer-profile write completed ────────────────
      debugPrint('[ShopEase:Auth] Step 7: Firestore customer-profile write completed');

      _customerProfile = customer;
      _currentUser = user;
      _needsProfileCompletion = false;
      return true;
    } catch (e, stack) {
      debugPrint('[ShopEase:Auth] Registration failure: $e\n$stack');
      _errorMessage = e.toString();

      // If user was created in Firebase Auth but Firestore profile write failed:
      // Preserve the authenticated user session so they do not attempt to register the same email again!
      if (_authRepository.currentUser != null) {
        _currentUser = _authRepository.currentUser;
        _needsProfileCompletion = true;
        debugPrint('[ShopEase:Auth] Preserved authenticated session for UID ${_currentUser!.uid}; profile setup pending.');
      }
      return false;
    } finally {
      // ── Step 8: AuthController loading state cleared ─────────────────────
      _isLoading = false;
      debugPrint('[ShopEase:Auth] Step 8: AuthController loading state cleared in finally block');
      notifyListeners();
    }
  }

  /// Creates/completes a missing Firestore customer profile for an authenticated user.
  Future<bool> completeProfile({required String fullName}) async {
    if (_currentUser == null) {
      _errorMessage = 'No active authentication session. Please sign in first.';
      notifyListeners();
      return false;
    }

    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final customer = CustomerModel(
        uid: _currentUser!.uid,
        fullName: fullName.trim().isNotEmpty
            ? fullName.trim()
            : (_currentUser!.displayName ?? 'Customer'),
        email: _currentUser!.email ?? '',
        role: 'customer',
        createdAt: now,
        updatedAt: now,
      );

      debugPrint('[ShopEase:Auth] Retrying profile creation for UID: ${_currentUser!.uid}');
      await _customerRepository.createCustomerProfile(customer);

      _customerProfile = customer;
      _needsProfileCompletion = false;
      debugPrint('[ShopEase:Auth] Customer profile successfully created on retry!');
      return true;
    } catch (e, stack) {
      debugPrint('[ShopEase:Auth] Error in completeProfile: $e\n$stack');
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send password reset link to user's email.
  Future<bool> sendPasswordReset({required String email}) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _authRepository.sendPasswordResetEmail(email: email);
      _successMessage = 'Password reset instructions sent to $email.';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out current customer.
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authRepository.signOut();
      _currentUser = null;
      _customerProfile = null;
      _needsProfileCompletion = false;
      _errorMessage = null;
      _successMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear transient error or success notices.
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Sets profile in memory for deterministic unit & widget tests.
  void setCustomerProfileForTesting(CustomerModel? profile, {User? user}) {
    _customerProfile = profile;
    _currentUser = user;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
