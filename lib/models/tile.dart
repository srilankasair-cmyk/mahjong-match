import 'package:flutter/material.dart';

enum TileSuit {
  man,        // Characters (万)
  pin,        // Dots (筒)
  sou,        // Bamboo (条)
  east,       // East Wind (東) - magic
  west,       // West Wind (西) - magic
  south,      // South Wind (南) - magic
  north,      // North Wind (北) - magic
  redDragon,    // Red Dragon (中) - magic
  whiteDragon,  // White Dragon (白) - magic
  greenDragon,  // Green Dragon (發) - magic
}

class Tile {
  final String id;
  final TileSuit suit;
  final int number; // 1-9 for man/pin/sou, 0 for honour tiles

  const Tile({required this.id, required this.suit, this.number = 0});

  bool get isMagic =>
      suit == TileSuit.east ||
      suit == TileSuit.west ||
      suit == TileSuit.south ||
      suit == TileSuit.north ||
      suit == TileSuit.redDragon ||
      suit == TileSuit.whiteDragon ||
      suit == TileSuit.greenDragon;

  bool get isNumbered =>
      suit == TileSuit.man || suit == TileSuit.pin || suit == TileSuit.sou;

  /// Key used to group identical tiles for matching
  String get matchKey {
    if (isNumbered) return '${suit.name}_$number';
    return suit.name;
  }

  String get displayTop {
    switch (suit) {
      case TileSuit.man:
        return _chineseNum(number);
      case TileSuit.pin:
        return _chineseNum(number);
      case TileSuit.sou:
        return _chineseNum(number);
      case TileSuit.east:
        return '東';
      case TileSuit.west:
        return '西';
      case TileSuit.south:
        return '南';
      case TileSuit.north:
        return '北';
      case TileSuit.redDragon:
        return '中';
      case TileSuit.whiteDragon:
        return '白';
      case TileSuit.greenDragon:
        return '發';
    }
  }

  String get displayBottom {
    switch (suit) {
      case TileSuit.man:
        return '万';
      case TileSuit.pin:
        return '筒';
      case TileSuit.sou:
        return '条';
      default:
        return '';
    }
  }

  Color get textColor {
    switch (suit) {
      case TileSuit.man:
        return const Color(0xFFD32F2F);
      case TileSuit.pin:
        return const Color(0xFF1565C0);
      case TileSuit.sou:
        return const Color(0xFF2E7D32);
      case TileSuit.east:
      case TileSuit.west:
      case TileSuit.south:
      case TileSuit.north:
        return const Color(0xFF6D4C41);
      case TileSuit.redDragon:
        return const Color(0xFFD32F2F);
      case TileSuit.whiteDragon:
        return const Color(0xFF37474F);
      case TileSuit.greenDragon:
        return const Color(0xFF2E7D32);
    }
  }

  Color get backgroundColor {
    if (isMagic) return const Color(0xFFFFF9C4);
    return const Color(0xFFFFFDE7);
  }

  static String _chineseNum(int n) {
    const nums = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    return (n >= 1 && n <= 9) ? nums[n] : '?';
  }

  @override
  bool operator ==(Object other) => other is Tile && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Tile($matchKey #$id)';
}
