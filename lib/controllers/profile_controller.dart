import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

/// Manages customer profile viewing and updating from Firestore.
class ProfileController extends ChangeNotifier {
  final CustomerRepository _customerRepository;

  CustomerModel? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  ProfileController({CustomerRepository? customerRepository})
      : _customerRepository = customerRepository ?? FirestoreCustomerRepository();

  CustomerModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  /// Loads profile for the given [uid] from Firestore.
  Future<void> loadProfile(String uid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _customerRepository.getCustomerProfile(uid);
      if (_profile == null) {
        _errorMessage = 'Customer profile document not found in Firestore.';
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates existing customer profile information.
  Future<bool> updateProfile(CustomerModel updated) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _customerRepository.updateCustomerProfile(updated);
      _profile = updated;
      _successMessage = 'Profile updated successfully.';
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
