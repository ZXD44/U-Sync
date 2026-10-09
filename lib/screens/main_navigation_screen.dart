import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_sync_service.dart';
import '../services/theme_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'rooms_browser_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  bool _hasLiveRooms = false;
  StreamSubscription? _roomsSubscription;
  final FirebaseSyncService _syncService = FirebaseSyncService();

  final List<Widget> _screens = [
    const HomeScreen(),          // 1. หน้าแรก
    const RoomsBrowserScreen(),  // 2. ห้องสด
    const StatsScreen(),         // 3. สถิติ
    const ProfileScreen(),       // 4. โปรไฟล์ & ตั้งค่า
  ];

  @override
  void initState() {
    super.initState();
    _roomsSubscription = _syncService.getPublicRooms().listen((rooms) {
      if (mounted) {
        setState(() {
          _hasLiveRooms = rooms.isNotEmpty;
        });
      }
    });

    _checkAutoUpdate();
  }

  void _checkAutoUpdate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final release = await UpdateService.checkForUpdate();
    if (release != null && release.hasUpdate && mounted) {
      UpdateDialog.show(context, release);
    }
  }

  @override
  void dispose() {
    _roomsSubscription?.cancel();
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService.isDarkModeNotifier,
      builder: (context, isDark, _) {
        return Scaffold(
          body: Stack(
            children: [
              // Current Selected Screen
              IndexedStack(
                index: _selectedIndex,
                children: _screens,
              ),

              // Floating Pill Navbar at Bottom Center
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: Center(
                  child: FloatingPillNavBar(
                    selectedIndex: _selectedIndex,
                    hasLiveRooms: _hasLiveRooms,
                    onItemSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
