import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'firebase_service.dart';

/// Contract defining product image upload, asset management, and storage lifecycle.
abstract class ProductImageStorageService {
  /// Returns a curated list of bundled local luxury product image assets.
  List<String> getBundledImageAssets();

  /// Validates whether an image path or URL is well-formed.
  bool isValidImagePath(String path);

  /// Checks if an image URL belongs to the managed Firebase Storage bucket for products.
  bool isManagedStorageUrl(String url);

  /// Uploads product image bytes to Cloud Storage under `products/{productId}/{fileName}`.
  /// Returns the public download URL.
  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  });

  /// Safely deletes an existing product image from Cloud Storage if it belongs
  /// to the managed product storage path.
  Future<void> deleteProductImage(String imageUrlOrPath);
}

/// Firebase Cloud Storage implementation of [ProductImageStorageService].
class FirebaseProductImageStorageService implements ProductImageStorageService {
  final FirebaseStorage? _injectedStorage;
  static const Duration defaultTimeout = Duration(seconds: 60);
  final Duration timeout;

  FirebaseProductImageStorageService({
    FirebaseStorage? storage,
    Duration? timeout,
  })  : _injectedStorage = storage,
        timeout = timeout ?? defaultTimeout;

  FirebaseStorage? get _storage {
    if (_injectedStorage != null) return _injectedStorage;
    if (!FirebaseService.isInitialized) {
      return null;
    }
    return FirebaseStorage.instance;
  }

  static const List<String> _bundledAssets = [
    'Assest/The Viral Blush Beauty Lovers Are Obsessed With.jpeg',
    'Assest/1101693127585736227.jpeg',
    'Assest/1125759238142635105.jpeg',
    'Assest/454863631129179235.jpeg',
    'Assest/614037730488778069.jpeg',
    'Assest/Beachy Blush in a Flash.jpeg',
    'Assest/Dreamy lipstick vibes 🌸 AI commercial photography for beauty brands.jpeg',
    'Assest/Psd cosmetics beauty products and makeup social media post and discount sale banner design template _ Premium PSD.jpeg',
    'Assest/RAL Rare Beauty.jpeg',
    'Assest/「インテリアグリーン」をセンスよく飾る7つのアイデア.jpeg',
  ];

  /// Static helper to validate image file extension and size before upload.
  static String? validateImageFile({
    required String fileName,
    required int byteLength,
    int maxBytes = 5 * 1024 * 1024,
  }) {
    final lower = fileName.toLowerCase();
    final validExt = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
    if (!validExt) {
      return 'Unsupported format. Allowed formats: JPG, PNG, WEBP.';
    }
    if (byteLength > maxBytes) {
      final sizeMb = (byteLength / (1024 * 1024)).toStringAsFixed(1);
      final maxMb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
      return 'Image too large ($sizeMb MB). Maximum allowed size is $maxMb MB.';
    }
    return null;
  }

  @override
  List<String> getBundledImageAssets() => List.unmodifiable(_bundledAssets);

  @override
  bool isValidImagePath(String path) {
    final clean = path.trim();
    if (clean.isEmpty) return false;
    if (clean.startsWith('http://') || clean.startsWith('https://')) return true;
    if (clean.startsWith('Assest/') || clean.startsWith('assets/')) return true;
    return false;
  }

  @override
  bool isManagedStorageUrl(String url) {
    final clean = url.trim().toLowerCase();
    if (!clean.startsWith('http')) return false;
    // Check for Firebase Storage host and products folder
    final isFirebaseHost = clean.contains('firebasestorage.googleapis.com') ||
        clean.contains('firebasestorage.app');
    final isProductsPath = clean.contains('/products%2f') || clean.contains('/products/');
    return isFirebaseHost && isProductsPath;
  }

  @override
  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    // 1. Upfront byte validation
    final validationError = validateImageFile(fileName: fileName, byteLength: bytes.length);
    if (validationError != null) {
      throw validationError;
    }

