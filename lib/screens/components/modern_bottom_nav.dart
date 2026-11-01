import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';
import '../../theme.dart';

class ModernBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const ModernBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currencyFormat = NumberFormat.currency(symbol: '₱');

    final items = [
      _BottomNavItemData(
        icon: Icons.grid_view_outlined,
        activeIcon: Icons.grid_view_rounded,
        label: 'Products',
      ),
      _BottomNavItemData(
        icon: Icons.shopping_bag_outlined,
        activeIcon: Icons.shopping_bag_rounded,
        label: 'Cart',
        badgeCount: appState.totalCartItemsCount,
        badgeText: appState.totalAmount > 0 ? currencyFormat.format(appState.totalAmount) : null,
      ),
      _BottomNavItemData(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        label: 'History',
        badgeCount: appState.transactions.length,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: AppColors.paletteDark.withValues(alpha: 0.12),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.88),
                      Colors.white.withValues(alpha: 0.70),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.8,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = selectedIndex == index;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onTap(index);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.fastOutSlowIn,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSelected ? 16 : 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected ? AppColors.cyanGradient : null,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      AnimatedScale(
                                        scale: isSelected ? 1.15 : 1.0,
                                        duration: const Duration(milliseconds: 200),
                                        child: Icon(
                                          isSelected ? item.activeIcon : item.icon,
                                          color: isSelected ? Colors.white : AppColors.primaryDarkNavy,
                                          size: 20,
                                        ),
                                      ),
                                      if (item.badgeCount > 0)
                                        Positioned(
                                          right: -8,
                                          top: -6,
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.white : AppColors.danger,
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 4,
                                                )
                                              ],
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 16,
                                              minHeight: 16,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${item.badgeCount}',
                                                style: TextStyle(
                                                  color: isSelected ? AppColors.danger : Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.primaryDarkNavy,
                                        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                        fontSize: 11.5,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;
  final String? badgeText;

  _BottomNavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
    this.badgeText,
  });
}
