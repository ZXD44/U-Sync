import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../theme/app_theme.dart';
import '../services/stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final totalVideos = StatsService.totalVideos;
    final totalRooms = StatsService.totalRooms;
    final totalReactions = StatsService.totalReactions;
    final totalMessages = StatsService.totalMessages;
    final history = StatsService.history;
    final weeklyHeights = StatsService.getWeeklyNormalizedHeights();
    final todayWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'สถิติการใช้งานจริง',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Big Summary Card (Purple Pastel)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.purplePastel,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'เวลาดูรวมตามจริง (Real-time)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.purpleDeep,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.auto_graph_rounded,
                          color: AppColors.purpleDeep),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    StatsService.formattedWatchTime,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'บันทึกเวลาจริงจากการดูวิดีโอ YouTube ร่วมกับเพื่อน',
                    style: TextStyle(fontSize: 12, color: Color(0xFF5A4D78)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. 4 Bento Metric Tiles Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    color: AppColors.orangePastel,
                    title: 'คลิปที่ดูแล้ว',
                    value: '$totalVideos คลิป',
                    icon: Icons.movie_outlined,
                    iconColor: AppColors.orangeDeep,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    color: AppColors.bluePastel,
                    title: 'ห้องที่เข้าร่วม',
                    value: '$totalRooms ห้อง',
                    icon: Icons.meeting_room_outlined,
                    iconColor: AppColors.blueDeep,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    color: AppColors.pinkPastel,
                    title: 'Reactions ส่งแล้ว',
                    value: '$totalReactions ครั้ง',
                    icon: Icons.favorite_border_rounded,
                    iconColor: AppColors.pinkDeep,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    color: AppColors.greenPastel,
                    title: 'ข้อความแชท',
                    value: '$totalMessages ข้อความ',
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: AppColors.greenDeep,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // 3. Real Weekly Activity Chart
            const Text(
              'กิจกรรมจริงในสัปดาห์นี้',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildDayBar('จ.', weeklyHeights[0], isToday: todayWeekday == 1),
                  _buildDayBar('อ.', weeklyHeights[1], isToday: todayWeekday == 2),
                  _buildDayBar('พ.', weeklyHeights[2], isToday: todayWeekday == 3),
                  _buildDayBar('พฤ.', weeklyHeights[3], isToday: todayWeekday == 4),
                  _buildDayBar('ศ.', weeklyHeights[4], isToday: todayWeekday == 5),
                  _buildDayBar('ส.', weeklyHeights[5], isToday: todayWeekday == 6),
                  _buildDayBar('อา.', weeklyHeights[6], isToday: todayWeekday == 7),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // 4. Watch History Section
            Row(
              children: [
                const Text(
                  'ประวัติการดูล่าสุด',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (history.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      StatsService.clearHistory();
                      setState(() {});
                      Fluttertoast.showToast(msg: 'ล้างประวัติเรียบร้อย');
                    },
                    child: const Text('ล้างประวัติ',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            if (history.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'ยังไม่มีประวัติการดูคลิป เริ่มเข้าห้องและดูคลิปด้วยกันได้เลย! 🎬',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final dt =
                      DateTime.fromMillisecondsSinceEpoch(item.timestamp);
                  final timeStr =
                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.purplePastel,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: AppColors.purpleDeep),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'เวลา $timeStr • รหัสคลิป: ${item.videoId}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required Color color,
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayBar(String day, double heightFactor, {bool isToday = false}) {
    return Column(
      children: [
        Container(
          width: 16,
          height: (60 * heightFactor).clamp(8.0, 60.0),
          decoration: BoxDecoration(
            color: isToday ? AppColors.darkNav : AppColors.purplePastel,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isToday ? AppColors.darkNav : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
