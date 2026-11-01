import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_product_controller.dart';
import '../../../controllers/home_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/category_model.dart';
import '../../../models/product_model.dart';
import '../../../services/product_image_storage_service.dart';

/// Modal dialog for adding or editing a luxury product in the ShopEase catalog.
class ProductFormDialog extends StatefulWidget {
  final ProductModel? product;

  const ProductFormDialog({super.key, this.product});

  static Future<bool?> show(BuildContext context, {ProductModel? product}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductFormDialog(product: product),
    );
  }

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _priceController;
  late TextEditingController _originalPriceController;
  late TextEditingController _stockController;
  late TextEditingController _subtitleController;
  late TextEditingController _volumeController;
  late TextEditingController _tagController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;

  late String _selectedCategoryId;
  late String _selectedCategoryName;
  late bool _isAvailable;
  late bool _isFeatured;
  bool _isSaving = false;
  String? _uploadStatusMessage;

  Uint8List? _selectedImageBytes;
  String? _selectedImageFileName;
  String? _selectedImageContentType;
  String? _imageValidationError;

  ProductImageStorageService get _imageService {
    try {
      return context.read<ProductImageStorageService>();
    } catch (_) {
      return FirebaseProductImageStorageService();
    }
  }

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameController = TextEditingController(text: p?.name ?? '');
    _brandController = TextEditingController(text: p?.brand ?? 'AÈRA');
    _priceController =
        TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _originalPriceController = TextEditingController(
      text: p?.originalPrice != null ? p!.originalPrice!.toStringAsFixed(2) : '',
    );
    _stockController = TextEditingController(
      text: p != null ? p.stockQuantity.toString() : '10',
    );
    _subtitleController = TextEditingController(
      text: p?.subtitle ?? 'LUXURY COSMETICS',
    );
    _volumeController = TextEditingController(text: p?.volume ?? 'Full Size');
    _tagController = TextEditingController(text: p?.tag ?? '');
    _descriptionController =
        TextEditingController(text: p?.description ?? '');
    _imageUrlController = TextEditingController(
      text: p?.imageUrl ??
          'Assest/The Viral Blush Beauty Lovers Are Obsessed With.jpeg',
    );

    _selectedCategoryId = p?.categoryId ?? 'blush';
    _selectedCategoryName = p?.categoryName ?? 'Blush & Cheeks';
    _isAvailable = p?.isAvailable ?? true;
    _isFeatured = p?.isFeatured ?? false;

    _imageUrlController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _pickImage() async {
    setState(() => _imageValidationError = null);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final fileName = picked.name;

      // Validate format and size upfront using service helper
      final validationError = FirebaseProductImageStorageService.validateImageFile(
        fileName: fileName,
        byteLength: bytes.length,
      );
      if (validationError != null) {
        setState(() {
          _imageValidationError = validationError;
        });
        return;
      }

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageFileName = fileName;
        _selectedImageContentType = picked.mimeType ?? 'image/jpeg';
        _imageValidationError = null;
      });
    } catch (e) {
      setState(() {
        _imageValidationError = 'Failed to select image: $e';
      });
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageFileName = null;
      _selectedImageContentType = null;
      _imageValidationError = null;
      if (widget.product?.imageUrl != null) {
        _imageUrlController.text = widget.product!.imageUrl!;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _stockController.dispose();
    _subtitleController.dispose();
    _volumeController.dispose();
    _tagController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<AdminProductController>().categories;
    final validCategories = categories.where((c) => c.id != 'all').toList();
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final viewInsets = mediaQuery.viewInsets;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 960;

    // Dynamically calculate max height to prevent overflow when virtual keyboard opens
    final availableHeight = size.height - viewInsets.bottom - (isMobile ? 24 : 48);
    final dialogMaxHeight = (availableHeight > 340 ? availableHeight : 340.0)
        .clamp(340.0, size.height * (isMobile ? 0.96 : 0.88));

    final dialogWidth = isMobile
        ? double.infinity
        : (isTablet ? (size.width * 0.92).clamp(580.0, 720.0) : 740.0);

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 8 : 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 740,
          maxHeight: dialogMaxHeight,
        ),
        child: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Header (fixed)
              _buildHeader(isMobile),

              // 2. Upload / Status progress banner
              if (_isSaving && _uploadStatusMessage != null)
                _buildStatusBar(),

              // 3. Form Body (scrollable)
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.all(isMobile ? 16 : 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 560;
                      return Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section 1: Product Information
                            _buildSectionTitle('1. Product Information'),
                            const SizedBox(height: 12),
                            if (isNarrow) ...[
                              _buildTextField(
                                controller: _nameController,
                                label: 'Product Name *',
                                hint: 'e.g. Soft Pinch Liquid Blush',
                                validator: (val) => val == null || val.trim().isEmpty
                                    ? 'Product name is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _brandController,
                                label: 'Brand',
                                hint: 'e.g. Rare Beauty, AÈRA',
                              ),
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: _buildTextField(
                                      controller: _nameController,
                                      label: 'Product Name *',
                                      hint: 'e.g. Soft Pinch Liquid Blush',
                                      validator: (val) => val == null || val.trim().isEmpty
                                          ? 'Product name is required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 4,
                                    child: _buildTextField(
                                      controller: _brandController,
                                      label: 'Brand',
                                      hint: 'e.g. Rare Beauty, AÈRA',
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            if (isNarrow) ...[
                              _buildCategoryDropdown(validCategories),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _subtitleController,
                                label: 'Subtitle / Classification',
                                hint: 'e.g. DEWY LIQUID BLUSH',
                              ),
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: _buildCategoryDropdown(validCategories),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 5,
                                    child: _buildTextField(
                                      controller: _subtitleController,
                                      label: 'Subtitle / Classification',
                                      hint: 'e.g. DEWY LIQUID BLUSH',
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 24),

                            // Section 2: Pricing & Stock Inventory
                            _buildSectionTitle('2. Pricing & Stock Inventory'),
                            const SizedBox(height: 12),
                            if (isNarrow) ...[
                              _buildTextField(
                                controller: _priceController,
                                label: 'Selling Price (₹) *',
                                hint: 'e.g. 1850.00',
                                prefixText: '₹ ',
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Price required';
                                  }
                                  final p = double.tryParse(val.trim());
                                  if (p == null || p <= 0) {
                                    return 'Must be > 0';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _originalPriceController,
                                label: 'Original / MRP (₹)',
                                hint: 'Optional MRP',
                                prefixText: '₹ ',
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                validator: (val) {
                                  if (val != null && val.trim().isNotEmpty) {
                                    final p = double.tryParse(val.trim());
                                    if (p == null || p < 0) {
                                      return 'Invalid price';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _stockController,
                                label: 'Stock Quantity *',
                                hint: 'e.g. 25',
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Stock required';
                                  }
                                  final s = int.tryParse(val.trim());
                                  if (s == null || s < 0) {
                                    return 'Must be >= 0';
                                  }
                                  return null;
                                },
                              ),
                            ] else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: _buildTextField(
                                      controller: _priceController,
                                      label: 'Selling Price (₹) *',
                                      hint: 'e.g. 1850.00',
                                      prefixText: '₹ ',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Price required';
                                        }
                                        final p = double.tryParse(val.trim());
                                        if (p == null || p <= 0) {
                                          return 'Must be > 0';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: _buildTextField(
                                      controller: _originalPriceController,
                                      label: 'Original / MRP (₹)',
                                      hint: 'Optional MRP',
                                      prefixText: '₹ ',
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                      validator: (val) {
                                        if (val != null && val.trim().isNotEmpty) {
                                          final p = double.tryParse(val.trim());
                                          if (p == null || p < 0) {
                                            return 'Invalid price';
                                          }
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: _buildTextField(
                                      controller: _stockController,
                                      label: 'Stock Quantity *',
                                      hint: 'e.g. 25',
                                      keyboardType: TextInputType.number,
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Stock required';
                                        }
                                        final s = int.tryParse(val.trim());
                                        if (s == null || s < 0) {
                                          return 'Must be >= 0';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            if (isNarrow) ...[
                              _buildTextField(
                                controller: _volumeController,
                                label: 'Volume / Size',
                                hint: 'e.g. 7.5 ml, 50 ml, Standard',
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: _tagController,
                                label: 'Highlight Tag (Optional)',
                                hint: 'e.g. Bestseller, New, Trending',
                              ),
                            ] else
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _volumeController,
                                      label: 'Volume / Size',
                                      hint: 'e.g. 7.5 ml, 50 ml, Standard',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildTextField(
                                      controller: _tagController,
                                      label: 'Highlight Tag (Optional)',
                                      hint: 'e.g. Bestseller, New, Trending',
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 24),

                            // Section 3: Product Description
                            _buildSectionTitle('3. Product Description'),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _descriptionController,
                              label: 'Detailed Description *',
                              hint: 'Describe formulation, benefits, and luxury finish...',
                              maxLines: 3,
                              validator: (val) => val == null || val.trim().isEmpty
                                  ? 'Description is required'
                                  : null,
                            ),

                            const SizedBox(height: 24),

                            // Section 4: Product Image & Storage
                            _buildSectionTitle('4. Product Image & Storage'),
                            const SizedBox(height: 8),
                            const Text(
                              'Upload a high-resolution luxury product image from your device, enter a remote URL, or select from curated presets.',
                              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
                            ),
                            const SizedBox(height: 12),
                            _buildImageSection(isNarrow),

                            const SizedBox(height: 24),

                            // Section 5: Publication & Visibility
                            _buildSectionTitle('5. Publication & Visibility'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    title: const Text(
                                      'Product Available for Purchase',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.mainText,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'When disabled, customers can view historical orders but cannot add item to cart.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    value: _isAvailable,
                                    activeThumbColor: AppColors.luxuryWine,
                                    onChanged: (val) => setState(() => _isAvailable = val),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  const Divider(height: 1),
                                  SwitchListTile(
                                    title: const Text(
                                      'Featured Product',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.mainText,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Promote this luxury item in the homepage featured recommendations carousel.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    value: _isFeatured,
                                    activeThumbColor: AppColors.champagneGold,
                                    onChanged: (val) => setState(() => _isFeatured = val),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 4. Footer Actions (fixed)
              _buildFooter(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 14 : 18,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.luxuryWine.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isEditing ? Icons.edit_note_rounded : Icons.add_business_rounded,
              color: AppColors.luxuryWine,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEditing ? 'Edit Product' : 'Add New Product',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isEditing
                      ? 'Modify product catalog specifications and stock in real time'
                      : 'Create and publish a luxury merchandise item to ShopEase',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
            color: AppColors.secondaryText,
            iconSize: 20,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      color: AppColors.luxuryWine.withAlpha(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.luxuryWine,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _uploadStatusMessage ?? 'Processing...',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.luxuryWine,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isMobile) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mainText,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(0, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _handleSaveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.luxuryWine,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(0, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        isEditing ? 'Save Changes' : 'Create Product',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.mainText,
                side: const BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSaveProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.luxuryWine,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      isEditing ? 'Save Changes' : 'Create Product',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.luxuryWine,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCategoryDropdown(List<CategoryModel> categories) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: categories.any((c) => c.id == _selectedCategoryId)
          ? _selectedCategoryId
          : (categories.isNotEmpty ? categories.first.id : 'blush'),
      decoration: InputDecoration(
        labelText: 'Category *',
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.luxuryWine, width: 1.5),
        ),
      ),
      items: categories.map((cat) {
        return DropdownMenuItem<String>(
          value: cat.id,
          child: Text(
            cat.name,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val == null) return;
        setState(() {
          _selectedCategoryId = val;
          _selectedCategoryName = categories
              .firstWhere((c) => c.id == val,
                  orElse: () => const CategoryModel(id: 'all', name: 'Cosmetics', icon: Icons.star))
              .name;
        });
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefixText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 13, color: AppColors.mainText),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.mainText,
        ),
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
        hintStyle: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.luxuryWine, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildImageSection(bool isNarrow) {
    final hasSelectedFile = _selectedImageBytes != null;
    final fileSizeMb = hasSelectedFile
        ? (_selectedImageBytes!.length / (1024 * 1024)).toStringAsFixed(2)
        : null;

    final imageControls = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upload Button & Selected File Status
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _pickImage,
              icon: Icon(
                hasSelectedFile
                    ? Icons.change_circle_outlined
                    : (isEditing
                        ? Icons.drive_folder_upload_rounded
                        : Icons.upload_file_rounded),
                size: 16,
              ),
              label: Text(
                hasSelectedFile
                    ? 'Replace Uploaded File'
                    : (isEditing
                        ? 'Upload Replacement Image'
                        : 'Upload Image from Computer'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelectedFile
                    ? AppColors.champagneGold
                    : AppColors.luxuryWine,
                foregroundColor:
                    hasSelectedFile ? AppColors.mainText : AppColors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (hasSelectedFile) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF2E7D32).withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Text(
                        '$_selectedImageFileName ($fileSizeMb MB)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _isSaving ? null : _clearSelectedImage,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: AppColors.error,
                ),
                label: const Text(
                  'Remove',
                  style: TextStyle(fontSize: 11, color: AppColors.error),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 0),
                ),
              ),
            ],
          ],
        ),

        // Validation Error / Timeout Alert Message
        if (_imageValidationError != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withAlpha(60)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _imageValidationError!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        const Text(
          'Or specify a remote URL / select a luxury catalog preset:',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _imageUrlController,
          label: 'Image URL or Asset Path *',
          hint: 'https://... or Assest/...',
          validator: (val) {
            if (_selectedImageBytes != null) return null; // File takes precedence
            if (val == null || val.trim().isEmpty) {
              return 'Please select an image file, enter a URL, or choose a preset';
            }
            return null;
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Quick Presets:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            _buildPresetChip(
              'Viral Blush',
              'Assest/The Viral Blush Beauty Lovers Are Obsessed With.jpeg',
            ),
            _buildPresetChip('Rare Beauty', 'Assest/RAL Rare Beauty.jpeg'),
            _buildPresetChip(
              'Velvet Lips',
              'Assest/Dreamy lipstick vibes 🌸 AI commercial photography for beauty brands.jpeg',
            ),
            _buildPresetChip(
              'Beachy Glow',
              'Assest/Beachy Blush in a Flash.jpeg',
            ),
            _buildPresetChip(
              'Green Botanics',
              'Assest/「インテリアグリーン」をセンスよく飾る7つのアイデア.jpeg',
            ),
          ],
        ),
      ],
    );

    final previewBox = Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _buildLiveImagePreview(),
      ),
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: previewBox),
          const SizedBox(height: 14),
          imageControls,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        previewBox,
        const SizedBox(width: 16),
        Expanded(child: imageControls),
      ],
    );
  }

  Widget _buildPresetChip(String label, String assetPath) {
    final isSelected =
        _selectedImageBytes == null && _imageUrlController.text.trim() == assetPath;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedImageBytes = null;
          _selectedImageFileName = null;
          _selectedImageContentType = null;
          _imageValidationError = null;
          _imageUrlController.text = assetPath;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.luxuryWine.withAlpha(30)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.luxuryWine : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.luxuryWine : AppColors.mainText,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveImagePreview() {
    if (_selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image_outlined,
              color: AppColors.secondaryText),
        ),
      );
    }

    final path = _imageUrlController.text.trim();
    if (path.isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: AppColors.secondaryText),
      );
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image_outlined,
              color: AppColors.secondaryText),
        ),
      );
    }

    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Center(
        child:
            Icon(Icons.broken_image_outlined, color: AppColors.secondaryText),
      ),
    );
  }

  Future<void> _handleSaveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _uploadStatusMessage = null;
    });

    try {
      final adminController = context.read<AdminProductController>();
      final homeController = context.read<HomeController>();
      final imageService = _imageService;

      final price = double.parse(_priceController.text.trim());
      final originalPrice = _originalPriceController.text.trim().isNotEmpty
          ? double.tryParse(_originalPriceController.text.trim())
          : null;
      final stock = int.parse(_stockController.text.trim());

      final existing = widget.product;
      final productId =
          existing?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}';

      String finalImageUrl;
      String? previousManagedImageUrl;

      // 1. If an image file was selected from disk, upload it first
      if (_selectedImageBytes != null) {
        setState(() {
          _uploadStatusMessage = 'Uploading product image to Cloud Storage...';
        });

        try {
          final uploadedUrl = await imageService.uploadProductImage(
            productId: productId,
            bytes: _selectedImageBytes!,
            fileName: _selectedImageFileName ?? 'product.jpg',
            contentType: _selectedImageContentType,
          );
          finalImageUrl = uploadedUrl;

          // If editing and previous image was in managed storage, mark for cleanup
          if (existing?.imageUrl != null &&
              imageService.isManagedStorageUrl(existing!.imageUrl!)) {
            previousManagedImageUrl = existing.imageUrl;
          }
        } catch (uploadError) {
          // Upload failed or timed out: surface to user and offer instant fallback
          setState(() {
            _imageValidationError = uploadError.toString();
            _isSaving = false;
            _uploadStatusMessage = null;
          });

          if (!mounted) return;

          // Prompt the user with an option to publish immediately with a luxury preset
          final shouldSaveWithPreset = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: AppColors.champagneGold,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Storage Upload Notice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload to Cloud Storage did not complete: $uploadError',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.mainText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Would you like to publish this product immediately using a curated luxury preset image? All product details (name, pricing, inventory, description) will be preserved and saved to Firestore.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Keep Editing'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryWine,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text('Publish with Preset Image'),
                ),
              ],
            ),
          );

          if (shouldSaveWithPreset == true && mounted) {
            final fallbackPreset = _getCategoryPresetImage(_selectedCategoryId);
            finalImageUrl = fallbackPreset;
            setState(() {
              _selectedImageBytes = null;
              _selectedImageFileName = null;
              _selectedImageContentType = null;
              _imageUrlController.text = fallbackPreset;
              _imageValidationError = null;
              _isSaving = true;
              _uploadStatusMessage = 'Saving product to catalog...';
            });
          } else {
            return;
          }
        }
      } else {
        // If no new file uploaded:
        if (isEditing &&
            _imageUrlController.text.trim().isEmpty &&
            existing?.imageUrl != null) {
          finalImageUrl = existing!.imageUrl!;
        } else {
          finalImageUrl = _imageUrlController.text.trim();
        }
      }

      setState(() {
        _uploadStatusMessage = 'Saving product to catalog...';
      });

      final product = ProductModel(
        id: productId,
        name: _nameController.text.trim(),
        brand: _brandController.text.trim().isNotEmpty
            ? _brandController.text.trim()
            : 'AÈRA',
        subtitle: _subtitleController.text.trim().isNotEmpty
            ? _subtitleController.text.trim()
            : 'LUXURY COSMETICS',
        volume: _volumeController.text.trim().isNotEmpty
            ? _volumeController.text.trim()
            : 'Full Size',
        availableSizes: existing?.availableSizes ?? const ['Standard', 'Deluxe'],
        description: _descriptionController.text.trim(),
        price: price,
        originalPrice: originalPrice,
        categoryId: _selectedCategoryId,
        categoryName: _selectedCategoryName,
        rating: existing?.rating ?? 4.8,
        reviewCount: existing?.reviewCount ?? 1,
        isFeatured: _isFeatured,
        stockQuantity: stock,
        isAvailable: _isAvailable,
        tag: _tagController.text.trim().isNotEmpty
            ? _tagController.text.trim()
            : null,
        topNote: existing?.topNote ?? 'Pure Botanical Essence',
        heartNote: existing?.heartNote ?? 'Velvet Complex',
        baseNote: existing?.baseNote ?? 'Radiant Silk Finish',
        visualIcon: existing?.visualIcon ?? Icons.auto_awesome,
        visualColor: existing?.visualColor ?? const Color(0xFF8A4652),
        secondaryColor: existing?.secondaryColor,
        imageUrl: finalImageUrl,
      );

      final success =
          await adminController.saveProduct(product, isEditing: isEditing);

      if (success) {
        // Now that the Firestore update succeeded, safely delete previous storage object if replaced
        if (previousManagedImageUrl != null &&
            previousManagedImageUrl != finalImageUrl) {
          await imageService.deleteProductImage(previousManagedImageUrl);
        }

        // Refresh customer catalog cache seamlessly
        homeController.loadHomeData();

        if (!mounted) return;
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Product updated successfully.'
                : 'New product added to catalog.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(adminController.errorMessage ?? 'Failed to save product.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving product: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadStatusMessage = null;
        });
      }
    }
  }

  String _getCategoryPresetImage(String categoryId) {
    switch (categoryId.toLowerCase()) {
      case 'blush':
        return 'Assest/The Viral Blush Beauty Lovers Are Obsessed With.jpeg';
      case 'lips':
      case 'lipstick':
        return 'Assest/Dreamy lipstick vibes 🌸 AI commercial photography for beauty brands.jpeg';
      case 'cheeks':
      case 'glow':
        return 'Assest/Beachy Blush in a Flash.jpeg';
      case 'skincare':
      case 'botanics':
        return 'Assest/「インテリアグリーン」をセンスよく飾る7つのアイデア.jpeg';
      default:
        return 'Assest/RAL Rare Beauty.jpeg';
    }
  }
}
