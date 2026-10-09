import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../theme/app_theme.dart';
import '../services/device_service.dart';
import '../services/stats_service.dart';
import '../services/favorites_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/theme_service.dart';
import '../models/room_info.dart';
import '../services/url_helper.dart';
import 'watch_party_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _createRoomController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();

  // Room options
  bool _isRoomLocked = false;
  String? _selectedCategory;

  // Active room state
  bool _hasActiveRoom = false;
  String? _activeRoomId;
  int _countdownRemaining = 0;
  Timer? _countdownTimer;
  StreamSubscription? _activeRoomSubscription;
  final FirebaseSyncService _homeSyncService = FirebaseSyncService();

  // Categories with vector icons
  List<Map<String, dynamic>> get _categories => [
        {
          'icon': Icons.music_note_rounded,
          'name': 'ฟังเพลง Lo-Fi',
          'color': AppColors.purplePastel,
          'deep': AppColors.purpleDeep,
          'prefix': 'ห้องฟังเพลง',
        },
        {
          'icon': Icons.sports_esports_rounded,
          'name': 'สตรีมเกม',
          'color': AppColors.bluePastel,
          'deep': AppColors.blueDeep,
          'prefix': 'แก๊งเกมเมอร์',
        },
        {
          'icon': Icons.movie_filter_rounded,
          'name': 'หนัง & ซีรีส์',
          'color': AppColors.orangePastel,
          'deep': AppColors.orangeDeep,
          'prefix': 'โรงหนังส่วนตัว',
        },
        {
          'icon': Icons.mic_rounded,
          'name': 'พอดแคสต์ & คุยสด',
          'color': AppColors.greenPastel,
          'deep': AppColors.greenDeep,
          'prefix': 'ทอล์คโชว์',
        },
        {
          'icon': Icons.auto_awesome_rounded,
          'name': 'อนิเมะ & การ์ตูน',
          'color': AppColors.pinkPastel,
          'deep': AppColors.pinkDeep,
          'prefix': 'โอตาคุคลับ',
        },
        {
          'icon': Icons.sports_soccer_rounded,
          'name': 'กีฬา & ไฮไลท์',
          'color': AppColors.bluePastel,
          'deep': AppColors.blueDeep,
          'prefix': 'รวมพลคนดูกีฬา',
        },
      ];

  @override
  void initState() {
    super.initState();
    _generateRandomRoom();
    _checkActiveRoom();
    ThemeService.isDarkModeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ThemeService.isDarkModeNotifier.removeListener(_onThemeChanged);
    _createRoomController.dispose();
    _pinController.dispose();
    _videoUrlController.dispose();
    _countdownTimer?.cancel();
    _activeRoomSubscription?.cancel();
    _homeSyncService.dispose();
    super.dispose();
  }

  /// Real-time check and listener for active room existence
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
        _homeSyncService.watchRoomExistence(lastRoom).listen((event) {
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
        final now = _homeSyncService.currentServerTimestamp;
        final remaining = ((deleteAt - now) / 1000).ceil();
        if (remaining <= 0) {
          _homeSyncService.deleteRoomImmediately(lastRoom);
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
          _homeSyncService.deleteRoomImmediately(_activeRoomId!);
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

  void _dismissActiveRoom() async {
    final rid = _activeRoomId;
    _countdownTimer?.cancel();
    _activeRoomSubscription?.cancel();
    FirebaseSyncService.clearLastActiveRoom();

    setState(() {
      _hasActiveRoom = false;
      _activeRoomId = null;
      _countdownRemaining = 0;
    });
    _generateRandomRoom();

    if (rid != null) {
      await _homeSyncService.deleteRoomImmediately(rid);
    }
    await _homeSyncService.cleanOldRoomsForDevice(_homeSyncService.myDeviceId);

    Fluttertoast.showToast(
      msg: 'ลบห้องเดิมเรียบร้อย สามารถสร้างห้องใหม่ได้ทันที',
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  void _generateRandomRoom([String? prefix]) {
    final names = [
      'คนเหงาดูคลิป',
      'ห้องนอนไม่หลับ',
      'ดูไปบ่นไป',
      'สมาคมคนตื่นสาย',
      'เม้าท์มอยหอยสังข์',
      'เปิดเพลงเต้นคนเดียว',
      'ห้องลับคนหล่อเท่',
      'แก๊งแมวส้มครองโลก',
      'ห้องดูคลิปผีตอนดึก',
      'กินหมูกระทะไปดูไป',
      'นักสืบโคนันจำเป็น',
      'ห้องแอบแม่ดูคลิป',
      'สมาคมคนรักอนิเมะ',
      'ห้องคนโสดโปรดจีบ',
      'ดูคลิปจนแบตหมด',
      'ต้มมาม่ารอบดึก',
      'คุยเรื่อยเปื่อยไม่นอน',
      'สมาคมคนรักการกิน',
      'ห้องคนน่ารักเท่านั้น',
      'สตรีมเมอร์จำเป็น',
    ];
    final selectedPrefix = prefix ?? names[Random().nextInt(names.length)];
    final randomCode = (100 + Random().nextInt(900)).toString();
    setState(() {
      _createRoomController.text = '$selectedPrefix-$randomCode';
    });
  }

  void _selectCategory(Map<String, dynamic> cat) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedCategory == cat['name']) {
        _selectedCategory = null;
        _generateRandomRoom();
      } else {
        _selectedCategory = cat['name'] as String;
        _generateRandomRoom(cat['prefix'] as String);
        Fluttertoast.showToast(
          msg: 'เลือกหมวดหมู่ "${cat['name']}" แล้ว!',
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    });
  }

  void _enterRoom({
    required String roomId,
    String? roomName,
    bool isLocked = false,
    String password = '',
    String initialVideoId = '',
  }) {
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) {
      Fluttertoast.showToast(msg: 'กรุณากรอกรหัสห้อง');
      return;
    }

    _countdownTimer?.cancel();
    if (_activeRoomId != null && _activeRoomId != cleanRoomId) {
      _homeSyncService.deleteRoomImmediately(_activeRoomId!);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WatchPartyScreen(
          roomId: cleanRoomId,
          roomName: roomName ?? cleanRoomId,
          initialLocked: isLocked,
          password: password,
          initialVideoId: initialVideoId,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {});
        _checkActiveRoom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nickname = DeviceService.getNickname();
    final avatarEmoji = StatsService.avatarEmoji;
    final favoriteRooms = FavoritesService.favorites;
    final isDark = AppColors.isDark;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'หน้าแรก',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. User Greeting Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark ? const Color(0xFF282438) : Colors.transparent,
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.purplePastel,
                          child: Text(
                            avatarEmoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'สวัสดี, $nickname',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ยูซิงค์ • รับชม YouTube พร้อมกันแบบ Real-time',
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

                  // 2. Quick Category Chips
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.purplePastel.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              size: 14,
                              color: AppColors.purpleDeep,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'หมวดหมู่ยอดนิยม',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          if (_selectedCategory != null)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedCategory = null;
                                  _generateRandomRoom();
                                });
                              },
                              child: Text(
                                'รีเซ็ต',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.purpleDeep,
                                ),
                              ),
                            )
                          else
                            Text(
                              'แตะเพื่อเลือกธีม',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final isCatSelected = _selectedCategory == cat['name'];
                            final iconData = cat['icon'] as IconData;
                            final accentColor = cat['deep'] as Color;
                            final pastelColor = cat['color'] as Color;

                            return GestureDetector(
                              onTap: () => _selectCategory(cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isCatSelected
                                      ? (isDark ? AppColors.purpleDeep : AppColors.darkNav)
                                      : AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isCatSelected
                                        ? (isDark ? AppColors.purpleDeep : AppColors.darkNav)
                                        : (isDark
                                            ? const Color(0xFF2E2940)
                                            : pastelColor.withValues(alpha: 0.6)),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                          alpha: isCatSelected
                                              ? 0.2
                                              : (isDark ? 0.25 : 0.03)),
                                      blurRadius: isCatSelected ? 8 : 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: isCatSelected
                                            ? Colors.white.withValues(alpha: 0.2)
                                            : pastelColor.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        iconData,
                                        size: 14,
                                        color: isCatSelected
                                            ? Colors.white
                                            : accentColor,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      cat['name'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isCatSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    if (isCatSelected) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 14,
                                        color: Color(0xFF4ADE80),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 3. Primary Centerpiece: Create Room / Rejoin Room Card
                  _buildCreateOrRejoinCard(isDark),

                  const SizedBox(height: 18),

                  // 5. Live Public Rooms Preview
                  StreamBuilder<List<RoomInfo>>(
                    stream: _homeSyncService.getPublicRooms(),
                    builder: (context, snapshot) {
                      final rooms = snapshot.data ?? [];
                      final liveRooms =
                          rooms.where((r) => r.memberCount > 0).take(4).toList();

                      if (liveRooms.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2EC4B6),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'กำลังดูสดอยู่ตอนนี้',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${liveRooms.length} ห้องกำลังดูอยู่',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 110,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: liveRooms.length,
                              itemBuilder: (context, index) {
                                final room = liveRooms[index];
                                return GestureDetector(
                                  onTap: () => _enterRoom(
                                    roomId: room.roomId,
                                    roomName: room.roomName,
                                    isLocked: room.isLocked,
                                    password: room.password,
                                  ),
                                  child: Container(
                                    width: 220,
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark
                                            ? const Color(0xFF2B273D)
                                            : AppColors.bluePastel.withValues(alpha: 0.6),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                              alpha: isDark ? 0.25 : 0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                room.roomName.isNotEmpty
                                                    ? room.roomName
                                                    : room.roomId,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (room.isLocked)
                                              Icon(Icons.lock_rounded,
                                                  size: 13,
                                                  color: AppColors.pinkDeep),
                                          ],
                                        ),
                                        Text(
                                          room.videoId.isNotEmpty
                                              ? '🎬 เล่น YouTube อยู่'
                                              : '⌛ กำลังเลือกคลิป',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.bluePastel
                                                    .withValues(alpha: 0.4),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons.people_rounded,
                                                      size: 12,
                                                      color: AppColors.blueDeep),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${room.memberCount} คน',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors.blueDeep,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark ? AppColors.purpleDeep : AppColors.darkNav,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'เข้าห้อง >',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                      );
                    },
                  ),

                  // 6. Favorite Rooms
                  if (favoriteRooms.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'ห้องโปรดของคุณ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: favoriteRooms.length,
                        itemBuilder: (context, index) {
                          final fav = favoriteRooms[index];
                          return GestureDetector(
                            onTap: () => _enterRoom(
                              roomId: fav.roomId,
                              roomName: fav.roomName,
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2B273D) : Colors.transparent,
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                        alpha: isDark ? 0.25 : 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.meeting_room_rounded,
                                      size: 16, color: AppColors.purpleDeep),
                                  const SizedBox(width: 6),
                                  Text(
                                    fav.roomName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the centerpiece card: either Create New Room or Rejoin Active Room
  Widget _buildCreateOrRejoinCard(bool isDark) {
    // ── REJOIN MODE ──
    if (_hasActiveRoom && _activeRoomId != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2D2010), const Color(0xFF22160A)]
                : [const Color(0xFFFFF3CD), const Color(0xFFFFE8A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark
                ? const Color(0xFF6B4810)
                : const Color(0xFFFFC67D),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.15),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
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
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF8A00),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ห้องเดิมยังเปิดอยู่',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFFFFC67D)
                              : const Color(0xFF856404),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Dismiss / Cancel active room
                InkWell(
                  onTap: _dismissActiveRoom,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 13,
                            color: isDark
                                ? const Color(0xFFFFC67D)
                                : const Color(0xFF856404)),
                        const SizedBox(width: 4),
                        Text(
                          'ยกเลิกห้อง',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFFFFC67D)
                                : const Color(0xFF856404),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'กลับห้องเดิมของคุณ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? const Color(0xFFFFF3CD)
                    : const Color(0xFF5A3E00),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.meeting_room_rounded,
                    size: 14,
                    color: isDark
                        ? const Color(0xFFFFE0B2)
                        : const Color(0xFF856404)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Room ID: $_activeRoomId'
                        '${_countdownRemaining > 0 ? '  •  หมดเวลาใน ${_countdownRemaining}s' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFFFE0B2)
                          : const Color(0xFF856404),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A00),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  _countdownTimer?.cancel();
                  _enterRoom(roomId: _activeRoomId!);
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login_rounded,
                        color: Colors.white, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'กลับเข้าห้องเดิมทันที',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: _dismissActiveRoom,
                icon: Icon(Icons.add_circle_outline_rounded,
                    size: 15,
                    color: isDark
                        ? const Color(0xFFFFC67D)
                        : const Color(0xFF856404)),
                label: Text(
                  'ต้องการสร้างห้องใหม่แทนห้องเดิม',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFFFC67D)
                        : const Color(0xFF856404),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── CREATE NEW ROOM MODE ──
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF241F3A), const Color(0xFF1B172C)]
              : [const Color(0xFFD6C5FC), const Color(0xFFFFE3D1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF3B3356) : Colors.transparent,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purpleDeep.withValues(
                alpha: isDark ? 0.15 : 0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
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
                  color: isDark
                      ? const Color(0xFF151322)
                      : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'สร้างห้องใหม่',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.purpleDeep,
                  ),
                ),
              ),
              const Spacer(),
              // Lock toggle button
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isRoomLocked = !_isRoomLocked;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isRoomLocked
                        ? AppColors.pinkDeep
                        : (isDark ? const Color(0xFF151322) : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isRoomLocked
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        size: 13,
                        color: _isRoomLocked
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isRoomLocked ? 'ล็อค PIN' : 'ห้องสาธารณะ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isRoomLocked
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Randomize Room Name
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _generateRandomRoom();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF151322) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shuffle_rounded,
                          size: 13, color: AppColors.purpleDeep),
                      const SizedBox(width: 4),
                      Text(
                        'สุ่มชื่อ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.purpleDeep,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'เริ่มปาร์ตี้ดูคลิปด้วยกัน',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ส่งชื่อห้องให้เพื่อน แล้วเข้ามาดูคลิปพร้อมกันได้ทันที',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textSecondary
                  : const Color(0xFF5A4D78),
            ),
          ),
          const SizedBox(height: 16),

          // Room Name TextField
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF12101E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF2E2844) : Colors.transparent,
                width: 1.0,
              ),
            ),
            child: TextField(
              controller: _createRoomController,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'ตั้งชื่อหรือรหัสห้อง',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: InputBorder.none,
                icon: Icon(Icons.meeting_room_rounded,
                    color: AppColors.purpleDeep, size: 20),
              ),
            ),
          ),

          // Optional YouTube URL TextField
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF12101E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF2E2844) : Colors.transparent,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _videoUrlController,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'ลิงก์ YouTube ที่ต้องการเปิดเลย (ทางเลือก)',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      border: InputBorder.none,
                      icon: Icon(
                        Icons.link_rounded,
                        color: AppColors.orangeDeep,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                      setState(() {
                        _videoUrlController.text = data.text!.trim();
                      });
                      Fluttertoast.showToast(msg: 'วางลิงก์แล้ว');
                    } else {
                      Fluttertoast.showToast(msg: 'คลิปบอร์ดว่างเปล่า');
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 8),
                    child: Text(
                      'วาง',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.orangeDeep,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Optional PIN field if locked
          if (_isRoomLocked) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF12101E) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2844) : Colors.transparent,
                  width: 1.0,
                ),
              ),
              child: TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.pinkDeep,
                ),
                decoration: InputDecoration(
                  hintText: 'ตั้งรหัสผ่าน PIN (ตัวเลข 4-6 หลัก)',
                  hintStyle: TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                  border: InputBorder.none,
                  counterText: '',
                  icon: Icon(Icons.key_rounded,
                      color: AppColors.pinkDeep, size: 18),
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.purpleDeep : AppColors.darkNav,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: () {
                final rid = _createRoomController.text.trim();
                final pin = _pinController.text.trim();
                if (_isRoomLocked && pin.isEmpty) {
                  Fluttertoast.showToast(
                      msg: 'กรุณาตั้งรหัสผ่าน PIN สำหรับห้องล็อค');
                  return;
                }

                // Extract optional YouTube Video ID
                String initialVideoId = '';
                final rawUrl = _videoUrlController.text.trim();
                if (rawUrl.isNotEmpty) {
                  final extracted = UrlHelper.extractYouTubeId(rawUrl);
                  if (extracted != null) {
                    initialVideoId = extracted;
                  } else {
                    Fluttertoast.showToast(msg: 'ลิงก์ YouTube ไม่ถูกต้อง จะสร้างห้องเปล่า');
                  }
                }

                _enterRoom(
                  roomId: rid,
                  isLocked: _isRoomLocked,
                  password: pin,
                  initialVideoId: initialVideoId,
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'สร้างห้อง & เริ่มเล่นเลย',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
