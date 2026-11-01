import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_service.dart';

/// Contract defining customer favorites operations in Firestore.
abstract class FavoritesRepository {
  Future<Set<String>> getFavorites(String uid);
  Future<void> addFavorite(
    String uid,
    String productId, {
    Map<String, dynamic>? extraData,
  });
  Future<void> removeFavorite(String uid, String productId);
}

/// Cloud Firestore implementation of [FavoritesRepository].
///
/// Stores favorites at `/customers/{uid}/favorites/{productId}`.
///
class FirestoreFavoritesRepository implements FavoritesRepository {
  final FirebaseFirestore? _injectedFirestore;
  static const Duration _timeout = Duration(seconds: 10);

  FirestoreFavoritesRepository({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore {
    if (_injectedFirestore != null) return _injectedFirestore;
    if (!FirebaseService.isInitialized) {
      throw 'Firebase is not initialized yet.';
    }
    return FirebaseService.firestore;
  }

  CollectionReference<Map<String, dynamic>> _userFavorites(String uid) =>
      _firestore.collection('customers').doc(uid).collection('favorites');

  @override
  Future<Set<String>> getFavorites(String uid) async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return {};
    }
    try {
      final snapshot = await _userFavorites(uid).get().timeout(_timeout);
      return snapshot.docs.map((doc) => doc.id).toSet();
    } on FirebaseException catch (e) {
      debugPrint(
        '[ShopEase:FavoritesRepo] Firebase error fetching favorites: ${e.code} - ${e.message}',
      );
      return {};
    } catch (e) {
      debugPrint('[ShopEase:FavoritesRepo] Error loading favorites: $e');
      return {};
    }
  }

  @override
  Future<void> addFavorite(
    String uid,
    String productId, {
    Map<String, dynamic>? extraData,
  }) async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) return;
    try {
      final data = <String, dynamic>{
        'productId': productId,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (extraData != null) {
        data.addAll(extraData);
      }
      await _userFavorites(
        uid,
      ).doc(productId).set(data, SetOptions(merge: true)).timeout(_timeout);
    } on FirebaseException catch (e) {
      debugPrint(
        '[ShopEase:FavoritesRepo] Error adding favorite: ${e.code} - ${e.message}',
      );
    } catch (e) {
      debugPrint('[ShopEase:FavoritesRepo] Error saving favorite: $e');
    }
  }

  @override
  Future<void> removeFavorite(String uid, String productId) async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) return;
    try {
      await _userFavorites(uid).doc(productId).delete().timeout(_timeout);
    } on FirebaseException catch (e) {
      debugPrint(
        '[ShopEase:FavoritesRepo] Error removing favorite: ${e.code} - ${e.message}',
      );
    } catch (e) {
      debugPrint('[ShopEase:FavoritesRepo] Error deleting favorite: $e');
    }
  }
}
