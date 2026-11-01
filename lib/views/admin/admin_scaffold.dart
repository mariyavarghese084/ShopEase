import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../services/in_app_messaging_service.dart';
import '../../widgets/widgets.dart';

/// Responsive administrative layout scaffold for AÈRA luxury cosmetics & fashion.
///
/// Features:
/// - Desktop (>= 1024px): Persistent, full-featured luxury sidebar (260px) + fluid content.
/// - Tablet (700px - 1023px): Compact icon-only sidebar (74px) with tooltips.
/// - Mobile (< 700px): Safe drawer navigation with top app bar hamburger toggle.
/// - Production aesthetic: Clean sections, active route highlights, zero development tags.
class AdminScaffold extends StatelessWidget {
  final String title;
  final String currentRoute;
  final Widget body;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.currentRoute,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    // Suppress marketing in-app popups while performing administrative tasks
    InAppMessagingService.setMessagesSuppressed(true);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        final isTablet =
            constraints.maxWidth >= 700 && constraints.maxWidth < 1024;
        final isMobile = constraints.maxWidth < 700;

        return Scaffold(
          backgroundColor: AppColors.background,
          drawer: isMobile
              ? Drawer(
                  backgroundColor: AppColors.cardBackground,
                  child: AdminSidebar(
                    currentRoute: currentRoute,
                    isCompact: false,
                    onNavigate: () => Navigator.of(context).pop(),
                  ),
                )
              : null,
          appBar: AdminHeader(title: title, isMobile: isMobile),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop)
                SizedBox(
                  width: 260,
                  child: AdminSidebar(
                    currentRoute: currentRoute,
                    isCompact: false,
                  ),
                )
              else if (isTablet)
                SizedBox(
                  width: 74,
                  child: AdminSidebar(
                    currentRoute: currentRoute,
                    isCompact: true,
                  ),
                ),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

/// Reusable sidebar navigation widget for the AÈRA Admin Panel.
class AdminSidebar extends StatelessWidget {
  final String currentRoute;
  final bool isCompact;
  final VoidCallback? onNavigate;

