import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EnhancedStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String change;
  final bool isPositive;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;

  const EnhancedStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.change,
    this.isPositive = true,
    this.onTap,
    this.trailing,
    this.subtitle,
  });

  @override
  State<EnhancedStatCard> createState() => _EnhancedStatCardState();
}

class _EnhancedStatCardState extends State<EnhancedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  // late Animation<double> _fadeAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    //   CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    // );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Material(
              elevation: 0,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.borderColor,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with icon and change indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              widget.icon,
                              color: widget.color,
                              size: 20,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  widget.isPositive ? Colors.green : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.isPositive
                                      ? Icons.trending_up
                                      : Icons.trending_down,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.change,
                                  style: AppTypography.changeIndicator.copyWith(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // Value
                      Text(
                        widget.value,
                        style: AppTypography.cardValue.copyWith(
                          color: widget.color,
                          fontSize: 22,
                        ),
                      ),

                      const SizedBox(height: 2),

                      // Title
                      Text(
                        widget.title,
                        style: AppTypography.cardSubtitle.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),

                      // Subtitle if provided
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          style: AppTypography.cardSubtitle.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],

                      // Trailing widget if provided
                      if (widget.trailing != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        widget.trailing!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Specialized card for sales statistics
class SalesStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final VoidCallback? onTap;

  const SalesStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.change,
    this.isPositive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedStatCard(
      title: title,
      value: value,
      icon: Icons.trending_up,
      color: AppColors.successColor,
      change: change,
      isPositive: isPositive,
      onTap: onTap,
    );
  }
}

// Specialized card for inventory statistics
class InventoryStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final VoidCallback? onTap;

  const InventoryStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.change,
    this.isPositive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedStatCard(
      title: title,
      value: value,
      icon: Icons.inventory,
      color: AppColors.warningColor,
      change: change,
      isPositive: isPositive,
      onTap: onTap,
    );
  }
}

// Specialized card for customer statistics
class CustomerStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final VoidCallback? onTap;

  const CustomerStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.change,
    this.isPositive = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedStatCard(
      title: title,
      value: value,
      icon: Icons.people,
      color: AppColors.infoColor,
      change: change,
      isPositive: isPositive,
      onTap: onTap,
    );
  }
}
