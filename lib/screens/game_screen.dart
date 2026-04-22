import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/game_controller.dart';
import '../models/game_config.dart';
import '../models/tile.dart';
import '../services/audio_service.dart';
import 'rules_screen.dart';

class GameScreen extends StatefulWidget {
  final GameConfig config;
  const GameScreen({super.key, required this.config});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  String? _effectMessage;
  Timer? _effectTimer;
  bool _navigating = false;

  // Animation state: tracks the display position of every tile on the board.
  // (row, col) — row can be -1 for tiles entering from above the board.
  final Map<String, (int, int)> _tilePositions = {};
  // Tile objects by id, kept alive so we can render tiles that are mid-animation.
  final Map<String, Tile> _tiles = {};

  // Active "tiles floating away" animations (one per Pung/Chow event).
  final List<_MatchAnimData> _matchAnims = [];

  // IDs of magic-eliminated tiles currently fading out (semi-transparent ghost).
  final Set<String> _fadingMagicIds = {};
  Timer? _magicFadeTimer;

  @override
  void initState() {
    super.initState();
    _controller = GameController(widget.config);
    // Snapshot initial board positions without animation
    _syncPositionsInstant();
    _controller.addListener(_onControllerUpdate);
    // Switch to in-game BGM
    AudioService.instance.playGameBgm();
  }

  @override
  void dispose() {
    _effectTimer?.cancel();
    _magicFadeTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    // Return to menu BGM when leaving the game screen
    AudioService.instance.playMenuBgm();
    super.dispose();
  }

