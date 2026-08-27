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
  bool _isCheckingUpdate = false;

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

  void _checkForUpdatesManually() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);
    HapticFeedback.lightImpact();
    Fluttertoast.showToast(msg: 'กำลังตรวจสอบเวอร์ชันล่าสุดจาก GitHub...');

    final release = await UpdateService.checkForUpdate();
    if (mounted) {
      setState(() => _isCheckingUpdate = false);
      if (release != null && release.hasUpdate) {
        UpdateDialog.show(context, release);
      } else {
        Fluttertoast.showToast(
          msg: 'คุณกำลังใช้งานเวอร์ชันล่าสุดแล้ว (v${UpdateService.currentVersion})',
          backgroundColor: AppColors.darkNav,
        );
      }
    }
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
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'ข้อมูลระบบ & เวอร์ชัน',
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
                  _buildInfoRow('แอปพลิเคชัน', 'ยูซิงค์ (U-Sync)'),
                  _buildInfoRow('เวอร์ชัน', '1.2.0 (Neo-Pastel Edition)'),
                  _buildInfoRow('ระบบซิงค์เวลา', 'Firebase Realtime Database'),
                  _buildInfoRow('ระบบล็อกหน้าจอ', 'Wakelock Plus (เปิดใช้งาน)'),
                  _buildInfoRow('การคำนวณเวลา', 'Latency Compensation Math'),
                  const SizedBox(height: 8),
                  StatefulBuilder(
                    builder: (context, setSoundState) {
                      return SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'เสียงเตือนแชท & Reaction',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: const Text(
                          'เปิดเสียงเมื่อเพื่อนส่งข้อความหรือส่งอิโมจิ',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        value: FavoritesService.soundEnabled,
                        activeThumbColor: AppColors.darkNav,
                        onChanged: (val) {
                          setSoundState(() {
                            FavoritesService.setSoundEnabled(val);
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ระบบจะปรับเวลาวิดีโอให้ตรงกันโดยอัตโนมัติ และลบห้องทิ้งทันทีเมื่อไม่มีคนใช้งาน',
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
                  child: const Text('ปิด',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
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
                  GestureDetector(
                    onTap: _showEditProfileModal,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: AppColors.purplePastel,
                          child: Text(
                            avatarEmoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.darkNav,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ],
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
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'แตะเพื่อแก้ไขชื่อและเปลี่ยนรูปอวตาร',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.purpleDeep, size: 20),
                    tooltip: 'แก้ไขโปรไฟล์',
                    onPressed: _showEditProfileModal,
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
                    icon: Icons.system_update_rounded,
                    title: 'ตรวจสอบการอัปเดตเวอร์ชันใหม่',
                    subtitle: 'เวอร์ชันปัจจุบัน v${UpdateService.currentVersion} • ตรวจสอบจาก GitHub',
                    onTap: _checkForUpdatesManually,
                  ),
                  const Divider(
                      height: 1,
                      indent: 60,
                      endIndent: 20,
                      color: Color(0xFFF0EDF6)),
                  _buildSettingTile(
                    icon: Icons.info_outline_rounded,
                    title: 'การทำงานของระบบ & ข้อมูลแอป',
                    subtitle: 'ยูซิงค์ v${UpdateService.currentVersion} • ระบบซิงค์เวลาและหน้าจอ',
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
