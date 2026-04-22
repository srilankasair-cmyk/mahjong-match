enum LevelMode { basic, advanced, challenge, nightmare }

class GameConfig {
  final LevelMode mode;
  final int handSlots;
  final bool hasMagicTiles;
  final bool isNightmare;

  const GameConfig({
    required this.mode,
    required this.handSlots,
    required this.hasMagicTiles,
    this.isNightmare = false,
  });

  static const GameConfig basic = GameConfig(
    mode: LevelMode.basic,
    handSlots: 14,
    hasMagicTiles: false,
  );

  static const GameConfig advanced = GameConfig(
    mode: LevelMode.advanced,
    handSlots: 14,
    hasMagicTiles: true,
  );

  static const GameConfig challenge = GameConfig(
    mode: LevelMode.challenge,
    handSlots: 7,
    hasMagicTiles: true,
  );

  static const GameConfig nightmare = GameConfig(
    mode: LevelMode.nightmare,
    handSlots: 7,
    hasMagicTiles: true,
    isNightmare: true,
  );

  static const List<GameConfig> all = [basic, advanced, challenge, nightmare];

  String get displayName {
    switch (mode) {
      case LevelMode.basic:
        return 'Basic Mode';
      case LevelMode.advanced:
        return 'Fun Mode';
      case LevelMode.challenge:
        return 'Challenge Mode';
      case LevelMode.nightmare:
        return 'Nightmare Mode';
    }
  }

  String get description {
    switch (mode) {
      case LevelMode.basic:
        return '14 hand slots\nFriendly to starter';
      case LevelMode.advanced:
        return '14 hand slots\nMagic tiles';
      case LevelMode.challenge:
        return '7 hand slots\nMagic tiles';
      case LevelMode.nightmare:
        return '7 hand slots\nMagic tiles\nLocked tiles hidden';
    }
  }
}

class ResultArgs {
  final int score;
  final LevelMode level;
  final bool isVictory;

  const ResultArgs({
    required this.score,
    required this.level,
    required this.isVictory,
  });
}
