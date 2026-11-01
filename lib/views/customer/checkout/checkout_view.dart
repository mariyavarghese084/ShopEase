import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/order_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/order_model.dart';
import '../orders/order_tracking_view.dart';

/// Luxury Checkout View handling shipping address, delivery selection,
/// payment methods, and order placement.
class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;

  int _selectedShippingOption =
      0; // 0: Free Express (1-2 days), 1: Same Day (₹149)
  int _selectedPaymentMethod =
      0; // 0: Card, 1: Apple/Google Pay, 2: Cash on Delivery
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    final profile = auth.customerProfile;

    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _postalCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  double get _shippingCost => _selectedShippingOption == 1 ? 149.00 : 0.00;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final total = cart.subtotal - cart.discountAmount + _shippingCost;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.mainText,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 1. Shipping Address Section ───────────────────────
                      _buildSectionHeader(
                        icon: Icons.location_on_outlined,
                        title: 'Shipping Address',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _nameController,
                              label: 'Full Name',
                              icon: Icons.person_outline,
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Please enter your name'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _buildTextField(
                              controller: _phoneController,
                              label: 'Phone Number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Please enter your phone number'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _buildTextField(
                              controller: _addressController,
                              label: 'Street Address, Apt / Suite',
                              icon: Icons.home_outlined,
                              validator: (val) =>
                                  val == null || val.trim().isEmpty
                                  ? 'Please enter your address'
                                  : null,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _buildTextField(
                                    controller: _cityController,
                                    label: 'City',
                                    icon: Icons.location_city_outlined,
                                    validator: (val) =>
                                        val == null || val.trim().isEmpty
                                        ? 'Enter city'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  flex: 4,
                                  child: _buildTextField(
                                    controller: _postalCodeController,
                                    label: 'Postal Code',
                                    icon: Icons.markunread_mailbox_outlined,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ── 2. Shipping Delivery Speed ────────────────────────
                      _buildSectionHeader(
                        icon: Icons.local_shipping_outlined,
                        title: 'Delivery Method',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            _buildCustomRadioTile(
                              title: 'Free Express Delivery',
                              subtitle:
                                  'Delivered within 1-2 business days with insured courier',
                              priceLabel: 'Free',
                              isSelected: _selectedShippingOption == 0,
                              onTap: () =>
                                  setState(() => _selectedShippingOption = 0),
                            ),
                            const Divider(height: 1),
                            _buildCustomRadioTile(
                              title: 'VIP Same-Day Delivery',
                              subtitle:
                                  'Instant priority courier delivery within 24 hours',
                              priceLabel: '₹149',
                              isSelected: _selectedShippingOption == 1,
                              onTap: () =>
                                  setState(() => _selectedShippingOption = 1),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ── 3. Payment Method ─────────────────────────────────
                      _buildSectionHeader(
                        icon: Icons.payment_outlined,
                        title: 'Payment Method',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            _buildCustomRadioTile(
                              title: 'Credit / Debit Card (Visa, Mastercard)',
                              subtitle:
                                  'Secure transaction with 256-bit encryption',
                              trailingIcon: Icons.credit_card_rounded,
                              isSelected: _selectedPaymentMethod == 0,
                              onTap: () =>
                                  setState(() => _selectedPaymentMethod = 0),
                            ),
                            if (_selectedPaymentMethod == 0) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md,
                                  0,
                                  AppSpacing.md,
                                  AppSpacing.md,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.divider,
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        size: 16,
                                        color: AppColors.secondaryText,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Saved Card: •••• •••• •••• 4242 (Expires 08/28)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.mainText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const Divider(height: 1),
                            _buildCustomRadioTile(
                              title: 'Apple Pay / Google Pay',
                              subtitle: 'Fast biometric checkout',
                              trailingIcon: Icons.phone_iphone_rounded,
                              isSelected: _selectedPaymentMethod == 1,
                              onTap: () =>
                                  setState(() => _selectedPaymentMethod = 1),
                            ),
                            const Divider(height: 1),
                            _buildCustomRadioTile(
                              title: 'Cash on Delivery',
                              subtitle: 'Pay the courier upon parcel delivery',
                              trailingIcon: Icons.payments_outlined,
                              isSelected: _selectedPaymentMethod == 2,
                              onTap: () =>
                                  setState(() => _selectedPaymentMethod = 2),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // ── 4. Order Summary Card ─────────────────────────────
                      _buildSectionHeader(
                        icon: Icons.receipt_long_outlined,
                        title: 'Order Summary',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            ...cart.items.map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.quantity}x ${item.product.name} (${item.selectedSize})',
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '₹${item.totalPrice.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Subtotal',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                Text(
                                  '₹${cart.subtotal.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                            if (cart.discountAmount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discount (${cart.appliedPromoCode})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.luxuryWine,
                                    ),
                                  ),
                                  Text(
                                    '-₹${cart.discountAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.luxuryWine,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Delivery',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                                Text(
                                  _shippingCost == 0.0
                                      ? 'Free'
                                      : '₹${_shippingCost.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _shippingCost == 0.0
                                        ? const Color(0xFF2E7D32)
                                        : AppColors.mainText,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total to Pay',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '₹${total.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.luxuryWine,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),

            // ── Sticky Bottom Action: Place Order ───────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mainText.withAlpha(12),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _isPlacingOrder
                      ? null
                      : () => _handlePlaceOrder(cart, total),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryWine,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.luxuryWine.withAlpha(80),
                  ),
                  child: _isPlacingOrder
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Confirm Order • ₹${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomRadioTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    String? priceLabel,
    IconData? trailingIcon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.luxuryWine
                      : AppColors.secondaryText,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.luxuryWine,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (priceLabel != null)
              Text(
                priceLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: priceLabel == 'Free'
                      ? const Color(0xFF2E7D32)
                      : AppColors.luxuryWine,
                ),
              ),
            if (trailingIcon != null)
              Icon(trailingIcon, color: AppColors.luxuryWine, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.luxuryWine),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.mainText,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: AppColors.mainText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.secondaryText,
        ),
        prefixIcon: Icon(icon, size: 20, color: AppColors.champagneGold),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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

  Future<void> _handlePlaceOrder(CartController cart, double grandTotal) async {
    if (!_formKey.currentState!.validate()) return;

    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your shopping bag is empty!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final outOfStockItems =
        cart.items.where((i) => !i.product.isInStock).toList();
    if (outOfStockItems.isNotEmpty) {
      final names = outOfStockItems.map((i) => i.product.name).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot place order: "$names" is out of stock.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    try {
      // Realistic payment and order processing delay
      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;

      final auth = context.read<AuthController>();
      final orderController = context.read<OrderController>();
      final paymentString = _selectedPaymentMethod == 0
          ? 'Credit Card (•••• 4242)'
          : _selectedPaymentMethod == 1
          ? 'Apple / Google Pay'
          : 'Cash on Delivery';

      final orderItems = cart.items
          .map(
            (i) => OrderItemModel.fromProduct(
              i.product,
              quantity: i.quantity,
              size: i.selectedSize,
            ),
          )
          .toList();

      final order = await orderController.placeOrder(
        items: orderItems,
        subtotal: cart.subtotal,
        discount: cart.discountAmount,
        shippingFee: _shippingCost,
        total: grandTotal,
        shippingName: _nameController.text.trim(),
        shippingPhone: _phoneController.text.trim(),
        shippingAddress: _addressController.text.trim(),
        shippingCity: _cityController.text.trim(),
        shippingPostalCode: _postalCodeController.text.trim(),
        paymentMethod: paymentString,
        uid: auth.currentUser?.uid,
      );

      // Clear cart only after the order has been saved successfully
      cart.clearCart();

      if (!mounted) return;
      setState(() => _isPlacingOrder = false);

      // Navigate to live Order Tracking screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OrderTrackingView(order: order)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlacingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order processing error: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
