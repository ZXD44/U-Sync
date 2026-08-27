import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../theme/app_theme.dart';
import '../models/room_info.dart';
import '../services/firebase_sync_service.dart';
import 'watch_party_screen.dart';

class RoomsBrowserScreen extends StatefulWidget {
  const RoomsBrowserScreen({super.key});

  @override
  State<RoomsBrowserScreen> createState() => _RoomsBrowserScreenState();
}

class _RoomsBrowserScreenState extends State<RoomsBrowserScreen> {
  final FirebaseSyncService _syncService = FirebaseSyncService();
  final TextEditingController _searchController = TextEditingController();
  int _selectedFilter = 0; // 0 = ทั้งหมด, 1 = สาธารณะ, 2 = ล็อค

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterRoom({
    required String roomId,
    String? roomName,
    bool isLocked = false,
    String password = '',
  }) {
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WatchPartyScreen(
          roomId: cleanRoomId,
          roomName: roomName ?? cleanRoomId,
          initialLocked: isLocked,
          password: password,
        ),
      ),
    );
  }

  void _showJoinLockedRoomDialog(RoomInfo room) {
    final pwdController = TextEditingController();
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
              title: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: AppColors.orangeDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ห้อง "${room.roomName}" ล็อคอยู่',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'กรุณากรอกรหัสผ่านเพื่อเข้าห้องนี้',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pwdController,
                    obscureText: true,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'รหัสผ่านห้อง',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
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
                    if (pwdController.text.trim() == room.password) {
                      Navigator.pop(ctx);
                      _enterRoom(
                        roomId: room.roomId,
                        roomName: room.roomName,
                        isLocked: room.isLocked,
                        password: room.password,
                      );
                    } else {
                      Fluttertoast.showToast(msg: 'รหัสผ่านไม่ถูกต้อง');
                    }
                  },
                  child: const Text('เข้าห้อง',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'สำรวจห้องปาร์ตี้',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search & Filter Box
            // 🔍 Redesigned Modern Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.isDark
                        ? const Color(0xFF2E2B40)
                        : AppColors.purplePastel.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: AppColors.isDark ? 0.25 : 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.purplePastel.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: AppColors.purpleDeep,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'ค้นหาชื่อห้อง หรือรหัส Room ID...',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded,
                            size: 18, color: AppColors.textMuted),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
            ),

            // Category Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  _buildFilterChip(0, 'ทั้งหมด', Icons.explore_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip(1, 'สาธารณะ', Icons.lock_open_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip(2, 'ห้องล็อค', Icons.lock_rounded),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Live Rooms Stream
            Expanded(
              child: StreamBuilder<List<RoomInfo>>(
                stream: _syncService.getPublicRooms(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.purpleDeep),
                    );
                  }

                  var rooms = snapshot.data ?? [];

                  // Apply search filter
                  final query = _searchController.text.trim().toLowerCase();
                  if (query.isNotEmpty) {
                    rooms = rooms.where((r) {
                      return r.roomName.toLowerCase().contains(query) ||
                          r.roomId.toLowerCase().contains(query);
                    }).toList();
                  }

                  // Apply tab filter
                  if (_selectedFilter == 1) {
                    rooms = rooms.where((r) => !r.isLocked).toList();
                  } else if (_selectedFilter == 2) {
                    rooms = rooms.where((r) => r.isLocked).toList();
                  }

                  if (rooms.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: const BoxDecoration(
                                color: AppColors.purplePastel,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.meeting_room_outlined,
                                  size: 34, color: AppColors.purpleDeep),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'ไม่พบห้องที่กำลังเปิดอยู่ในขณะนี้',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'สร้างห้องใหม่ที่หน้าแรกเพื่อเริ่มดูคลิปพร้อมกันได้เลย',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];

                      return _RoomCard(
                        room: room,
                        onJoin: () {
                          if (room.isLocked) {
                            _showJoinLockedRoomDialog(room);
                          } else {
                            _enterRoom(
                              roomId: room.roomId,
                              roomName: room.roomName,
                              isLocked: false,
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, IconData icon) {
    final bool isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.darkNav : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.darkNav
                : (AppColors.isDark
                    ? const Color(0xFF2E2B40)
                    : AppColors.purplePastel.withValues(alpha: 0.5)),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(
                        alpha: AppColors.isDark ? 0.2 : 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.purpleDeep,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Room card with live countdown timer for rooms pending deletion
class _RoomCard extends StatefulWidget {
  final RoomInfo room;
  final VoidCallback onJoin;

  const _RoomCard({required this.room, required this.onJoin});

  @override
  State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard> {
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  final FirebaseSyncService _cardSyncService = FirebaseSyncService();

  @override
  void initState() {
    super.initState();
    _calculateCountdown();
    if (_secondsRemaining > 0) {
      _startTicker();
    }
  }

  @override
  void didUpdateWidget(covariant _RoomCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.deleteAt != widget.room.deleteAt) {
      _calculateCountdown();
      _countdownTimer?.cancel();
      if (_secondsRemaining > 0) {
        _startTicker();
      }
    }
  }

  void _calculateCountdown() {
    if (widget.room.deleteAt <= 0) {
      _secondsRemaining = 0;
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = ((widget.room.deleteAt - now) / 1000).ceil();
    _secondsRemaining = diff > 0 ? diff : 0;
  }

  void _startTicker() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _cardSyncService.deleteRoomImmediately(widget.room.roomId);
        if (mounted) {
          setState(() {
            _secondsRemaining = 0;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cardSyncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final bool isPlaying = room.status == 'PLAYING';
    final bool isPendingDeletion = _secondsRemaining > 0 && room.memberCount == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPendingDeletion ? const Color(0xFFFFF8F0) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: isPendingDeletion
            ? Border.all(color: const Color(0xFFFFBB5C), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: room.isLocked
                    ? AppColors.orangePastel
                    : AppColors.purplePastel,
                child: Icon(
                  room.isLocked
                      ? Icons.lock_rounded
                      : Icons.smart_display_rounded,
                  color: room.isLocked
                      ? AppColors.orangeDeep
                      : AppColors.purpleDeep,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.roomName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Room ID: ${room.roomId}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (room.isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.orangePastel,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'มีรหัสผ่าน',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7F4F24),
                    ),
                  ),
                ),
            ],
          ),

          // ⏳ Countdown Banner
          if (isPendingDeletion) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_rounded,
                      size: 16, color: Color(0xFFE65100)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ห้องจะถูกลบใน $_secondsRemaining วินาที',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ),
                  Text(
                    '${_secondsRemaining}s',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF4F0FA)),
          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying
                      ? const Color(0xFF2EC4B6)
                      : AppColors.orangeDeep,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isPlaying ? 'กำลังเล่นวิดีโอ' : 'พักวิดีโอ',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.people_alt_rounded,
                  size: 14, color: AppColors.purpleDeep),
              const SizedBox(width: 4),
              Text(
                '${room.memberCount} คนออนไลน์',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPendingDeletion
                      ? const Color(0xFFE65100)
                      : AppColors.darkNav,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: widget.onJoin,
                child: Text(
                  isPendingDeletion ? 'กู้คืนห้อง' : 'เข้าร่วม',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

