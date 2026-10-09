import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class FloatingPillNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool hasLiveRooms;

  const FloatingPillNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.hasLiveRooms = false,
  });

  @override
  Widget build(BuildContext context) {
    final navBg = AppColors.isDark ? const Color(0xFF161421) : const Color(0xFF191824);
    final activeItemBg = AppColors.isDark ? const Color(0xFF2A263D) : Colors.white;

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: AppColors.isDark ? const Color(0xFF2E2B40) : Colors.transparent,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: AppColors.isDark ? 0.5 : 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildNavItem(
            index: 0,
            icon: Icons.home_rounded,
            label: 'หน้าแรก',
            activeColor: AppColors.purpleDeep,
            activeBg: activeItemBg,
          ),
          const SizedBox(width: 4),
          _buildNavItem(
            index: 1,
            icon: Icons.grid_view_rounded,
            label: 'ห้องสด',
            activeColor: AppColors.blueDeep,
            activeBg: activeItemBg,
            showDot: hasLiveRooms,
          ),
          const SizedBox(width: 4),
          _buildNavItem(
            index: 2,
            icon: Icons.insights_rounded,
            label: 'สถิติ',
            activeColor: AppColors.orangeDeep,
            activeBg: activeItemBg,
          ),
          const SizedBox(width: 4),
          _buildNavItem(
            index: 3,
            icon: Icons.person_rounded,
            label: 'โปรไฟล์',
            activeColor: AppColors.pinkDeep,
            activeBg: activeItemBg,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required Color activeColor,
    required Color activeBg,
    bool showDot = false,
  }) {
    final bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onItemSelected(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? activeColor
                      : Colors.white.withValues(alpha: 0.65),
                ),
                if (showDot && !isSelected)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2EC4B6),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: activeColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
