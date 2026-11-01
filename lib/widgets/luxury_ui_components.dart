import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// Button styling variants for AÈRA luxury administrative & customer actions.
enum LuxuryButtonVariant {
  /// Deep Wine Red filled CTA with subtle Champagne Gold accent border.
  primary,

  /// Elegant outlined button with soft wine-tinted hover and crisp border.
  outline,

  /// Refined secondary button with subtle background and icon accent.
  secondary,

  /// Subtle gold-accented action button.
  gold,
}

/// A compact, responsive, luxury action button featuring:
/// - Smooth Web & Desktop mouse-hover elevation & background adjustment
/// - Subtle press-down scale feedback (0.97x)
/// - Integrated icon rotation or loading spinner during async operations
/// - Strict finite constraints to prevent any layout/infinite-width crashes
class LuxuryActionButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final LuxuryButtonVariant variant;
  final double fontSize;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? minWidth;
  final double? maxWidth;
  final String? tooltip;

  const LuxuryActionButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.variant = LuxuryButtonVariant.primary,
    this.fontSize = 13.0,
    this.iconSize = 16.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.borderRadius = 10.0,
    this.minWidth,
    this.maxWidth,
    this.tooltip,
  });

  /// Factory for the Admin Products "Add Product" button.
  factory LuxuryActionButton.addProduct({
    Key? key,
    required VoidCallback? onPressed,
    String label = 'Add Product',
    bool isWide = true,
  }) {
    return LuxuryActionButton(
      key: key,
      label: label,
      icon: Icons.add_rounded,
      onPressed: onPressed,
      variant: LuxuryButtonVariant.primary,
      fontSize: 13.5,
      iconSize: 18.0,
      borderRadius: 11.0,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 18 : 14, vertical: 11),
      tooltip: 'Add new luxury product to catalog',
    );
  }

  /// Factory for the Admin Orders / Customers "Refresh" button.
  factory LuxuryActionButton.refresh({
    Key? key,
    required VoidCallback? onPressed,
    bool isLoading = false,
    String label = 'Refresh',
    double? maxWidth,
  }) {
    return LuxuryActionButton(
      key: key,
      label: label,
      icon: Icons.refresh_rounded,
      onPressed: onPressed,
      isLoading: isLoading,
      variant: LuxuryButtonVariant.outline,
      fontSize: 12.5,
      iconSize: 15.0,
      borderRadius: 10.0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      maxWidth: maxWidth,
      tooltip: 'Refresh data from Firestore',
    );
  }

  /// Factory for the Admin Orders "Inspect" button.
  factory LuxuryActionButton.inspect({
    Key? key,
    required VoidCallback? onPressed,
    String label = 'Inspect',
    double? maxWidth,
  }) {
    return LuxuryActionButton(
      key: key,
      label: label,
      icon: Icons.visibility_outlined,
      onPressed: onPressed,
      variant: LuxuryButtonVariant.primary,
      fontSize: 12.0,
      iconSize: 14.0,
      borderRadius: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      maxWidth: maxWidth,
      tooltip: 'Inspect complete order snapshot & audit history',
    );
  }

  /// Factory for the Admin Customers "Details" button.
  factory LuxuryActionButton.customerDetails({
    Key? key,
    required VoidCallback? onPressed,
    String label = 'Details',
    double? maxWidth,
  }) {
    return LuxuryActionButton(
      key: key,
      label: label,
      icon: Icons.person_outline_rounded,
      onPressed: onPressed,
      variant: LuxuryButtonVariant.outline,
      fontSize: 12.0,
      iconSize: 14.0,
      borderRadius: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      maxWidth: maxWidth,
      tooltip: 'View customer profile & purchase history',
    );
  }

  @override
  State<LuxuryActionButton> createState() => _LuxuryActionButtonState();
}

