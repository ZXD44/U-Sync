import 'package:flutter/material.dart';
import '../models/member_presence.dart';
import '../theme/app_theme.dart';

class SyncStatusBadge extends StatelessWidget {
  final Map<String, MemberPresence> members;
  final String myDeviceId;
  final bool isBuffering;

  const SyncStatusBadge({
    super.key,
    required this.members,
    required this.myDeviceId,
    this.isBuffering = false,
  });

  @override
  Widget build(BuildContext context) {
    // Check partners
    final partnerEntries =
        members.entries.where((e) => e.key != myDeviceId).toList();
    final bool hasPartner = partnerEntries.isNotEmpty;
    final int onlineCount = members.values.where((m) => m.isOnline).length;
    final bool isPartnerOnline =
        hasPartner && partnerEntries.any((e) => e.value.isOnline);

    String statusText;
    if (!hasPartner) {
      statusText = 'รอเพื่อนเข้าห้อง...';
    } else if (partnerEntries.length == 1) {
      final partner = partnerEntries.first.value;
      statusText = partner.isOnline
          ? '${partner.nickname} (ออนไลน์ 🟢)'
          : '${partner.nickname} (ออฟไลน์ 🔴)';
    } else {
      statusText = 'ออนไลน์ $onlineCount คน';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPartnerOnline
                  ? const Color(0xFF2EC4B6)
                  : const Color(0xFFFF5964),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isBuffering) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.purpleDeep,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
