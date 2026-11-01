import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../theme.dart';

class ModernNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badgeCount;

  const ModernNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

class ModernNavRail extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  const ModernNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final navItems = [
      const ModernNavItem(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        label: 'POS Terminal',
      ),
      ModernNavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        label: 'Sales History',
        badgeCount: appState.transactions.length,
      ),
      const ModernNavItem(
        icon: Icons.contactless_outlined,
        activeIcon: Icons.contactless_rounded,
        label: 'RFID Loyalty',
      ),
      ModernNavItem(
        icon: Icons.verified_user_outlined,
        activeIcon: Icons.verified_user_rounded,
        label: 'Pending Approvals',
        badgeCount: appState.pendingApprovals.length,
      ),
    ];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: MediaQuery.of(context).size.width >= 1024 ? 240 : 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.paletteNavy.withValues(alpha: 0.92),
                AppColors.paletteMidnight.withValues(alpha: 0.95),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              right: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
            ),
          ),
          child: Column(
            children: [
              // Branding Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.cyanGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: AppDesign.glowingShadow,
                      ),
                      child: const Icon(
                        Icons.water_drop,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'AQUASYNC',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.success,
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'POS Terminal',
                                style: TextStyle(
                                  color: AppColors.skyBlue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
              const SizedBox(height: 16),

              // Navigation Links
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: navItems.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isSelected = selectedIndex == index;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.fastOutSlowIn,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  AppColors.paletteMedium.withValues(alpha: 0.30),
                                  AppColors.paletteMedium.withValues(alpha: 0.10),
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(color: AppColors.paletteLight.withValues(alpha: 0.5), width: 1.5)
                            : Border.all(color: Colors.transparent, width: 1.5),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Stack(
                        children: [
                          if (isSelected)
                            Positioned(
                              left: 0,
                              top: 8,
                              bottom: 8,
                              child: Container(
                                width: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.paletteLight,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.paletteLight,
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              onDestinationSelected(index);
                            },
                            leading: AnimatedScale(
                              scale: isSelected ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                color: isSelected ? AppColors.paletteLight : AppColors.lightGrayText,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected ? AppColors.white : AppColors.lightGrayText,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                                fontSize: 13,
                                letterSpacing: 0.3,
                              ),
                            ),
                            trailing: item.badgeCount > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.paletteMedium : AppColors.paletteMedium.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${item.badgeCount}',
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),

              // Cashier Profile & Quick Logout Card
              Padding(
                padding: const EdgeInsets.all(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          gradient: AppColors.cyanGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.person, color: AppColors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              appState.cashierName ?? 'Staff',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Cashier Active',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: AppColors.lightGrayText, size: 20),
                        tooltip: 'Logout',
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          onLogout();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