  /// Called once at startup — fills _tilePositions directly from the board
  /// (no animation needed for the initial layout).
  void _syncPositionsInstant() {
    _tilePositions.clear();
    _tiles.clear();
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 7; c++) {
        final t = _controller.board[r][c];
        if (t != null) {
          _tilePositions[t.id] = (r, c);
          _tiles[t.id] = t;
        }
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    // Effect message
    if (_controller.lastEffectMessage != null) {
      _effectMessage = _controller.lastEffectMessage;
      _effectTimer?.cancel();
      _effectTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _effectMessage = null);
      });
    }

    // Spawn a floating-away animation for the tiles just matched
    if (_controller.lastMatchedTiles.isNotEmpty) {
      _matchAnims.add(_MatchAnimData(
        id: DateTime.now().microsecondsSinceEpoch,
        tiles: List.of(_controller.lastMatchedTiles),
        label: _controller.lastMatchLabel,
      ));
    }

    // Capture positions of magic-eliminated tiles BEFORE updating _tilePositions,
    // so they can be rendered as semi-transparent ghosts for 1 second.
    if (_controller.lastMagicRemovedTileIds.isNotEmpty) {
      for (final id in _controller.lastMagicRemovedTileIds) {
        if (_tilePositions.containsKey(id)) {
          _fadingMagicIds.add(id);
        }
      }
      _magicFadeTimer?.cancel();
      _magicFadeTimer = Timer(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        setState(() {
          for (final id in _fadingMagicIds) {
            _tilePositions.remove(id);
            _tiles.remove(id);
          }
          _fadingMagicIds.clear();
        });
        // Gravity runs after the ghosts have visually disappeared.
        _controller.applyMagicGravity();
      });
    }

    // Build the target positions from the controller's current board state
    final target = <String, (int, int)>{};
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 7; c++) {
        final t = _controller.board[r][c];
        if (t != null) {
          target[t.id] = (r, c);
          _tiles[t.id] = t; // register tile object
        }
      }
    }

    // Identify tiles that are brand-new (entering from pool this update)
    final newIds = target.keys.where((id) => !_tilePositions.containsKey(id)).toSet();

    // Remove tiles that left the board (but keep fading magic ghosts alive)
    _tilePositions.removeWhere(
      (id, _) => !target.containsKey(id) && !_fadingMagicIds.contains(id),
    );

    // For new tiles: place them one row above wherever they will end up.
    // We'll animate them to their real rows in a post-frame callback.
    for (final id in newIds) {
      _tilePositions[id] = (-1, target[id]!.$2);
    }

    // Update positions of existing tiles (AnimatedPositioned will tween these)
    for (final id in target.keys) {
      if (!newIds.contains(id)) {
        _tilePositions[id] = target[id]!;
      }
    }

    // First render: existing tiles start animating, new tiles sit at row -1
    setState(() {});

    // Play all queued sound effects (staggered by 120 ms so a chain feels satisfying)
    final sounds = List.of(_controller.pendingSounds);
    _controller.clearPendingSounds();
    for (int i = 0; i < sounds.length; i++) {
      if (i == 0) {
        AudioService.instance.playSfx(sounds[i]);
      } else {
        Future.delayed(Duration(milliseconds: i * 120), () {
          if (mounted) AudioService.instance.playSfx(sounds[i]);
        });
      }
    }

    // Second render (next frame): animate new tiles into their real positions
    if (newIds.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          for (final id in newIds) {
            if (target.containsKey(id)) {
              _tilePositions[id] = target[id]!;
            }
          }
        });
      });
    }

    // Navigate to result screen after a short delay
    if (!_navigating && (_controller.isVictory || _controller.isGameOver)) {
      _navigating = true;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/result',
          arguments: ResultArgs(
            score: _controller.score,
            level: widget.config.mode,
            isVictory: _controller.isVictory,
          ),
        );
      });
    }
  }

  void _showRules(BuildContext context) => showRulesDialog(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          widget.config.displayName,
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: Colors.black,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, size: 20),
            color: Colors.black54,
            tooltip: 'How to Play',
            onPressed: () => _showRules(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_controller.score}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const Text(
                    'pts',
                    style: TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, outerConstraints) {
                final isWide = outerConstraints.maxWidth >= 600;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: isWide
                        ? _buildWideLayout()
                        : _buildNarrowLayout(),
                  ),
                );
              },
            ),
            // Floating "tiles departing" animations — pointer events pass through
            IgnorePointer(
              child: Stack(
                children: [
                  for (final anim in _matchAnims)
                    _FloatingMatchAnim(
                      key: ValueKey(anim.id),
                      anim: anim,
                      // Only attach the toast to the most-recent animation so
                      // it moves together below the departing tiles.
                      effectMessage: anim == _matchAnims.last
                          ? _effectMessage
                          : null,
                      onDone: () {
                        if (!mounted) return;
                        setState(() {
                          final wasLast =
                              _matchAnims.isNotEmpty &&
                              _matchAnims.last == anim;
                          _matchAnims.remove(anim);
                          // When the final animation completes, kill the toast
                          // immediately so the static fallback never flashes in.
                          if (wasLast && _matchAnims.isEmpty) {
                            _effectMessage = null;
                            _effectTimer?.cancel();
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            // Fallback toast shown when there is no floating animation
            // (e.g. magic-tile effect messages).
            if (_effectMessage != null && _matchAnims.isEmpty)
              Positioned(
                bottom: 62,
                left: 0,
                right: 0,
                child: Center(
                  child: IgnorePointer(
                    child: _EffectToast(message: _effectMessage!),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Narrow layout ───────────────────────────────────────────────────────

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _buildProgressBar(),
        Expanded(child: _buildBoardArea()),
        _buildHandSection(),
      ],
    );
  }

  // ─── Wide layout ─────────────────────────────────────────────────────────

  Widget _buildWideLayout() {
    return Column(
      children: [
        _buildProgressBar(),
        Expanded(child: _buildBoardArea()),
        _buildHandSection(),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black45,
        fontSize: 10,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ─── Progress bar ────────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    final total = _controller.totalTiles;
    final cleared = _controller.clearedTiles;
    final progress = total > 0 ? cleared / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.layers_rounded, color: Colors.black38, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.black12,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_controller.tilesRemaining} left',
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─── Game board (Stack + AnimatedPositioned for fall animation) ───────────

  Widget _buildBoardArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const hPad = 8.0;
        const colGap = 3.0;
        const rowGap = 3.0;
        final availableWidth = constraints.maxWidth - hPad * 2;
        final tileW = (availableWidth - colGap * 6) / 7;
        final tileH = tileW * 1.4;

        // Board dimensions (exactly 5 rows × 7 cols of tiles)
        final boardW = availableWidth;
        final boardH = tileH * 5 + rowGap * 4;

        double tileLeft(int col) => hPad + col * (tileW + colGap);
        double tileTop(int row)  => row * (tileH + rowGap);

        return Stack(
          children: [
            // Fixed-size board clipping area (clips tiles entering from above)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ClipRect(
                child: SizedBox(
                  width: boardW + hPad * 2,
                  height: boardH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Empty slot grid (static background)
                      for (int r = 0; r < 5; r++)
                        for (int c = 0; c < 7; c++)
                          Positioned(
                            left: tileLeft(c),
                            top: tileTop(r),
                            width: tileW,
                            height: tileH,
                            child: _EmptySlot(
                              width: tileW,
                              height: tileH,
                            ),
                          ),

                      // Animated tiles
                      for (final entry in _tilePositions.entries)
                        _buildAnimatedTile(
                          entry.key,
                          entry.value,
                          tileW,
                          tileH,
                          tileLeft,
                          tileTop,
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Game-end overlay
            if (_controller.isVictory || _controller.isGameOver)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      _controller.isVictory ? '🏆 Victory!' : '😔 Game Over',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(1, 2))
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedTile(
    String tileId,
    (int, int) pos,
    double tileW,
    double tileH,
    double Function(int) tileLeft,
    double Function(int) tileTop,
  ) {
    final tile = _tiles[tileId];
    if (tile == null) return const SizedBox.shrink();

    // Find the actual board position (for clickability check)
    // We look up the CURRENT controller board, not the animated position
    int? boardRow, boardCol;
    for (int r = 0; r < 5; r++) {
      for (int c = 0; c < 7; c++) {
        if (_controller.board[r][c]?.id == tileId) {
          boardRow = r;
          boardCol = c;
        }
      }
    }

    // If tile is not on the board (mid-animation after removal), render non-clickable.
    // Fading magic tiles are rendered at reduced opacity for the ghost effect.
    if (boardRow == null || boardCol == null) {
      final isFading = _fadingMagicIds.contains(tileId);
      return AnimatedPositioned(
        key: ValueKey(tileId),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        left: tileLeft(pos.$2),
        top: tileTop(pos.$1),
        width: tileW,
        height: tileH,
        child: AnimatedOpacity(
          opacity: isFading ? 0.35 : 1.0,
          duration: const Duration(milliseconds: 250),
          child: _TileCell(tile: tile, clickable: false, width: tileW, height: tileH),
        ),
      );
    }

    final row = boardRow;
    final col = boardCol;
    final clickable = !_controller.isGameOver &&
        !_controller.isVictory &&
        _controller.isTileClickable(row, col);

    final faceDown = widget.config.isNightmare && !clickable;

    return AnimatedPositioned(
      key: ValueKey(tileId),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      left: tileLeft(pos.$2),
      top: tileTop(pos.$1),
      width: tileW,
      height: tileH,
      child: GestureDetector(
        onTap: clickable
            ? () => _controller.selectTile(row, col)
            : null,
        child: _TileCell(
          tile: tile,
          clickable: clickable,
          width: tileW,
          height: tileH,
          faceDown: faceDown,
        ),
      ),
    );
  }

  // ─── Hand slots ──────────────────────────────────────────────────────────

  Widget _buildHandSection() {
    return Container(
      color: const Color(0xFFD8D8D8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const colGap = 3.0;
          const slotsPerRow = 7;
          final availableWidth = constraints.maxWidth - 16;
          final tileWidth = (availableWidth - colGap * 6) / 7;
          final tileHeight = tileWidth * 1.4;

          final slots = _controller.handSlots;
          final totalSlots = slots.length;
          final rows = (totalSlots / slotsPerRow).ceil();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionLabel('HAND  (${_controller.handTileCount}/$totalSlots)'),
              const SizedBox(height: 5),
              for (int r = 0; r < rows; r++)
                Padding(
                  padding: EdgeInsets.only(bottom: r < rows - 1 ? 3 : 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(slotsPerRow, (c) {
                      final idx = r * slotsPerRow + c;
                      if (idx >= totalSlots) {
                        return Padding(
                          padding: EdgeInsets.only(
                              right: c < slotsPerRow - 1 ? colGap : 0),
                          child: SizedBox(
                              width: tileWidth, height: tileHeight),
                        );
                      }
                      final tile = slots[idx];
                      return Padding(
                        padding: EdgeInsets.only(
                            right: c < slotsPerRow - 1 ? colGap : 0),
                        child: _TileCell(
                          tile: tile,
                          clickable: false,
                          width: tileWidth,
                          height: tileHeight,
                          isHandSlot: true,
                        ),
                      );
                    }),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Empty slot widget ────────────────────────────────────────────────────────

class _EmptySlot extends StatelessWidget {
  final double width;
  final double height;
  const _EmptySlot({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ─── Tile cell widget ────────────────────────────────────────────────────────

// Spritesheet layout:
//   Row 0 (y=22,  h=146): sou  1-9
//   Row 1 (y=230, h=147): pin  1-9
//   Row 2 (y=441, h=146): man  1-9
//   Row 3 (y=646, h=148): east, south, west, north
//   Row 4 (y=856, h=147): redDragon, greenDragon, whiteDragon
// Columns: x = 20 + col * 111,  tile width = 104 px

(int, int) _spriteCoord(TileSuit suit, int number) {
  switch (suit) {
    case TileSuit.sou:         return (number - 1, 0);
    case TileSuit.pin:         return (number - 1, 1);
    case TileSuit.man:         return (number - 1, 2);
    case TileSuit.east:        return (0, 3);
    case TileSuit.south:       return (1, 3);
    case TileSuit.west:        return (2, 3);
    case TileSuit.north:       return (3, 3);
    case TileSuit.redDragon:   return (0, 4);
    case TileSuit.greenDragon: return (1, 4);
    case TileSuit.whiteDragon: return (2, 4);
  }
}

Widget _tileSprite(Tile tile, double dstW, double dstH) {
  const double sheetW  = 1024;
  const double sheetH  = 1024;
  const double srcX0   = 20.0;
  const double srcStep = 111.0;
  const double srcTileW = 104.0;
  const List<double> rowY = [22,  230, 441, 646, 856];
  const List<double> rowH = [146, 147, 146, 148, 147];

  final (col, row) = _spriteCoord(tile.suit, tile.number);
  final srcX = srcX0 + col * srcStep;
  final srcY = rowY[row];
  final srcH = rowH[row];
  final sx   = dstW / srcTileW;
  final sy   = dstH / srcH;

  return ClipRect(
    child: OverflowBox(
      alignment: Alignment.topLeft,
      maxWidth:  sheetW * sx,
      maxHeight: sheetH * sy,
      child: Transform.translate(
        offset: Offset(-srcX * sx, -srcY * sy),
        child: Image.asset(
          'assets/images/tiles.png',
          width:  sheetW * sx,
          height: sheetH * sy,
          fit: BoxFit.fill,
        ),
      ),
    ),
  );
}

class _TileCell extends StatelessWidget {
  final Tile? tile;
  final bool clickable;
  final double width;
  final double height;
  final bool isHandSlot;
  final bool faceDown;

  const _TileCell({
    required this.tile,
    required this.clickable,
    required this.width,
    required this.height,
    this.isHandSlot = false,
    this.faceDown = false,
  });

  @override
  Widget build(BuildContext context) {
    if (tile == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isHandSlot ? const Color(0x0F000000) : Colors.black12,
          borderRadius: BorderRadius.circular(4),
          border: isHandSlot
              ? Border.all(color: Colors.black12, width: 0.8)
              : null,
        ),
      );
    }

    // Nightmare mode: locked tiles are rendered face-down (content hidden).
    if (faceDown) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32),
          borderRadius: BorderRadius.circular(3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 3,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(width * 0.14),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1B5E20), width: 1.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    // Active (clickable) tiles: full opacity. Inactive: dimmed.
    // No extra border is added for active state per the game rules.
    return Opacity(
      opacity: clickable || isHandSlot ? 1.0 : 0.55,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: clickable
              ? const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 3,
                    offset: Offset(1, 2),
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: _tileSprite(tile!, width, height),
        ),
      ),
    );
  }
}

// ─── Match animation data ─────────────────────────────────────────────────────

class _MatchAnimData {
  final int id;
  final List<Tile> tiles;
  final String label;
  _MatchAnimData({required this.id, required this.tiles, required this.label});
}

// ─── Floating match animation widget ─────────────────────────────────────────
//
// Shows the three matched tiles rising up from the hand area and fading away.
// Timeline (total 1 700 ms):
//   0 – 18 %  (0.3 s) : appear + start floating up
//   18 – 76 % (1.0 s) : hover / slow drift  ← the 1 s the user asked for
//   76 – 100% (0.4 s) : fade out while continuing upward

class _FloatingMatchAnim extends StatefulWidget {
  final _MatchAnimData anim;
  final String? effectMessage;
  final VoidCallback onDone;

  const _FloatingMatchAnim({
    required super.key,
    required this.anim,
    required this.onDone,
    this.effectMessage,
  });

  @override
  State<_FloatingMatchAnim> createState() => _FloatingMatchAnimState();
}

class _FloatingMatchAnimState extends State<_FloatingMatchAnim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<double> _dy; // px upward (negative = up)

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward().then((_) {
        if (mounted) widget.onDone();
      });

    // Opacity: fade in → hold → fade out
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 18),
      TweenSequenceItem(tween: ConstantTween(1.0),           weight: 58),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 24),
    ]).animate(_ctrl);

    // Vertical travel: quick rise → hover drift → continue out
    _dy = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0,   end: -50.0),  weight: 18),
      TweenSequenceItem(tween: Tween(begin: -50.0, end: -80.0),  weight: 58),
      TweenSequenceItem(tween: Tween(begin: -80.0, end: -110.0), weight: 24),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tile size mirrors the hand-slot proportions at a fixed reference width
    const tileW = 46.0;
    const tileH = tileW * 1.4;

    return Positioned(
      left: 0,
      right: 0,
      // Start above the hand section (approx. 120 px from the bottom
      // of the SafeArea covers both 1-row and 2-row hand layouts)
      bottom: 120,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) => Opacity(
            opacity: _opacity.value,
            child: Transform.translate(
              offset: Offset(0, _dy.value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tiles row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < widget.anim.tiles.length; i++) ...[
                        if (i > 0) const SizedBox(width: 5),
                        Container(
                          width: tileW,
                          height: tileH,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: _tileSprite(
                              widget.anim.tiles[i],
                              tileW,
                              tileH,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Toast label follows below the tiles in the same transform
                  if (widget.effectMessage != null) ...[
                    const SizedBox(height: 6),
                    _EffectToast(message: widget.effectMessage!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Effect toast widget ──────────────────────────────────────────────────────
//
// Shared pill used both inside _FloatingMatchAnim (moves with tiles) and
// as a standalone overlay for magic-effect messages.

class _EffectToast extends StatelessWidget {
  final String message;
  const _EffectToast({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFFEE58),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

