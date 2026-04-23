import 'package:flutter/material.dart';
import 'screens/start_screen.dart';
import 'screens/level_select_screen.dart';
import 'screens/game_screen.dart';
import 'screens/result_screen.dart';
import 'models/game_config.dart';
import 'services/audio_service.dart';
import 'services/audio_web_unlock.dart'
    if (dart.library.io) 'services/audio_web_unlock_stub.dart';

void main() {
  runApp(const MahjongMatchApp());
}

class MahjongMatchApp extends StatelessWidget {
  const MahjongMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        unlockWebAudioContext(); // synchronous — must run before any await
        AudioService.instance.onUserInteraction();
      },
      child: MaterialApp(
        title: 'Mahjong Match',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2E7D32),
          ),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const StartScreen(),
          '/levels': (context) => const LevelSelectScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/game') {
            final config = settings.arguments as GameConfig;
            return MaterialPageRoute(
              builder: (context) => GameScreen(config: config),
            );
          }
          if (settings.name == '/result') {
            final args = settings.arguments as ResultArgs;
            return MaterialPageRoute(
              builder: (context) => ResultScreen(args: args),
            );
          }
          return null;
        },
      ),
    );
  }
}
