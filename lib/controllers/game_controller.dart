import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/tile.dart';
import '../models/game_config.dart';
import '../models/sound_event.dart';

class GameController extends ChangeNotifier {
  final GameConfig config;

  // board[row][col], 5 rows x 7 cols
  late List<List<Tile?>> board;
  late List<Tile> tilePool;
  late List<Tile?> handSlots;
  int score = 0;
  int totalTiles = 0;
  int clearedTiles = 0;
  bool isGameOver = false;
  bool isVictory = false;

  /// The last effect message to show briefly in the UI
  String? lastEffectMessage;

  /// IDs of tiles removed by the last magic-tile activation (so the UI can
  /// animate them fading out before they disappear).
  List<String> lastMagicRemovedTileIds = [];

  /// The three tiles just consumed by the most recent Pung or Chow.
  /// Set before notifyListeners so the UI can spawn a departure animation.
  List<Tile> lastMatchedTiles = [];
  String lastMatchLabel = '';

  /// True while the magic-tile fade animation is playing.
  /// Board input is blocked and gravity is deferred until the UI calls
  /// [applyMagicGravity] after the visual fade completes.
  bool isMagicAnimating = false;

  /// Sounds queued since the last notification; the UI reads and clears this.
  final List<SoundEvent> pendingSounds = [];

  GameController(this.config) {
    _initGame();
  }

  // ─── Initialisation ────────────────────────────────────────────────────

  void _initGame() {
    tilePool = _buildTilePool()..shuffle(Random());
    totalTiles = tilePool.length;
    clearedTiles = 0;
    board = List.generate(5, (_) => List.filled(7, null));
    handSlots = List.filled(config.handSlots, null);
    score = 0;
    isGameOver = false;
    isVictory = false;
    lastEffectMessage = null;
    lastMatchedTiles = [];
    lastMatchLabel = '';
    lastMagicRemovedTileIds = [];
    isMagicAnimating = false;
    pendingSounds.clear();
    _fillBoardFromPool();
  }

  List<Tile> _buildTilePool() {
    final tiles = <Tile>[];
    int idCtr = 0;
    String nextId() => '${idCtr++}';

    // Number tiles: man, pin, sou × 1-9 × 4 copies = 108
    for (final suit in [TileSuit.man, TileSuit.pin, TileSuit.sou]) {
      for (int n = 1; n <= 9; n++) {
        for (int c = 0; c < 4; c++) {
          tiles.add(Tile(id: nextId(), suit: suit, number: n));
        }
      }
    }

    if (config.hasMagicTiles) {
      // Wind tiles × 4 = 16
      for (final suit in [
        TileSuit.east, TileSuit.west, TileSuit.south, TileSuit.north,
      ]) {
        for (int c = 0; c < 4; c++) {
          tiles.add(Tile(id: nextId(), suit: suit));
        }
      }
      // Dragon tiles × 4 = 12
      for (final suit in [
        TileSuit.redDragon, TileSuit.whiteDragon, TileSuit.greenDragon,
      ]) {
        for (int c = 0; c < 4; c++) {
          tiles.add(Tile(id: nextId(), suit: suit));
        }
      }
    }
    return tiles;
  }

