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
import '../models/room_info.dart';
import 'watch_party_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _createRoomController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  // Room options
  bool _isRoomLocked = false;
  String _selectedCategory = '';

  // Rejoin banner state
  bool _hasActiveRoom = false;
  String? _activeRoomId;
  int _countdownRemaining = 0;
  Timer? _countdownTimer;
  StreamSubscription? _activeRoomSubscription;
  final FirebaseSyncService _homeSyncService = FirebaseSyncService();

  // Quick categories
  final List<Map<String, dynamic>> _categories = [
    {
      'icon': '🎵',
      'name': 'ฟังเพลง Lo-Fi',
      'color': AppColors.purplePastel,
      'deep': AppColors.purpleDeep,
      'prefix': 'ห้องฟังเพลง'
    },
    {
      'icon': '🎮',
      'name': 'สตรีมเกม',
      'color': AppColors.bluePastel,
      'deep': AppColors.blueDeep,
      'prefix': 'แก๊งเกมเมอร์'
    },
    {
      'icon': '🍿',
      'name': 'หนัง & ซีรีส์',
      'color': AppColors.orangePastel,
      'deep': AppColors.orangeDeep,
      'prefix': 'โรงหนังส่วนตัว'
    },
    {
      'icon': '🎙️',
      'name': 'พอดแคสต์ & คุยสด',
      'color': AppColors.greenPastel,
      'deep': AppColors.greenDeep,
      'prefix': 'ทอล์คโชว์'
    },
    {
      'icon': '📺',
      'name': 'อนิเมะ & การ์ตูน',
      'color': AppColors.pinkPastel,
      'deep': AppColors.pinkDeep,
      'prefix': 'โอตาคุคลับ'
    },
    {
      'icon': '⚽',
      'name': 'กีฬา & ไฮไลท์',
      'color': AppColors.bluePastel,
      'deep': AppColors.blueDeep,
      'prefix': 'รวมพลคนดูกีฬา'
    },
  ];

  @override
  void initState() {
    super.initState();
    _generateRandomRoom();
    _checkActiveRoom();
  }

  @override
  void dispose() {
    _createRoomController.dispose();
    _pinController.dispose();
    _countdownTimer?.cancel();
    _activeRoomSubscription?.cancel();
    _homeSyncService.dispose();
    super.dispose();
  }

  /// Real-time check and listener for active room existence
  void _checkActiveRoom() async {
    _activeRoomSubscription?.cancel();
    final lastRoom = FirebaseSyncService.lastActiveRoomId;
    if (lastRoom == null || lastRoom.isEmpty) {
      if (mounted) setState(() => _hasActiveRoom = false);
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

  void _dismissActiveRoom() {
    final rid = _activeRoomId;
    _countdownTimer?.cancel();
    _activeRoomSubscription?.cancel();
    FirebaseSyncService.clearLastActiveRoom();
    if (rid != null) {
      _homeSyncService.deleteRoomImmediately(rid);
    }
    setState(() {
      _hasActiveRoom = false;
      _activeRoomId = null;
      _countdownRemaining = 0;
    });
    Fluttertoast.showToast(
      msg: 'ยกเลิกห้องเดิมแล้ว สามารถสร้างหรือเข้าห้องใหม่ได้ทันที',
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

  void _enterRoom({
    required String roomId,
    String? roomName,
    bool isLocked = false,
    String password = '',
  }) {
    final cleanRoomId = roomId.trim();
    if (cleanRoomId.isEmpty) {
      Fluttertoast.showToast(msg: 'กรุณากรอกรหัสห้อง');
      return;
    }

    if (_hasActiveRoom &&
        _activeRoomId != null &&
        _activeRoomId != cleanRoomId) {
      Fluttertoast.showToast(
        msg: 'คุณมีห้องที่เปิดอยู่แล้ว กำลังนำท่านกลับเข้าห้องเดิม "$_activeRoomId"',
        toastLength: Toast.LENGTH_LONG,
        backgroundColor: const Color(0xFF856404),
      );
      _countdownTimer?.cancel();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WatchPartyScreen(
            roomId: _activeRoomId!,
            roomName: _activeRoomId!,
            initialLocked: false,
            password: '',
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() {});
          _checkActiveRoom();
        }
      });
      return;
    }

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

  void _selectCategory(Map<String, dynamic> cat) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategory = cat['name'] as String;
    });
    _generateRandomRoom(cat['prefix'] as String);
    Fluttertoast.showToast(
      msg: 'เลือกหมวดหมู่ "${cat['name']}" แล้ว!',
      toastLength: Toast.LENGTH_SHORT,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nickname = DeviceService.getNickname();
    final avatarEmoji = StatsService.avatarEmoji;
    final favoriteRooms = FavoritesService.favorites;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Bar: Profile greeting
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.purpleDeep, AppColors.pinkDeep],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.purpleDeep.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          child: Text(
                            avatarEmoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'สวัสดี, $nickname',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'แอปยูซิงค์ • ดู YouTube พร้อมกันแบบ Real-time',
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

                  const SizedBox(height: 18),

                  // 2. ⏳ REJOIN ACTIVE ROOM BANNER (if alive)
                  if (_hasActiveRoom && _activeRoomId != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF3CD), Color(0xFFFFE8A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.2),
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
                              const Icon(Icons.access_time_rounded,
                                  color: Color(0xFF856404), size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _countdownRemaining > 0
                                      ? 'ห้องเดิมกำลังจะถูกลบใน $_countdownRemaining วินาที'
                                      : 'ห้องเดิมของคุณยังเปิดอยู่',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF856404),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: _dismissActiveRoom,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Color(0xFF856404),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ห้อง: $_activeRoomId',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF856404),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF856404),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  onPressed: () {
                                    _countdownTimer?.cancel();
                                    _enterRoom(roomId: _activeRoomId!);
                                  },
                                  icon: const Icon(Icons.login_rounded,
                                      size: 16, color: Colors.white),
                                  label: const Text(
                                    'กลับเข้าห้องเดิม',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (_countdownRemaining > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_countdownRemaining}s',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF856404),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. Quick Category Chips (หมวดหมู่ดูด่วน)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.category_rounded,
                              size: 16, color: AppColors.purpleDeep),
                          SizedBox(width: 6),
                          Text(
                            'เลือกหมวดหมู่ยอดนิยม',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            final cat = _categories[index];
                            final isCatSelected =
                                _selectedCategory == cat['name'];
                            return GestureDetector(
                              onTap: () => _selectCategory(cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isCatSelected
                                      ? AppColors.darkNav
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isCatSelected
                                        ? AppColors.darkNav
                                        : AppColors.purplePastel
                                            .withValues(alpha: 0.6),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      cat['icon'] as String,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
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

                  // 4. Primary Card 1: "สร้างห้องดูคลิปด่วน" (Main Centerpiece Bento)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD6C5FC), Color(0xFFFFE3D1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.purplePastel.withValues(alpha: 0.4),
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
                                color: Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _hasActiveRoom && _activeRoomId != null
                                    ? 'ห้องเดิมยังเปิดอยู่'
                                    : 'สร้างห้องใหม่',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.purpleDeep,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Lock toggle button
                            if (!_hasActiveRoom) ...[
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
                                        : Colors.white,
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shuffle_rounded,
                                          size: 13,
                                          color: AppColors.purpleDeep),
                                      SizedBox(width: 4),
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
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _hasActiveRoom && _activeRoomId != null
                              ? 'คุณมีห้องที่เปิดใช้งานอยู่แล้ว'
                              : 'เริ่มปาร์ตี้ดูคลิปด้วยกัน',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasActiveRoom && _activeRoomId != null
                              ? 'ห้องเดิมของคุณ "$_activeRoomId" กำลังทำงานอยู่ กดเพื่อกลับเข้าห้องเดิม'
                              : 'ส่งชื่อห้องให้เพื่อน แล้วเข้ามาดูคลิปพร้อมกันได้ทันที',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5A4D78),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Room Name TextField
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: TextField(
                            controller: _createRoomController,
                            enabled: !_hasActiveRoom,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: _hasActiveRoom
                                  ? 'ห้องเดิม: $_activeRoomId'
                                  : 'ตั้งชื่อหรือรหัสห้อง',
                              border: InputBorder.none,
                              icon: const Icon(Icons.meeting_room_rounded,
                                  color: AppColors.purpleDeep, size: 20),
                            ),
                          ),
                        ),

                        // Optional PIN field if locked
                        if (_isRoomLocked && !_hasActiveRoom) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.pinkDeep,
                              ),
                              decoration: const InputDecoration(
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
                              backgroundColor: AppColors.darkNav,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: () {
                              if (_hasActiveRoom && _activeRoomId != null) {
                                _enterRoom(roomId: _activeRoomId!);
                              } else {
                                final rid = _createRoomController.text.trim();
                                final pin = _pinController.text.trim();
                                if (_isRoomLocked && pin.isEmpty) {
                                  Fluttertoast.showToast(
                                      msg: 'กรุณาตั้งรหัสผ่าน PIN สำหรับห้องล็อค');
                                  return;
                                }
                                _enterRoom(
                                  roomId: rid,
                                  isLocked: _isRoomLocked,
                                  password: pin,
                                );
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                    _hasActiveRoom
                                        ? Icons.login_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  _hasActiveRoom && _activeRoomId != null
                                      ? 'กลับเข้าห้องเดิม'
                                      : 'สร้างห้อง & เริ่มเล่นเลย',
                                  style: const TextStyle(
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
                  ),

                  const SizedBox(height: 18),

                  // 5. 🔥 Live Public Rooms Carousel (พรีวิวห้องที่กำลังดูสดอยู่)
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
                              const Text(
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
                                style: const TextStyle(
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
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.bluePastel
                                            .withValues(alpha: 0.6),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.03),
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
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (room.isLocked)
                                              const Icon(Icons.lock_rounded,
                                                  size: 13,
                                                  color: AppColors.pinkDeep),
                                          ],
                                        ),
                                        Text(
                                          room.videoId.isNotEmpty
                                              ? '🎬 เล่น YouTube อยู่'
                                              : '⌛ กำลังเลือกคลิป',
                                          style: const TextStyle(
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.bluePastel
                                                    .withValues(alpha: 0.4),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                      Icons.people_rounded,
                                                      size: 12,
                                                      color: AppColors.blueDeep),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${room.memberCount} คน',
                                                    style: const TextStyle(
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
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: AppColors.darkNav,
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

                  // 6. Favorite Rooms (if any)
                  if (favoriteRooms.isNotEmpty) ...[
                    const Row(
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        SizedBox(width: 6),
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.meeting_room_rounded,
                                      size: 16, color: AppColors.purpleDeep),
                                  const SizedBox(width: 6),
                                  Text(
                                    fav.roomName,
                                    style: const TextStyle(
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

                  const SizedBox(height: 80), // Padding for Floating Nav
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
