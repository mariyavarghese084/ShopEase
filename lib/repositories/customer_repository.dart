import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../services/firebase_service.dart';

/// Contract defining customer profile data operations in Firestore.
abstract class CustomerRepository {
  Future<void> createCustomerProfile(CustomerModel customer);
  Future<CustomerModel?> getCustomerProfile(String uid);
  Stream<CustomerModel?> watchCustomerProfile(String uid);
  Future<void> updateCustomerProfile(CustomerModel customer);

  /// Retrieves all customer profile documents (admin customer directory).
  Future<List<CustomerModel>> getAllCustomers();
}

/// Firestore implementation of [CustomerRepository].
///
/// Stores and retrieves customer profiles at `/customers/{uid}`.
class FirestoreCustomerRepository implements CustomerRepository {
  final FirebaseFirestore? _injectedFirestore;
  static const Duration _operationTimeout = Duration(seconds: 10);

  FirestoreCustomerRepository({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore {
    if (_injectedFirestore != null) return _injectedFirestore;
    if (!FirebaseService.isInitialized) {
      throw 'Firebase is not configured yet. Run `flutterfire configure` to connect your project.';
    }
    return FirebaseService.firestore;
  }

  CollectionReference<Map<String, dynamic>> get _customersCollection =>
      _firestore.collection('customers');

  @override
  Future<void> createCustomerProfile(CustomerModel customer) async {
    try {
      debugPrint('[ShopEase:CustomerRepo] Writing customer doc to customers/${customer.uid} with timeout');
      
      // Perform write with bounded timeout so UI never hangs indefinitely
      await _customersCollection
          .doc(customer.uid)
          .set(customer.toMap())
          .timeout(
            _operationTimeout,
            onTimeout: () {
              throw TimeoutException(
                'Firestore profile write timed out after 10s. '
                'Please verify that Cloud Firestore is created and rules allow writes in Firebase Console.',
              );
            },
          );
      debugPrint('[ShopEase:CustomerRepo] Profile document saved successfully');
    } on TimeoutException catch (timeout) {
      debugPrint('[ShopEase:CustomerRepo] Timeout hit, verifying if document exists in Firestore...');
      final exists = await _verifyDocumentExists(customer.uid);
      if (exists) {
        debugPrint('[ShopEase:CustomerRepo] Document verified in Firestore despite timeout.');
        return;
      }
      throw timeout.message ?? 'Firestore write timed out.';
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:CustomerRepo] FirebaseException during createCustomerProfile: [${e.code}] ${e.message}');
      throw 'Failed to save customer profile (${e.code}): ${e.message ?? e.code}';
    } catch (e, stack) {
      debugPrint('[ShopEase:CustomerRepo] Unexpected error in createCustomerProfile: $e\n$stack');
      throw 'An unexpected error occurred while saving your profile: $e';
    }
  }

  Future<bool> _verifyDocumentExists(String uid) async {
    try {
      final doc = await _customersCollection
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 4));
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CustomerModel?> getCustomerProfile(String uid) async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return null;
    }
    try {
      final doc = await _customersCollection
          .doc(uid)
          .get()
          .timeout(_operationTimeout);
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return CustomerModel.fromFirestore(doc);
    } on TimeoutException {
      throw 'Loading profile timed out after 10s. Please check your internet connection.';
    } on FirebaseException catch (e) {
      throw 'Failed to fetch customer profile (${e.code}): ${e.message ?? e.code}';
    } catch (e) {
      throw 'An error occurred while loading your profile: $e';
    }
  }

  @override
  Stream<CustomerModel?> watchCustomerProfile(String uid) {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return const Stream.empty();
    }
    try {
      return _customersCollection.doc(uid).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return CustomerModel.fromFirestore(snapshot);
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<void> updateCustomerProfile(CustomerModel customer) async {
    try {
      final updatedData = customer.toMap();
      updatedData['updatedAt'] = FieldValue.serverTimestamp();
      await _customersCollection
          .doc(customer.uid)
          .update(updatedData)
          .timeout(_operationTimeout);
    } on FirebaseException catch (e) {
      throw 'Failed to update customer profile: ${e.message ?? e.code}';
    }
  }

  @override
  Future<List<CustomerModel>> getAllCustomers() async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return [];
    }
    try {
      final snapshot = await _customersCollection.get().timeout(_operationTimeout);
      final customers = snapshot.docs
          .map((doc) => CustomerModel.fromFirestore(doc))
          .toList();
      customers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return customers;
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:CustomerRepo] FirebaseException in getAllCustomers: [${e.code}] ${e.message}');
      throw 'Failed to load customers from Firestore (${e.code}): ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('[ShopEase:CustomerRepo] Error in getAllCustomers: $e');
      return [];
    }
  }
}

/// In-memory implementation of [CustomerRepository] for testing and offline environments.
class InMemoryCustomerRepository implements CustomerRepository {
  final Map<String, CustomerModel> _customers = {};

  InMemoryCustomerRepository([List<CustomerModel>? seedCustomers]) {
    if (seedCustomers != null) {
      for (final c in seedCustomers) {
        _customers[c.uid] = c;
      }
    }
  }

  @override
  Future<void> createCustomerProfile(CustomerModel customer) async {
    _customers[customer.uid] = customer;
  }

  @override
  Future<CustomerModel?> getCustomerProfile(String uid) async {
    return _customers[uid];
  }

  @override
  Stream<CustomerModel?> watchCustomerProfile(String uid) {
    return Stream.value(_customers[uid]);
  }

  @override
  Future<void> updateCustomerProfile(CustomerModel customer) async {
    _customers[customer.uid] = customer;
  }

  @override
  Future<List<CustomerModel>> getAllCustomers() async {
    final list = _customers.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
