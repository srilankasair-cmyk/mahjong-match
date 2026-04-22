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

  /// Kong tracking: set after a Pung so the very next click on the same tile
  /// type triggers a Kong (+500).
  bool _pungReadyForKong = false;
  String? _lastPungMatchKey;

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
    _pungReadyForKong = false;
    _lastPungMatchKey = null;
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
      _pungReadyForKong = false;
      _lastPungMatchKey = null;
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

    // Kong: after a Pung, if the very next click matches the Pung tile → +500
    if (_pungReadyForKong && tile.matchKey == _lastPungMatchKey) {
      board[row][col] = null;
      clearedTiles++;
      score += 500;
      lastEffectMessage = 'Kong! +500';
      lastMatchLabel = 'Kong';
      lastMatchedTiles = [tile];
      lastMagicRemovedTileIds = [];
      _pungReadyForKong = false;
      _lastPungMatchKey = null;
      pendingSounds.add(SoundEvent.pung);
      _afterTileRemoved();
      return;
    }

    // Any non-Kong normal tile click resets the Kong opportunity
    _pungReadyForKong = false;
    _lastPungMatchKey = null;

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
        final pungKey = entry.key;
        for (final idx in indices) {
          handSlots[idx] = null;
        }
        score += 100;
        lastEffectMessage = 'Pung! +100';
        pendingSounds.add(SoundEvent.pung);
        // Enable Kong: next click on the same tile type triggers +500
        _lastPungMatchKey = pungKey;
        _pungReadyForKong = true;
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
    // Moves a board tile to the end of tilePool (tile is deferred, not cleared).
    void moveToPool(int r, int c) {
      if (r < 0 || r >= 5 || c < 0 || c >= 7) return;
      if (board[r][c] != null) {
        lastMagicRemovedTileIds.add(board[r][c]!.id);
        tilePool.add(board[r][c]!); // send to END of pool
        board[r][c] = null;
        // Do NOT increment clearedTiles — the tile will return from the pool.
      }
    }

    switch (tile.suit) {
      case TileSuit.east: // Remove self; send the tile immediately to the RIGHT to pool
        pendingSounds.add(SoundEvent.magicWind);
        moveToPool(trigRow, trigCol + 1);
        break;

      case TileSuit.west: // Remove self; send the tile immediately to the LEFT to pool
        pendingSounds.add(SoundEvent.magicWind);
        moveToPool(trigRow, trigCol - 1);
        break;

      case TileSuit.south: // Remove self; send the tile directly BELOW to pool
        pendingSounds.add(SoundEvent.magicWind);
        moveToPool(trigRow + 1, trigCol);
        break;

      case TileSuit.north: // Remove self; send the tile directly ABOVE to pool
        pendingSounds.add(SoundEvent.magicWind);
        moveToPool(trigRow - 1, trigCol);
        break;

      case TileSuit.redDragon: // 中 — send 4 orthogonal neighbours to pool (up→down→left→right)
        pendingSounds.add(SoundEvent.magicWind);
        moveToPool(trigRow - 1, trigCol); // up
        moveToPool(trigRow + 1, trigCol); // down
        moveToPool(trigRow, trigCol - 1); // left
        moveToPool(trigRow, trigCol + 1); // right
        break;

      case TileSuit.whiteDragon: // 白板 — send surrounding 8 tiles to pool (clockwise)
        pendingSounds.add(SoundEvent.magicDisappear);
        moveToPool(trigRow - 1, trigCol - 1); // top-left
        moveToPool(trigRow - 1, trigCol);     // top
        moveToPool(trigRow - 1, trigCol + 1); // top-right
        moveToPool(trigRow,     trigCol + 1); // right
        moveToPool(trigRow + 1, trigCol + 1); // bottom-right
        moveToPool(trigRow + 1, trigCol);     // bottom
        moveToPool(trigRow + 1, trigCol - 1); // bottom-left
        moveToPool(trigRow,     trigCol - 1); // left
        break;

      case TileSuit.greenDragon: // 发财 — shuffle all tiles on screen and fill every empty slot
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
        return 'East Wind — right tile sent to pool!';
      case TileSuit.west:
        return 'West Wind — left tile sent to pool!';
      case TileSuit.south:
        return 'South Wind — tile below sent to pool!';
      case TileSuit.north:
        return 'North Wind — tile above sent to pool!';
      case TileSuit.redDragon:
        return '中 — 4 neighbours sent to pool!';
      case TileSuit.whiteDragon:
        return '白板 — 8 surrounding tiles sent to pool!';
      case TileSuit.greenDragon:
        return '发财 — board shuffled and refilled!';
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
    if (tilePool.isNotEmpty || boardTileCount != 0) return;
    // Pool and board are exhausted — win if hand is clear OR hand is stuck
    if (handTileCount == 0 || !_canHandFormAnyMatch()) {
      isVictory = true;
      pendingSounds.add(SoundEvent.gameEnd);
    }
  }

  /// Returns true if the current hand tiles can still form at least one Pung
  /// or Chow, i.e. there are moves left to play.
  bool _canHandFormAnyMatch() {
    // Check Pung: 3 tiles with the same matchKey
    final counts = <String, int>{};
    for (final tile in handSlots) {
      if (tile == null) continue;
      counts[tile.matchKey] = (counts[tile.matchKey] ?? 0) + 1;
      if (counts[tile.matchKey]! >= 3) return true;
    }

    // Check Chow: 3 consecutive numbers within the same suit
    for (final suit in [TileSuit.man, TileSuit.pin, TileSuit.sou]) {
      final nums = handSlots
          .where((t) => t != null && t.suit == suit)
          .map((t) => t!.number)
          .toList()
        ..sort();
      for (int i = 0; i < nums.length - 2; i++) {
        for (int j = i + 1; j < nums.length - 1; j++) {
          if (nums[j] != nums[i] + 1) continue;
          for (int k = j + 1; k < nums.length; k++) {
            if (nums[k] == nums[j] + 1) return true;
          }
        }
      }
    }

    return false;
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