  const AdminSidebar({
    super.key,
    required this.currentRoute,
    this.isCompact = false,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(right: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          // ── Brand Header ───────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 20,
              vertical: 20,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: isCompact
                ? Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.luxuryWine,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.luxuryWine.withAlpha(50),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            fontFamily: 'Playfair',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.champagneGold,
                          ),
                        ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.luxuryWine,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.luxuryWine.withAlpha(50),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.auto_awesome,
                            color: AppColors.champagneGold,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AÈRA',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.luxuryWine,
                                letterSpacing: 2.0,
                              ),
                            ),
                            Text(
                              'ShopEase Admin',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.champagneGold,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          // ── Navigation Items ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 8 : 12,
                vertical: 16,
              ),
              children: [
                if (!isCompact) _buildSectionLabel('OVERVIEW'),
                _buildNavItem(
                  context,
                  title: 'Dashboard',
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  route: AppRoutes.adminDashboard,
                ),
                const SizedBox(height: 8),

                if (!isCompact) _buildSectionLabel('MANAGEMENT'),
                _buildNavItem(
                  context,
                  title: 'Products',
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  route: AppRoutes.adminProducts,
                ),
                _buildNavItem(
                  context,
                  title: 'Orders',
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  route: AppRoutes.adminOrders,
                ),
                _buildNavItem(
                  context,
                  title: 'Customers',
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                  route: AppRoutes.adminCustomers,
                ),
                _buildNavItem(
                  context,
                  title: 'Notifications',
                  icon: Icons.campaign_outlined,
                  activeIcon: Icons.campaign_rounded,
                  route: AppRoutes.adminNotifications,
                ),
                const SizedBox(height: 8),

                if (!isCompact) _buildSectionLabel('STORE & ACCOUNT'),
                _buildNavItem(
                  context,
                  title: 'Customer Store',
                  icon: Icons.storefront_outlined,
                  activeIcon: Icons.storefront_rounded,
                  route: AppRoutes.customerHome,
                ),
              ],
            ),
          ),

          // ── Bottom Administrative Profile & Sign Out ───────────────────────
          Consumer<AuthController>(
            builder: (context, auth, _) {
              final user = auth.currentUser;
              final profile = auth.customerProfile;
              final name = profile?.fullName.isNotEmpty == true
                  ? profile!.fullName
                  : (user?.displayName ?? 'Admin');

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 8 : 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: isCompact
                    ? IconButton(
                        tooltip: 'Sign Out ($name)',
                        icon: const Icon(
                          Icons.logout_rounded,
                          size: 20,
                          color: AppColors.luxuryWine,
                        ),
                        onPressed: () => _confirmSignOut(context, auth),
                      )
                    : Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.luxuryWineLight,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'A',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.luxuryWine,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.mainText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  user?.email ?? 'admin@shopease.com',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.secondaryText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Sign Out',
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: AppColors.luxuryWine,
                            ),
                            onPressed: () => _confirmSignOut(context, auth),
                          ),
                        ],
                      ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.secondaryText,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required IconData activeIcon,
    required String route,
  }) {
    final isActive = currentRoute == route;

    final content = isCompact
        ? Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.luxuryWine.withAlpha(25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isActive
                  ? Border.all(color: AppColors.luxuryWine.withAlpha(80))
                  : null,
            ),
            child: IconButton(
              tooltip: title,
              icon: Icon(
                isActive ? activeIcon : icon,
                color: isActive
                    ? AppColors.luxuryWine
                    : AppColors.secondaryText,
                size: 20,
              ),
              onPressed: () {
                if (onNavigate != null) onNavigate!();
                if (!isActive) {
                  Navigator.of(context).pushReplacementNamed(route);
                }
              },
            ),
          )
        : Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              dense: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              selected: isActive,
              selectedTileColor: AppColors.luxuryWine.withAlpha(25),
              leading: Icon(
                isActive ? activeIcon : icon,
                color: isActive
                    ? AppColors.luxuryWine
                    : AppColors.secondaryText,
                size: 20,
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? AppColors.luxuryWine : AppColors.mainText,
                ),
              ),
              onTap: () {
                if (onNavigate != null) onNavigate!();
                if (!isActive) {
                  Navigator.of(context).pushReplacementNamed(route);
                }
              },
            ),
          );

    return content;
  }

  void _confirmSignOut(BuildContext context, AuthController auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out from AÈRA Admin?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You will be returned to the store sign-in screen.',
          style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.luxuryWine,
              foregroundColor: AppColors.white,
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

/// Top administrative header bar with title, admin status pill, and actions.
class AdminHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isMobile;

  const AdminHeader({super.key, required this.title, required this.isMobile});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final profile = auth.customerProfile;
    final adminName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : user?.displayName ?? 'Admin';

    return AppBar(
      backgroundColor: AppColors.cardBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: AppColors.mainText),
      leading: isMobile
          ? Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: AppColors.luxuryWine,
                ),
                tooltip: 'Open navigation',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            )
          : null,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.divider),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.mainText,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        // ── Notifications ───────────────────────────────────────────────────
        const NotificationBellButton(
          size: 20,
          color: AppColors.luxuryWine,
        ),
        const SizedBox(width: 4),

        // ── Admin Role Badge ────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.luxuryWine.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.luxuryWine.withAlpha(80)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_rounded,
                size: 14,
                color: AppColors.luxuryWine,
              ),
              SizedBox(width: 4),
              Text(
                'ADMIN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.luxuryWine,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // ── Administrator Name / Email (desktop/wide screen only) ───────────
        if (!isMobile && MediaQuery.of(context).size.width >= 850) ...[
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                adminName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mainText,
                ),
              ),
              Text(
                user?.email ?? '',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],

        // ── Logout Action ───────────────────────────────────────────────────
        IconButton(
          tooltip: 'Sign Out',
          icon: const Icon(
            Icons.logout_rounded,
            size: 20,
            color: AppColors.luxuryWine,
          ),
          onPressed: () => _confirmSignOut(context, auth),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _confirmSignOut(BuildContext context, AuthController auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out from AÈRA Admin?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You will be returned to the store sign-in screen.',
          style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.luxuryWine,
              foregroundColor: AppColors.white,
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.login);
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
