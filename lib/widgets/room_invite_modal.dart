import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';

class RoomInviteModal extends StatelessWidget {
  final String roomId;
  final String roomName;
  final bool isLocked;
  final String password;

  const RoomInviteModal({
    super.key,
    required this.roomId,
    required this.roomName,
    this.isLocked = false,
    this.password = '',
  });

  static void show(
    BuildContext context, {
    required String roomId,
    required String roomName,
    bool isLocked = false,
    String password = '',
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoomInviteModal(
        roomId: roomId,
        roomName: roomName,
        isLocked: isLocked,
        password: password,
      ),
    );
  }

  String get _inviteLink => 'https://usync.app/room/$roomId';

  @override
  Widget build(BuildContext context) {
    final displayName = roomName.isNotEmpty ? roomName : 'ห้อง $roomId';
    final isDark = AppColors.isDark;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isDark ? const Color(0xFF2B273D) : Colors.transparent,
          width: 1.0,
        ),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.purplePastel.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.purpleDeep,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'สแกน QR Code หรือแชร์ลิงก์เพื่อเข้าห้องทันที',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // QR Code Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13121E) : AppColors.background,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2B273D)
                    : AppColors.purplePastel.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.purpleDeep.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _inviteLink,
                    version: QrVersions.auto,
                    size: 180.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF7B4DFF),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF191824),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.meeting_room_rounded,
                      size: 16,
                      color: AppColors.purpleDeep,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'รหัสห้อง: $roomId',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isLocked) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.pinkPastel.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded,
                                size: 11, color: AppColors.pinkDeep),
                            if (password.isNotEmpty) ...[
                              const SizedBox(width: 3),
                              Text(
                                'PIN: $password',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.pinkDeep,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              // Copy Room ID Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: roomId));
                    Fluttertoast.showToast(
                      msg: 'คัดลอกรหัสห้อง $roomId แล้ว!',
                      backgroundColor: AppColors.darkNav,
                      textColor: Colors.white,
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    'คัดลอกรหัสห้อง',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.purpleDeep,
                    side: BorderSide(
                        color: AppColors.purpleDeep, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Copy Invite Link Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final shareText = isLocked && password.isNotEmpty
                        ? '🎬 มาร่วมดูวิดีโอกับฉันใน U-Sync!\n📍 รหัสห้อง: $roomId\n🔑 PIN: $password\n🔗 ลิงก์: $_inviteLink'
                        : '🎬 มาร่วมดูวิดีโอกับฉันใน U-Sync!\n📍 รหัสห้อง: $roomId\n🔗 ลิงก์: $_inviteLink';

                    Clipboard.setData(ClipboardData(text: shareText));
                    Fluttertoast.showToast(
                      msg: 'คัดลอกลิงก์เชิญพร้อมรายละเอียดแล้ว!',
                      backgroundColor: AppColors.purpleDeep,
                      textColor: Colors.white,
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'แชร์ลิงก์เชิญ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purpleDeep,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
