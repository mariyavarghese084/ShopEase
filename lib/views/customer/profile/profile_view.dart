import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/order_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../models/customer_model.dart';
import '../orders/order_tracking_view.dart';

/// Customer profile destination reading real Firestore customer profile data.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  void _loadProfile() {
    final authController = context.read<AuthController>();
    final uid =
        authController.customerProfile?.uid ?? authController.currentUser?.uid;
    if (uid != null) {
      context.read<ProfileController>().loadProfile(uid);
      context.read<OrderController>().loadUserOrders(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, auth, _) {
        final uid = auth.customerProfile?.uid ?? auth.currentUser?.uid;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.cardBackground,
            elevation: 0,
            title: const Text(
              'My Profile',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.mainText,
              ),
            ),
            actions: [
              if (uid != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.luxuryWine),
                  tooltip: 'Refresh Profile',
                  onPressed: _loadProfile,
                ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, color: AppColors.divider),
            ),
          ),
          body: uid == null
              ? _buildSignedOutState(context)
              : _buildProfileContent(context, uid),
        );
      },
    );
  }

  Widget _buildSignedOutState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.luxuryWine.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 48,
                color: AppColors.luxuryWine,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Sign In to Your AÈRA Account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Sign in to view your luxury orders, manage shipping addresses, and customize your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.login);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.luxuryWine,
                foregroundColor: AppColors.white,
                minimumSize: const Size(220, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Sign In / Register',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, String uid) {
    return Consumer3<ProfileController, OrderController, AuthController>(
      builder: (context, profileController, orderController, authController, _) {
        final profile =
            profileController.profile ?? authController.customerProfile;

        if (profileController.isLoading && profile == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.luxuryWine),
          );
        }

        if (profile == null && profileController.errorMessage != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Could Not Load Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    profileController.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: () => profileController.loadProfile(uid),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.luxuryWine,
                      foregroundColor: AppColors.white,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (profile == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_off_outlined,
                    color: AppColors.champagneGold,
                    size: 48,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Profile Document Missing',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'No Firestore record exists at customers/{uid} for this authenticated account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () => profileController.loadProfile(uid),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reload Profile'),
                  ),
                ],
              ),
            ),
          );
        }

        final totalOrders = orderController.orders.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  // ── 1. Avatar & Hero Card ──────────────────────────────────
                  _buildAvatarCard(context, profile, profileController),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 2. Metric Overview Strip ───────────────────────────────
                  _buildMetricsStrip(context, profile, totalOrders),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 3. Admin Switcher (if admin) ───────────────────────────
                  if (context.watch<AuthController>().isAdmin ||
                      profile.role.toLowerCase() == 'admin') ...[
                    _buildAdminBanner(context),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // ── 4. Contact & Delivery Information ──────────────────────
                  _buildContactCard(context, profile, profileController),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 5. Orders & History Action ─────────────────────────────
                  _buildOrderHistoryTile(context, totalOrders),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 6. Account Metadata Card ───────────────────────────────
                  _buildAccountInfoCard(profile),
                  const SizedBox(height: AppSpacing.xl),

                  // ── 7. Sign Out Button ─────────────────────────────────────
                  _buildSignOutButton(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarCard(
    BuildContext context,
    CustomerModel profile,
    ProfileController controller,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.luxuryWine.withAlpha(12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: AppColors.luxuryWine.withAlpha(20),
                backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                    ? NetworkImage(profile.photoUrl!)
                    : null,
                child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                    ? Text(
                        profile.fullName.isNotEmpty
                            ? profile.fullName[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.luxuryWine,
                        ),
                      )
                    : null,
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.champagneGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.white,
                  size: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            profile.fullName.isNotEmpty ? profile.fullName : 'Valued Customer',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.mainText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            profile.email,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.luxuryWine.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  profile.role.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.luxuryWine,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _openEditProfileDialog(context, profile, controller),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.luxuryWine,
                  side: const BorderSide(color: AppColors.luxuryWine),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit Profile', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsStrip(
    BuildContext context,
    CustomerModel profile,
    int totalOrders,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: 'Total Orders',
            value: '$totalOrders',
            icon: Icons.receipt_long_rounded,
            color: AppColors.luxuryWine,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrderTrackingView()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            label: 'Member Status',
            value: profile.isAdmin ? 'Admin' : 'VIP Member',
            icon: Icons.workspace_premium_rounded,
            color: AppColors.champagneGold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricTile(
            label: 'Security',
            value: 'Verified',
            icon: Icons.shield_rounded,
            color: const Color(0xFF2E7D32),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
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
    );
  }

  Widget _buildContactCard(
    BuildContext context,
    CustomerModel profile,
    ProfileController controller,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Contact & Delivery Address',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainText,
                  ),
                ),
                TextButton(
                  onPressed: () => _openEditProfileDialog(context, profile, controller),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.luxuryWine,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text('Update', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.phone_outlined, color: AppColors.luxuryWine, size: 20),
            title: const Text('Phone Number', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
            subtitle: Text(
              profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty
                  ? profile.phoneNumber!
                  : 'Add contact phone number',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty
                    ? AppColors.mainText
                    : AppColors.secondaryText,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.location_on_outlined, color: AppColors.luxuryWine, size: 20),
            title: const Text('Shipping & Delivery Address', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
            subtitle: Text(
              profile.address != null && profile.address!.isNotEmpty
                  ? profile.address!
                  : 'Add luxury delivery address',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: profile.address != null && profile.address!.isNotEmpty
                    ? AppColors.mainText
                    : AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryTile(BuildContext context, int totalOrders) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.luxuryWine.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.local_shipping_outlined, color: AppColors.luxuryWine, size: 22),
        ),
        title: const Text(
          'Orders & Tracking',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          totalOrders > 0
              ? 'You have $totalOrders order(s) registered in your account'
              : 'Track active deliveries and past cosmetic purchases',
          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.secondaryText),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const OrderTrackingView(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountInfoCard(CustomerModel profile) {
    final memberSince = '${profile.createdAt.day}/${profile.createdAt.month}/${profile.createdAt.year}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.badge_outlined, color: AppColors.secondaryText, size: 20),
            title: const Text('Customer Identification (UID)', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
            subtitle: Text(
              profile.uid,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.mainText),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined, color: AppColors.secondaryText, size: 20),
            title: const Text('Member Since', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
            subtitle: Text(
              memberSince,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.mainText),
            ),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.lock_outline_rounded, color: AppColors.secondaryText, size: 20),
            title: Text('Account Security', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
            subtitle: Text(
              'Protected with Cloud Firestore Role-Based Access Control',
              style: TextStyle(fontSize: 12, color: AppColors.mainText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.luxuryWine,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.luxuryWine.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: const Icon(
          Icons.admin_panel_settings_rounded,
          color: AppColors.champagneGold,
        ),
        title: const Text(
          'AÈRA Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
        subtitle: const Text(
          'Access management dashboard, product catalog, and orders',
          style: TextStyle(
            color: AppColors.softRose,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: AppColors.champagneGold,
        ),
        onTap: () {
          Navigator.of(context).pushReplacementNamed(
            AppRoutes.adminDashboard,
          );
        },
      ),
    );
  }

  Widget _buildSignOutButton(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error, width: 1.5),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out of your AÈRA account?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          await context.read<AuthController>().signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.welcome,
              (route) => false,
            );
          }
        }
      },
      icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
      label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _openEditProfileDialog(
    BuildContext context,
    CustomerModel profile,
    ProfileController controller,
  ) {
    final nameController = TextEditingController(text: profile.fullName);
    final phoneController = TextEditingController(text: profile.phoneNumber ?? '');
    final addressController = TextEditingController(text: profile.address ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.edit_rounded, color: AppColors.luxuryWine, size: 22),
                  SizedBox(width: 8),
                  Text('Edit Customer Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name *',
                            prefixIcon: const Icon(Icons.person_outline, color: AppColors.luxuryWine),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Full name cannot be empty';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.luxuryWine),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Delivery Address',
                            prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.luxuryWine),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: controller.isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final updated = profile.copyWith(
                            fullName: nameController.text.trim(),
                            phoneNumber: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                            address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                            updatedAt: DateTime.now(),
                          );

                          final success = await controller.updateProfile(updated);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Profile updated successfully.' : 'Failed to update profile.'),
                                backgroundColor: success ? AppColors.luxuryWine : AppColors.error,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryWine,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: controller.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