class _LuxuryActionButtonState extends State<LuxuryActionButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isLoading) {
      _spinController.repeat();
    }
  }

  @override
  void didUpdateWidget(LuxuryActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _spinController.repeat();
      } else {
        _spinController.stop();
        _spinController.reset();
      }
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Color _backgroundColor() {
    switch (widget.variant) {
      case LuxuryButtonVariant.primary:
        return _isHovered
            ? AppColors.luxuryWine.withAlpha(240)
            : AppColors.luxuryWine;
      case LuxuryButtonVariant.outline:
        return _isHovered
            ? AppColors.luxuryWine.withAlpha(18)
            : Colors.transparent;
      case LuxuryButtonVariant.secondary:
        return _isHovered
            ? AppColors.surfaceVariant
            : AppColors.cardBackground;
      case LuxuryButtonVariant.gold:
        return _isHovered
            ? AppColors.champagneGold.withAlpha(235)
            : AppColors.champagneGold;
    }
  }

  Color _foregroundColor() {
    switch (widget.variant) {
      case LuxuryButtonVariant.primary:
      case LuxuryButtonVariant.gold:
        return AppColors.white;
      case LuxuryButtonVariant.outline:
      case LuxuryButtonVariant.secondary:
        return AppColors.luxuryWine;
    }
  }

  Border _border() {
    switch (widget.variant) {
      case LuxuryButtonVariant.primary:
        return Border.all(
          color: _isHovered
              ? AppColors.champagneGold
              : AppColors.champagneGold.withAlpha(80),
          width: 1.0,
        );
      case LuxuryButtonVariant.outline:
        return Border.all(
          color: _isHovered
              ? AppColors.luxuryWine
              : AppColors.luxuryWine.withAlpha(160),
          width: 1.2,
        );
      case LuxuryButtonVariant.secondary:
        return Border.all(
          color: _isHovered ? AppColors.luxuryWine : AppColors.divider,
          width: 1.0,
        );
      case LuxuryButtonVariant.gold:
        return Border.all(
          color: AppColors.champagneLight,
          width: 1.0,
        );
    }
  }

  List<BoxShadow> _boxShadow() {
    if (widget.variant == LuxuryButtonVariant.outline) {
      if (_isHovered) {
        return [
          BoxShadow(
            color: AppColors.luxuryWine.withAlpha(16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ];
      }
      return const [];
    }

    if (_isHovered) {
      return [
        BoxShadow(
          color: AppColors.luxuryWine.withAlpha(60),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.champagneGold.withAlpha(30),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
    }
    return [
      BoxShadow(
        color: AppColors.black.withAlpha(25),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.onPressed != null && !widget.isLoading;

    final content = AnimatedScale(
      scale: _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _backgroundColor(),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: _border(),
          boxShadow: _boxShadow(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.isLoading)
              RotationTransition(
                turns: _spinController,
                child: Icon(
                  widget.icon ?? Icons.refresh_rounded,
                  size: widget.iconSize,
                  color: _foregroundColor(),
                ),
              )
            else if (widget.icon != null)
              Icon(
                widget.icon,
                size: widget.iconSize,
                color: _foregroundColor(),
              ),
            if (widget.icon != null) const SizedBox(width: 7),
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.fontSize,
                  fontWeight: FontWeight.w600,
                  color: _foregroundColor(),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Widget interactiveWidget = MouseRegion(
      cursor: isInteractive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (isInteractive) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (isInteractive) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (isInteractive) setState(() => _isPressed = false);
        },
        onTap: isInteractive ? widget.onPressed : null,
        child: content,
      ),
    );

    if (widget.tooltip != null) {
      interactiveWidget = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: interactiveWidget,
      );
    }

    if (widget.minWidth != null || widget.maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minWidth ?? 0.0,
          maxWidth: widget.maxWidth ?? double.infinity,
        ),
        child: interactiveWidget,
      );
    }

    return interactiveWidget;
  }
}

/// Staggered Entrance Animation for cards, rows, and dashboard widgets.
/// Gracefully fades and translates items upward over 250–320ms.
class StaggeredSlideFade extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration baseDuration;
  final double verticalOffset;

  const StaggeredSlideFade({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDuration = const Duration(milliseconds: 280),
    this.verticalOffset = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    // Subtle staggered delay capped at 250ms max to prevent sluggish feeling
    final delay = Duration(milliseconds: (index * 40).clamp(0, 240));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: baseDuration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, verticalOffset * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Smooth counter rolling animation for dashboard statistics and KPI metrics.
class LuxuryAnimatedCounter extends StatelessWidget {
  final num value;
  final String? prefix;
  final String? suffix;
  final TextStyle? style;
  final int decimalPlaces;

  const LuxuryAnimatedCounter({
    super.key,
    required this.value,
    this.prefix,
    this.suffix,
    this.style,
    this.decimalPlaces = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value.toDouble()),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        final formatted = decimalPlaces > 0
            ? val.toStringAsFixed(decimalPlaces)
            : val.round().toString();
        return Text(
          '${prefix ?? ""}$formatted${suffix ?? ""}',
          style: style,
        );
      },
    );
  }
}

/// An interactive card that slightly lifts and illuminates its border on hover.
class HoverElevatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color backgroundColor;

  const HoverElevatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16.0,
    this.backgroundColor = AppColors.cardBackground,
  });

  @override
  State<HoverElevatedCard> createState() => _HoverElevatedCardState();
}

class _HoverElevatedCardState extends State<HoverElevatedCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: widget.padding,
          transform: Matrix4.translationValues(0, _isHovered ? -2.5 : 0, 0),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _isHovered
                  ? AppColors.champagneGold.withAlpha(180)
                  : AppColors.divider,
              width: _isHovered ? 1.2 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? AppColors.luxuryWine.withAlpha(22)
                    : AppColors.black.withAlpha(6),
                blurRadius: _isHovered ? 14 : 6,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