  void _fillBoardFromPool() {
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 7; c++) {
        if (board[r][c] == null && tilePool.isNotEmpty) {
          board[r][c] = tilePool.removeAt(0);
        }
      }
    }
  }

  // ─── Accessors ─────────────────────────────────────────────────────────

  int get boardTileCount =>
      board.fold(0, (sum, row) => sum + row.where((t) => t != null).length);

  int get handTileCount => handSlots.where((t) => t != null).length;

  int get handEmptySlots => handSlots.where((t) => t == null).length;

  bool get handFull => handEmptySlots == 0;

  int get tilesRemaining =>
      tilePool.length + boardTileCount + handTileCount;

  /// A tile is clickable if it has at least one exposed side (boundary or gap).
  bool isTileClickable(int row, int col) {
    if (board[row][col] == null) return false;
    // Outer edges: bottom row, left column, right column
    if (row == 4 || col == 0 || col == 6) return true;
    // Adjacent to an empty cell
    if (row > 0 && board[row - 1][col] == null) return true;
    if (row < 4 && board[row + 1][col] == null) return true;
    if (col > 0 && board[row][col - 1] == null) return true;
    if (col < 6 && board[row][col + 1] == null) return true;
    return false;
  }

  // ─── Player actions ────────────────────────────────────────────────────

  void selectTile(int row, int col) {
    if (isGameOver || isVictory || isMagicAnimating) return;
    if (!isTileClickable(row, col)) return;

    final tile = board[row][col]!;

    // Magic tiles are consumed immediately on click
    if (tile.isMagic && config.hasMagicTiles) {
      lastMagicRemovedTileIds = [tile.id]; // magic tile itself fades too
      lastMatchedTiles = [tile];            // drives the floating tile animation
      lastMatchLabel = 'Magic';
      board[row][col] = null;
      clearedTiles++;
      score += 10; // Magic tile itself
      _applyMagicEffect(tile, row, col);
      lastEffectMessage = _magicEffectName(tile);
      isMagicAnimating = true;
      // Gravity is deliberately deferred; the UI will call applyMagicGravity()
      // after the 1-second fade animation completes.
      _checkVictory();
      if (!isVictory) _checkGameOver();
      notifyListeners();
      return;
    }

    _addToHand(tile, row, col);
  }

  /// Called by the UI after the magic-tile ghost fade (1 s) has finished.
  /// Applies gravity/refill so that tiles drop to fill the cleared gaps.
  void applyMagicGravity() {
    if (!isMagicAnimating) return;
    isMagicAnimating = false;
    // Clear these so the next _onControllerUpdate doesn't re-spawn animations.
    lastMagicRemovedTileIds = [];
    lastMatchedTiles = [];
    lastMatchLabel = '';
    _applyGravityAndRefill();
    _checkVictory();
    if (!isVictory) _checkGameOver();
    notifyListeners();
  }

  void _addToHand(Tile tile, int row, int col) {
    if (handFull) return;
    final slot = handSlots.indexWhere((t) => t == null);
    board[row][col] = null;
    clearedTiles++;
    handSlots[slot] = tile;
    lastMatchedTiles = []; // cleared; set again if a match is found
    lastMatchLabel = '';
    lastEffectMessage = null; // reset; set again only if a match is found
    lastMagicRemovedTileIds = [];
    pendingSounds.add(SoundEvent.tileToHand);
    _resolveMatches();
    _afterTileRemoved();
  }

  // ─── Match resolution ──────────────────────────────────────────────────

  void _resolveMatches() {
    bool found = true;
    while (found) {
      found = _findAndRemovePung() || _findAndRemoveChow();
    }
  }

  bool _findAndRemovePung() {
    final Map<String, List<int>> groups = {};
    for (int i = 0; i < handSlots.length; i++) {
      if (handSlots[i] != null) {
        groups.putIfAbsent(handSlots[i]!.matchKey, () => []).add(i);
      }
    }
    for (final entry in groups.entries) {
      if (entry.value.length >= 3) {
        final indices = entry.value.take(3).toList();
        // Capture before removing — the UI will animate these departing tiles
        lastMatchedTiles = indices.map((i) => handSlots[i]!).toList();
        lastMatchLabel = 'Pung';
        for (final idx in indices) {
          handSlots[idx] = null;
        }
        score += 100;
        lastEffectMessage = 'Pung! +100';
        pendingSounds.add(SoundEvent.pung);
        return true;
      }
    }
    return false;
  }

  bool _findAndRemoveChow() {
    for (final suit in [TileSuit.man, TileSuit.pin, TileSuit.sou]) {
      // Gather (slotIndex, number) pairs for this suit
      final entries = <MapEntry<int, int>>[];
      for (int i = 0; i < handSlots.length; i++) {
        if (handSlots[i] != null && handSlots[i]!.suit == suit) {
          entries.add(MapEntry(i, handSlots[i]!.number));
        }
      }
      if (entries.length < 3) continue;
      entries.sort((a, b) => a.value.compareTo(b.value));
      // Try to find three consecutive numbers
      for (int i = 0; i < entries.length - 2; i++) {
        for (int j = i + 1; j < entries.length - 1; j++) {
          if (entries[j].value != entries[i].value + 1) continue;
          for (int k = j + 1; k < entries.length; k++) {
            if (entries[k].value != entries[j].value + 1) continue;
            // Found a sequence — capture before removing
            lastMatchedTiles = [
              handSlots[entries[i].key]!,
              handSlots[entries[j].key]!,
              handSlots[entries[k].key]!,
            ];
            lastMatchLabel = 'Chow';
            handSlots[entries[i].key] = null;
            handSlots[entries[j].key] = null;
            handSlots[entries[k].key] = null;
            score += 30;
            lastEffectMessage = 'Chow! +30';
            pendingSounds.add(SoundEvent.chow);
            return true;
          }
        }
      }
    }
    return false;
  }

  // ─── Magic effects ─────────────────────────────────────────────────────

  void _applyMagicEffect(Tile tile, int trigRow, int trigCol) {
    void rm(int r, int c) {
      if (r < 0 || r >= 5 || c < 0 || c >= 7) return;
      if (board[r][c] != null) {
        lastMagicRemovedTileIds.add(board[r][c]!.id);
        board[r][c] = null;
        clearedTiles++;
        score += 10;
      }
    }

    switch (tile.suit) {
      case TileSuit.east: // Clear self's row to the right
        pendingSounds.add(SoundEvent.magicWind);
        for (int c = trigCol + 1; c < 7; c++) { rm(trigRow, c); }
        break;

      case TileSuit.west: // Clear self's row to the left
        pendingSounds.add(SoundEvent.magicWind);
        for (int c = trigCol - 1; c >= 0; c--) { rm(trigRow, c); }
        break;

      case TileSuit.south: // Clear self's column downward
        pendingSounds.add(SoundEvent.magicWind);
        for (int r = trigRow + 1; r < 5; r++) { rm(r, trigCol); }
        break;

      case TileSuit.north: // Clear self's column upward
        pendingSounds.add(SoundEvent.magicWind);
        for (int r = trigRow - 1; r >= 0; r--) { rm(r, trigCol); }
        break;

      case TileSuit.redDragon: // Clear 4 orthogonal neighbours
        pendingSounds.add(SoundEvent.magicWind);
        rm(trigRow - 1, trigCol);
        rm(trigRow + 1, trigCol);
        rm(trigRow, trigCol - 1);
        rm(trigRow, trigCol + 1);
        break;

      case TileSuit.whiteDragon: // Clear all 8 surrounding neighbours (including diagonals)
        pendingSounds.add(SoundEvent.magicDisappear);
        rm(trigRow - 1, trigCol - 1);
        rm(trigRow - 1, trigCol);
        rm(trigRow - 1, trigCol + 1);
        rm(trigRow,     trigCol - 1);
        rm(trigRow,     trigCol + 1);
        rm(trigRow + 1, trigCol - 1);
        rm(trigRow + 1, trigCol);
        rm(trigRow + 1, trigCol + 1);
        break;

      case TileSuit.greenDragon: // Shuffle tiles and refill board
        pendingSounds.add(SoundEvent.magicShuffle);
        _shuffleAndRefill();
        break;

      default:
        break;
    }
  }

  String _magicEffectName(Tile tile) {
    switch (tile.suit) {
      case TileSuit.east:
        return 'East Wind — row cleared right!';
      case TileSuit.west:
        return 'West Wind — row cleared left!';
      case TileSuit.south:
        return 'South Wind — column cleared down!';
      case TileSuit.north:
        return 'North Wind — column cleared up!';
      case TileSuit.redDragon:
        return 'The Blast — 4 neighbours cleared!';
      case TileSuit.whiteDragon:
        return 'Pure Void — 8 surrounding tiles cleared!';
      case TileSuit.greenDragon:
        return 'Fortune — board shuffled!';
      default:
        return '';
    }
  }

  void _shuffleAndRefill() {
    // Collect all board tiles and remaining pool tiles, shuffle, redistribute
    final all = <Tile>[];
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 7; c++) {
        if (board[r][c] != null) {
          all.add(board[r][c]!);
          board[r][c] = null;
        }
      }
    }
    all.addAll(tilePool);
    tilePool.clear();
    all.shuffle(Random());
    int idx = 0;
    for (int r = 0; r < 5 && idx < all.length; r++) {
      for (int c = 0; c < 7 && idx < all.length; c++) {
        board[r][c] = all[idx++];
      }
    }
    while (idx < all.length) {
      tilePool.add(all[idx++]);
    }
  }

  // ─── Post-removal bookkeeping ──────────────────────────────────────────

  void _afterTileRemoved() {
    _applyGravityAndRefill();
    _checkVictory();
    if (!isVictory) _checkGameOver();
    notifyListeners();
  }

  /// Gravity: each column's tiles fall to the bottom, then pool tiles
  /// refill any empty slots at the top of each column.
  void _applyGravityAndRefill() {
    for (int col = 0; col < 7; col++) {
      // Collect existing tiles in this column, top → bottom order
      final column = <Tile>[];
      for (int row = 0; row < 5; row++) {
        if (board[row][col] != null) column.add(board[row][col]!);
      }
      // Prepend pool tiles to fill empty top slots
      while (column.length < 5 && tilePool.isNotEmpty) {
        column.insert(0, tilePool.removeAt(0));
      }
      // Write back: empty rows at the top, tiles gravity-settled at the bottom
      final emptyRows = 5 - column.length;
      for (int row = 0; row < 5; row++) {
        board[row][col] = row < emptyRows ? null : column[row - emptyRows];
      }
    }
  }

  void _checkVictory() {
    if (tilePool.isEmpty &&
        boardTileCount == 0 &&
        handTileCount == 0) {
      isVictory = true;
      pendingSounds.add(SoundEvent.gameEnd);
    }
  }

  void _checkGameOver() {
    // Defeat: hand is full and cannot accept any more tiles
    if (handFull) {
      isGameOver = true;
      pendingSounds.add(SoundEvent.gameEnd);
    }
  }

  // ─── Restart ───────────────────────────────────────────────────────────

  void restart() {
    _initGame();
    notifyListeners();
  }

  /// Called by the UI after it has consumed all queued sounds.
  void clearPendingSounds() => pendingSounds.clear();
}