    final storage = _storage;
    final sanitizedFile = _sanitizeFileName(fileName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destinationPath = 'products/$productId/${timestamp}_$sanitizedFile';

    if (storage == null) {
      debugPrint('[ShopEase:Storage] Running in offline or mock mode; generating simulated download URL.');
      return 'https://firebasestorage.googleapis.com/v0/b/shopease-59a47.firebasestorage.app/o/products%2F$productId%2F${timestamp}_$sanitizedFile?alt=media';
    }

    try {
      final ref = storage.ref(destinationPath);
      final metadata = SettableMetadata(
        contentType: contentType ?? _inferContentType(fileName),
        customMetadata: {
          'productId': productId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putData(bytes, metadata);

      // Diagnostic logging for web & mobile
      uploadTask.snapshotEvents.listen(
        (snapshot) {
          debugPrint(
            '[ShopEase:Storage] Transfer progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes} (${snapshot.state})',
          );
        },
        onError: (e) {
          debugPrint('[ShopEase:Storage] Stream error: $e');
        },
      );

      final taskSnapshot = await uploadTask.timeout(timeout);
      final downloadUrl = await taskSnapshot.ref.getDownloadURL();
      debugPrint('[ShopEase:Storage] Image uploaded successfully to $destinationPath -> $downloadUrl');
      return downloadUrl;
    } on TimeoutException catch (e) {
      debugPrint('[ShopEase:Storage] Upload timed out after ${timeout.inSeconds}s: $e');
      throw 'Image upload timed out after ${timeout.inSeconds}s. This usually indicates Firebase Cloud Storage is uninitialized or browser CORS is blocking localhost requests.';
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:Storage] FirebaseException during upload: ${e.code} - ${e.message}');
      if (e.code == 'retry-limit-exceeded') {
        throw 'Storage retry limit exceeded. The Firebase Storage bucket may not be enabled yet in Firebase Console (Build > Storage > Get Started) or CORS is blocking localhost.';
      } else if (e.code == 'object-not-found' || e.code == 'bucket-not-found') {
        throw 'Firebase Storage bucket not found (404). Please ensure Cloud Storage is activated in your Firebase console.';
      } else if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        throw 'Permission denied uploading to Firebase Storage. Please verify admin storage permissions.';
      } else if (e.code == 'canceled') {
        throw 'Image upload was canceled.';
      } else if (e.code == 'quota-exceeded') {
        throw 'Firebase Storage quota has been exceeded.';
      }
      throw 'Failed to upload product image to Firebase Storage (${e.code}): ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('[ShopEase:Storage] Unexpected upload error: $e');
      throw 'An unexpected error occurred during image upload: $e';
    }
  }

  @override
  Future<void> deleteProductImage(String imageUrlOrPath) async {
    if (!isManagedStorageUrl(imageUrlOrPath)) {
      debugPrint('[ShopEase:Storage] Skipping deletion for non-managed asset or external URL: $imageUrlOrPath');
      return;
    }

    final storage = _storage;
    if (storage == null) return;

    try {
      final ref = storage.refFromURL(imageUrlOrPath);
      await ref.delete().timeout(const Duration(seconds: 15));
      debugPrint('[ShopEase:Storage] Deleted old storage object: $imageUrlOrPath');
    } catch (e) {
      debugPrint('[ShopEase:Storage] Notice: Failed or non-critical error deleting old image: $e');
    }
  }

  String _sanitizeFileName(String name) {
    final clean = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return clean.isEmpty ? 'image.jpg' : clean;
  }

  String _inferContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

/// In-memory implementation of [ProductImageStorageService] for fast, hermetic unit tests.
class InMemoryProductImageStorageService implements ProductImageStorageService {
  final Map<String, Uint8List> uploadedImages = {};
  final List<String> deletedUrls = [];
  bool shouldFailUpload = false;

  @override
  List<String> getBundledImageAssets() => const [
        'Assest/The Viral Blush Beauty Lovers Are Obsessed With.jpeg',
        'Assest/RAL Rare Beauty.jpeg',
      ];

  @override
  bool isValidImagePath(String path) {
    final clean = path.trim();
    if (clean.isEmpty) return false;
    return clean.startsWith('http://') ||
        clean.startsWith('https://') ||
        clean.startsWith('Assest/') ||
        clean.startsWith('assets/');
  }

  @override
  bool isManagedStorageUrl(String url) {
    return url.contains('shopease-mock/o/products');
  }

  @override
  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    if (shouldFailUpload) {
      throw 'Mock storage upload failure triggered for testing.';
    }
    final url =
        'https://firebasestorage.googleapis.com/v0/b/shopease-mock/o/products%2F$productId%2F$fileName?alt=media';
    uploadedImages[url] = bytes;
    return url;
  }

  @override
  Future<void> deleteProductImage(String imageUrlOrPath) async {
    deletedUrls.add(imageUrlOrPath);
    uploadedImages.remove(imageUrlOrPath);
  }
}
