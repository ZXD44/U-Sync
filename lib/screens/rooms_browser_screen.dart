import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../theme/app_theme.dart';
import '../models/room_info.dart';
import '../services/firebase_sync_service.dart';
import '../services/theme_service.dart';
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

  // Active room state for compact rejoin strip
  bool _hasActiveRoom = false;
  String? _activeRoomId;
  int _countdownRemaining = 0;
  Timer? _countdownTimer;
  StreamSubscription? _activeRoomSubscription;
  final FirebaseSyncService _rejoinSyncService = FirebaseSyncService();

  @override
  void initState() {
    super.initState();
    _checkActiveRoom();
    ThemeService.isDarkModeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _checkActiveRoom() {
    _activeRoomSubscription?.cancel();
    final lastRoom = FirebaseSyncService.lastActiveRoomId;
    if (lastRoom == null || lastRoom.isEmpty) {
      if (mounted) {
        setState(() {
          _hasActiveRoom = false;
          _activeRoomId = null;
        });
      }
      return;
    }

    _activeRoomSubscription =
        _rejoinSyncService.watchRoomExistence(lastRoom).listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        _countdownTimer?.cancel();
        FirebaseSyncService.clearLastActiveRoom();
        if (mounted) {
          setState(() {
            _hasActiveRoom = false;
            _activeRoomId = null;
            _countdownRemaining = 0;
          });
        }
        return;
      }

      final data = event.snapshot.value as Map?;
      final state = data?['state'] as Map?;
      final deleteAt = (state?['deleteAt'] as num?)?.toInt() ?? 0;

      if (deleteAt > 0) {
        final now = _rejoinSyncService.currentServerTimestamp;
        final remaining = ((deleteAt - now) / 1000).ceil();
        if (remaining <= 0) {
          _rejoinSyncService.deleteRoomImmediately(lastRoom);
          _countdownTimer?.cancel();
          FirebaseSyncService.clearLastActiveRoom();
          if (mounted) {
            setState(() {
              _hasActiveRoom = false;
              _activeRoomId = null;
              _countdownRemaining = 0;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _hasActiveRoom = true;
              _activeRoomId = lastRoom;
              _countdownRemaining = remaining;
            });
          }
          _startCountdownTicker();
        }
      } else {
        if (mounted) {
          setState(() {
            _hasActiveRoom = true;
            _activeRoomId = lastRoom;
            _countdownRemaining = 0;
          });
        }
      }
    });
  }

  void _startCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownRemaining <= 1) {
        timer.cancel();
        if (_activeRoomId != null) {
          _rejoinSyncService.deleteRoomImmediately(_activeRoomId!);
        }
        FirebaseSyncService.clearLastActiveRoom();
        if (mounted) {
          setState(() {
            _hasActiveRoom = false;
            _activeRoomId = null;
            _countdownRemaining = 0;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _countdownRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    ThemeService.isDarkModeNotifier.removeListener(_onThemeChanged);
    _searchController.dispose();
    _countdownTimer?.cancel();
    _activeRoomSubscription?.cancel();
    _rejoinSyncService.dispose();
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

    _countdownTimer?.cancel();
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
    ).then((_) {
      if (mounted) {
        setState(() {});
        _checkActiveRoom();
      }
    });
  }

  void _showJoinLockedRoomDialog(RoomInfo room) {
    final pwdController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = AppColors.isDark;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AlertDialog(
              backgroundColor: AppColors.cardBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Icon(Icons.lock_rounded, color: AppColors.orangeDeep),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ห้อง "${room.roomName}" ล็อคอยู่',
                      style: TextStyle(
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
                  Text(
                    'กรุณากรอกรหัสผ่านเพื่อเข้าห้องนี้',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pwdController,
                    obscureText: true,
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'รหัสผ่านห้อง',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF13121E) : AppColors.background,
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
                  child: Text('ยกเลิก',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.purpleDeep : AppColors.darkNav,
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
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
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
            // Compact Rejoin Active Room Strip
            if (_hasActiveRoom && _activeRoomId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 2),
                child: GestureDetector(
                  onTap: () {
                    _countdownTimer?.cancel();
                    _enterRoom(roomId: _activeRoomId!);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2D2010), const Color(0xFF22160A)]
                            : [const Color(0xFFFFF3CD), const Color(0xFFFFE8A1)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF6B4810)
                            : const Color(0xFFFFC67D),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF8A00),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ห้องเดิม: $_activeRoomId'
                                '${_countdownRemaining > 0 ? '  •  ${_countdownRemaining}s' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFFFFC67D)
                                  : const Color(0xFF856404),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8A00),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'กลับห้องเดิม',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2E2B40)
                        : AppColors.purplePastel.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.04),
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
                      child: Icon(
                        Icons.search_rounded,
                        color: AppColors.purpleDeep,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ค้นหาชื่อห้อง หรือรหัส Room ID...',
                          hintStyle: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.cancel_rounded,
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
                    return Center(
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
                              decoration: BoxDecoration(
                                color: AppColors.purplePastel,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.meeting_room_outlined,
                                  size: 34, color: AppColors.purpleDeep),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'ไม่พบห้องที่กำลังเปิดอยู่ในขณะนี้',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
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
    final isDark = AppColors.isDark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.purpleDeep : AppColors.darkNav)
              : AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.purpleDeep : AppColors.darkNav)
                : (isDark
                    ? const Color(0xFF2E2B40)
                    : AppColors.purplePastel.withValues(alpha: 0.5)),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                  alpha: isSelected ? 0.2 : (isDark ? 0.25 : 0.02)),
              blurRadius: isSelected ? 8 : 6,
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
    final isDark = AppColors.isDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPendingDeletion
              ? (isDark ? const Color(0xFF6E4515) : const Color(0xFFFFCC80))
              : (isDark ? const Color(0xFF2B273D) : Colors.transparent),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            room.roomName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPendingDeletion) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF3E2005)
                                  : const Color(0xFFFFE0B2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'ลบใน ${_secondsRemaining}s',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Room ID: ${room.roomId}',
                      style: TextStyle(
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
                  child: Text(
                    'มีรหัสผ่าน',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.orangeDeep,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.divider),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.people_alt_rounded,
                  size: 14, color: AppColors.purpleDeep),
              const SizedBox(width: 4),
              Text(
                '${room.memberCount} คนออนไลน์',
                style: TextStyle(
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
                      : (isDark ? AppColors.purpleDeep : AppColors.darkNav),
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
