import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/device_service.dart';
import 'services/stats_service.dart';
import 'services/favorites_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/watch_party_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize persistent nickname, stats, favorites & device ID
  try {
    await DeviceService.init();
    await StatsService.init();
    await FavoritesService.init();
  } catch (e) {
    debugPrint('Service init warning: $e');
  }

  // 2. Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }

  runApp(const SyncCoupleApp());
}



class SyncCoupleApp extends StatelessWidget {
  const SyncCoupleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ยูซิงค์',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainNavigationScreen(),
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.isNotEmpty) {
          final uri = Uri.tryParse(settings.name!);
          if (uri != null) {
            String? roomId;
            if (uri.scheme == 'usync' && uri.host == 'room') {
              roomId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
            } else if (uri.pathSegments.length >= 2 && uri.pathSegments.first == 'room') {
              roomId = uri.pathSegments[1];
            } else if (uri.path.startsWith('/room/')) {
              roomId = uri.path.replaceFirst('/room/', '').trim();
            }

            if (roomId != null && roomId.isNotEmpty) {
              return MaterialPageRoute(
                builder: (ctx) => WatchPartyScreen(roomId: roomId!),
              );
            }
          }
        }
        return null;
      },
    );
  }
}
