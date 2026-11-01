import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_notification_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/customer_model.dart';
import '../../../models/product_model.dart';

/// Luxury AÈRA modal dialog allowing administrators to compose and dispatch
/// push notifications and in-app campaign announcements.
class SendNotificationDialog extends StatefulWidget {
  const SendNotificationDialog({super.key});

  static Future<void> show(BuildContext context) {
    final controller = context.read<AdminNotificationController>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider<AdminNotificationController>.value(
        value: controller,
        child: const SendNotificationDialog(),
      ),
    );
  }

  @override
  State<SendNotificationDialog> createState() => _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<SendNotificationDialog> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _orderIdController = TextEditingController();

  String _selectedType = 'general';
  String _selectedAudience = 'all'; // 'all' or 'customer'
  CustomerModel? _selectedCustomer;
  String _navigationType = 'none'; // 'none', 'product', 'order'
  ProductModel? _selectedProduct;

  final Map<String, String> _typeLabels = {
    'general': 'General Announcement',
    'promotion': 'Promotional Offer',
    'product': 'New Product Launch',
    'festival': 'Festival Special',
    'update': 'Important Update',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _imageUrlController.dispose();
    _orderIdController.dispose();
    super.dispose();
  }

  Future<void> _handleSend(AdminNotificationController controller) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedAudience == 'customer' && _selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a target customer.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    String? targetRoute;
    String? targetId;

    if (_navigationType == 'product' && _selectedProduct != null) {
      targetRoute = '/customer/products/detail';
      targetId = _selectedProduct!.id;
    } else if (_navigationType == 'order' &&
        _orderIdController.text.trim().isNotEmpty) {
      targetRoute = '/customer/orders';
      targetId = _orderIdController.text.trim();
    }

    final success = await controller.sendNotification(
      title: _titleController.text,
      message: _messageController.text,
      type: _selectedType,
      audience: _selectedAudience,
      selectedCustomerId: _selectedCustomer?.uid,
      selectedCustomerName: _selectedCustomer?.fullName,
      imageUrl: _imageUrlController.text,
      targetRoute: targetRoute,
      targetId: targetId,
    );

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              controller.successMessage ?? 'Notification sent successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (controller.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(controller.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminNotificationController>();
    final isSending = controller.isSending;
    final customers = controller.availableCustomers;
    final products = controller.availableProducts;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 24,
      ),
      child: Container(
        width: 620,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withAlpha(50),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.luxuryWine.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: AppColors.luxuryWine,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compose Push Notification',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mainText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Create broadcast campaigns or direct customer announcements',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.secondaryText,
                    ),
                    onPressed: isSending
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),

            // ── Form Body ────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Notification Type
                      _buildLabel('Notification Type'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withAlpha(60),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedType,
                            isExpanded: true,
                            dropdownColor: AppColors.cardBackground,
                            items: _typeLabels.entries.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.key,
                                child: Text(
                                  e.value,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.mainText,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: isSending
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() => _selectedType = val);
                                    }
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Audience Selection
                      _buildLabel('Target Audience'),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAudienceTile(
                              title: 'All Customers',
                              subtitle: '${customers.length} registered',
                              isSelected: _selectedAudience == 'all',
                              onTap: () =>
                                  setState(() => _selectedAudience = 'all'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildAudienceTile(
                              title: 'Specific Customer',
                              subtitle: 'Direct message',
                              isSelected: _selectedAudience == 'customer',
                              onTap: () => setState(
                                () => _selectedAudience = 'customer',
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_selectedAudience == 'customer') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withAlpha(60),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<CustomerModel>(
                              value: _selectedCustomer,
                              hint: const Text(
                                'Select a customer from directory',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              isExpanded: true,
                              dropdownColor: AppColors.cardBackground,
                              items: customers.map((c) {
                                return DropdownMenuItem<CustomerModel>(
                                  value: c,
                                  child: Text(
                                    '${c.fullName.isNotEmpty ? c.fullName : 'Customer'} (${c.email})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.mainText,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: isSending
                                  ? null
                                  : (val) {
                                      setState(() => _selectedCustomer = val);
                                    },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Title
                      _buildLabel('Campaign Title *'),
                      TextFormField(
                        controller: _titleController,
                        enabled: !isSending,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.mainText,
                        ),
                        decoration: _inputDecoration(
                          hint: 'e.g. Exclusive Weekend Fragrance Offer',
                          icon: Icons.title_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 3) {
                            return 'Title must be at least 3 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Message Body
                      _buildLabel('Message Body *'),
                      TextFormField(
                        controller: _messageController,
                        enabled: !isSending,
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.mainText,
                        ),
                        decoration: _inputDecoration(
                          hint:
                              'Enter your notification announcement content here...',
                          icon: Icons.message_outlined,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 5) {
                            return 'Message must be at least 5 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Optional Image URL
                      _buildLabel('Banner Image URL (Optional)'),
                      TextFormField(
                        controller: _imageUrlController,
                        enabled: !isSending,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.mainText,
                        ),
                        decoration: _inputDecoration(
                          hint: 'https://example.com/banner.jpg',
                          icon: Icons.image_outlined,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (_imageUrlController.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            _imageUrlController.text.trim(),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              height: 60,
                              alignment: Alignment.center,
                              color: AppColors.surfaceVariant.withAlpha(80),
                              child: const Text(
                                'Invalid image URL or image failed to load',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Navigation Reference
                      _buildLabel('Tap Action / Navigation Reference'),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          _buildNavOption('None', 'none'),
                          _buildNavOption('Product', 'product'),
                          _buildNavOption('Order', 'order'),
                        ],
                      ),
                      if (_navigationType == 'product') ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withAlpha(60),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<ProductModel>(
                              value: _selectedProduct,
                              hint: const Text(
                                'Select a product to open on tap',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              isExpanded: true,
                              dropdownColor: AppColors.cardBackground,
                              items: products.map((p) {
                                return DropdownMenuItem<ProductModel>(
                                  value: p,
                                  child: Text(
                                    '${p.name} - \$${p.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.mainText,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: isSending
                                  ? null
                                  : (val) {
                                      setState(() => _selectedProduct = val);
                                    },
                            ),
                          ),
                        ),
                      ] else if (_navigationType == 'order') ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _orderIdController,
                          enabled: !isSending,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.mainText,
                          ),
                          decoration: _inputDecoration(
                            hint: 'Enter Order ID (e.g. ORD-123456)',
                            icon: Icons.receipt_long_outlined,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Footer Buttons ───────────────────────────────────────────────
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: isSending
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondaryText,
                      side: const BorderSide(color: AppColors.divider),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(80, 44),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton(
                    onPressed: isSending ? null : () => _handleSend(controller),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.luxuryWine,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(120, 44),
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send_rounded, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Dispatch Notification',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.mainText,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildAudienceTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.luxuryWine.withAlpha(20)
              : AppColors.surfaceVariant.withAlpha(50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.luxuryWine : AppColors.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: isSelected
                  ? AppColors.luxuryWine
                  : AppColors.secondaryText,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.luxuryWine
                          : AppColors.mainText,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavOption(String label, String value) {
    final isSelected = _navigationType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.luxuryWine.withAlpha(30),
      backgroundColor: AppColors.surfaceVariant.withAlpha(50),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isSelected ? AppColors.luxuryWine : AppColors.secondaryText,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _navigationType = value);
        }
      },
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
      prefixIcon: Icon(icon, size: 20, color: AppColors.secondaryText),
      filled: true,
      fillColor: AppColors.surfaceVariant.withAlpha(60),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
