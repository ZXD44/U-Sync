import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../theme/app_theme.dart';
import '../services/device_service.dart';
import '../services/stats_service.dart';
import '../services/favorites_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = DeviceService.getNickname();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Comprehensive Profile Edit Modal (Edit Both Avatar & Nickname)
  void _showEditProfileModal() {
    int tempAvatarIndex = StatsService.avatarIndex;
    final nameFieldController =
        TextEditingController(text: DeviceService.getNickname());

    showDialog(
      context: context,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  title: const Text(
                    'แก้ไขข้อมูลโปรไฟล์',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selected Avatar Preview
                        Center(
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.purplePastel,
                            child: Text(
                              StatsService.availableAvatars[
                                  tempAvatarIndex %
                                      StatsService.availableAvatars.length],
                              style: const TextStyle(fontSize: 34),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Section 1: Choose Avatar
                        const Text(
                          'เลือกรูปโปรไฟล์อวตาร:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: StatsService.availableAvatars.length,
                          itemBuilder: (context, index) {
                            final emoji = StatsService.availableAvatars[index];
                            final isSelected = tempAvatarIndex == index;

                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  tempAvatarIndex = index;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.purplePastel
                                      : AppColors.background,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: AppColors.purpleDeep, width: 2)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(emoji,
                                      style: const TextStyle(fontSize: 22)),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Section 2: Edit Nickname
                        const Text(
                          'ชื่อเล่นของคุณ:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: nameFieldController,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'กรอกชื่อเล่นของคุณ',
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ยกเลิก',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkNav,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final newName = nameFieldController.text.trim();
                        if (newName.isNotEmpty) {
                          DeviceService.setNickname(newName);
                        }
                        StatsService.setAvatarIndex(tempAvatarIndex);
                        Navigator.pop(ctx);
                        setState(() {});
                        Fluttertoast.showToast(msg: 'บันทึกโปรไฟล์เรียบร้อย');
                      },
                      child: const Text('บันทึก',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showDeviceInfoModal() {
    final deviceId = DeviceService.getDeviceId();
    showDialog(
      context: context,
      builder: (ctx) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'ข้อมูลอุปกรณ์ของคุณ',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'รหัสประจำเครื่อง (Device UUID):',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            deviceId,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded,
                              size: 18, color: AppColors.purpleDeep),
                          tooltip: 'คัดลอกรหัส',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: deviceId));
                            Fluttertoast.showToast(
                                msg: 'คัดลอกรหัสประจำเครื่องแล้ว');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'รหัสนี้ใช้ระบุตัวตนในห้องเพื่อป้องกันคำสั่งเล่นวิดีโอซ้ำซ้อน และใช้จัดการสถานะออนไลน์ของคุณ',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted, height: 1.4),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.darkNav,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('เข้าใจแล้ว',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSystemInfoModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isCheckingInModal = false;
        String updateStatusMessage = '';

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                  contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.purplePastel.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.purpleDeep,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ข้อมูลระบบ & อัปเดต',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'ยูซิงค์ • GitHub Connected',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Version & GitHub Badge Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEDE7F6), Color(0xFFF3E5F5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.purplePastel.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified_rounded,
                                      size: 16, color: AppColors.purpleDeep),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'เวอร์ชันปัจจุบัน:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.darkNav,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'v${UpdateService.currentVersion}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(Icons.code_rounded,
                                      size: 14, color: AppColors.textSecondary),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'GitHub: ZXD44/U-Sync',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // System Architecture Details
                        _buildInfoRow('ระบบซิงค์เวลา', 'Firebase Realtime (Offset Sync)'),
                        _buildInfoRow('เครื่องเล่น', 'YouTube CDN Player (60fps)'),
                        _buildInfoRow('การพักหน้าจอ', 'Wakelock Plus (เปิดทำงาน)'),
                        _buildInfoRow('ระบบกู้คืนหัวห้อง', 'Auto Host Migration (Active)'),

                        const SizedBox(height: 8),

                        // Sound Notification Setting
                        StatefulBuilder(
                          builder: (context, setSoundState) {
                            return SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'เสียงเตือนแชท & Reaction',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: const Text(
                                'มีเสียงเมื่อเพื่อนส่งข้อความหรือส่งสติกเกอร์',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              value: FavoritesService.soundEnabled,
                              activeThumbColor: AppColors.purpleDeep,
                              onChanged: (val) {
                                setSoundState(() {
                                  FavoritesService.setSoundEnabled(val);
                                });
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // GitHub Check Update Action Button inside Modal
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkNav,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isCheckingInModal
                              ? null
                              : () async {
                                  setModalState(() {
                                    isCheckingInModal = true;
                                    updateStatusMessage = 'กำลังเชื่อมต่อ GitHub API...';
                                  });
                                  HapticFeedback.lightImpact();

                                  final release = await UpdateService.checkForUpdate();
                                  
                                  if (ctx.mounted) {
                                    setModalState(() {
                                      isCheckingInModal = false;
                                    });

                                    if (release != null && release.hasUpdate) {
                                      Navigator.pop(ctx);
                                      if (mounted) {
                                        UpdateDialog.show(context, release);
                                      }
                                    } else {
                                      setModalState(() {
                                        updateStatusMessage =
                                            '✓ คุณกำลังใช้งานเวอร์ชันล่าสุดแล้ว (v${UpdateService.currentVersion})';
                                      });
                                      Fluttertoast.showToast(
                                        msg: 'คุณกำลังใช้งานเวอร์ชันล่าสุดแล้ว',
                                        backgroundColor: AppColors.darkNav,
                                      );
                                    }
                                  }
                                },
                          icon: isCheckingInModal
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, size: 18),
                          label: Text(
                            isCheckingInModal
                                ? 'กำลังตรวจสอบ...'
                                : 'ตรวจสอบอัปเดตจาก GitHub',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        if (updateStatusMessage.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            updateStatusMessage,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.purpleDeep,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'ปิดหน้าต่าง',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nickname = DeviceService.getNickname();
    final avatarEmoji = StatsService.avatarEmoji;
    final totalVideos = StatsService.totalVideos;
    final totalRooms = StatsService.totalRooms;
    final totalReactions = StatsService.totalReactions;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'โปรไฟล์และการตั้งค่า',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // User Avatar Card with Edit Options
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.purplePastel,
                    child: Text(
                      avatarEmoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'โปรไฟล์สมาชิก U-Sync',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Real Stat Badges Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.greenPastel,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ดูคลิปรวม',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF2D6A4F),
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalVideos คลิป',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B4332)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bluePastel,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ห้องที่เข้า',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF1D3557),
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalRooms ห้อง',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D3557)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.orangePastel,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reactions',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF7F4F24),
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$totalReactions ครั้ง',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7F4F24)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Simplified & Compact Settings Section (3 essential tiles only!)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingTile(
                    icon: Icons.badge_outlined,
                    title: 'แก้ไขข้อมูลโปรไฟล์',
                    subtitle: 'ชื่อเล่น: $nickname • อวตาร: $avatarEmoji',
                    onTap: _showEditProfileModal,
                  ),
                  const Divider(
                      height: 1,
                      indent: 60,
                      endIndent: 20,
                      color: Color(0xFFF0EDF6)),
                  _buildSettingTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'ข้อมูลอุปกรณ์ & รหัสเครื่อง',
                    subtitle: 'แตะเพื่อดูรายละเอียดและคัดลอกรหัส',
                    onTap: _showDeviceInfoModal,
                  ),
                  const Divider(
                      height: 1,
                      indent: 60,
                      endIndent: 20,
                      color: Color(0xFFF0EDF6)),
                  _buildSettingTile(
                    icon: Icons.hub_outlined,
                    title: 'ข้อมูลระบบ & อัปเดตเวอร์ชัน',
                    subtitle: 'ยูซิงค์ v${UpdateService.currentVersion} • ซิงค์กับ GitHub (ZXD44/U-Sync)',
                    onTap: _showSystemInfoModal,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Creator Credit: Clean Thai text without Heart
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'พัฒนาโดย ZirconX',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
