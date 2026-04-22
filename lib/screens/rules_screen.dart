import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/tile.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

void showRulesDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (_) => const _RulesFullDialog(),
  );
}

// ── Colours ───────────────────────────────────────────────────────────────────

const Color _kPageBg    = Color(0xFFF8F8F8);
const Color _kCardBg    = Colors.white;
const Color _kText      = Colors.black;
const Color _kDivider   = Color(0xFFE0E0E0);
const Color _kGold      = Color(0xFFCF8E00);

// ── Sprite sheet constants ────────────────────────────────────────────────────

const double _sheetW   = 1024;
const double _sheetH   = 1024;
const double _srcX0    = 20.0;
const double _srcStep  = 111.0;
const double _srcTileW = 104.0;
const List<double> _rowY = [22.0, 230.0, 441.0, 646.0, 856.0];
const List<double> _rowH = [146.0, 147.0, 146.0, 148.0, 147.0];

/// Render a specific tile from the sprite sheet.
/// [row] 0=sou 1=pin 2=man 3=winds 4=dragons
/// [col] 0-8 for numbered tiles; 0-3 for winds; 0-2 for dragons
Widget _tileAt({
  required int row,
  required int col,
  required double dstW,
  required double dstH,
}) {
  final srcX = _srcX0 + col * _srcStep;
  final srcY = _rowY[row];
  final sh   = _rowH[row];
  final sx   = dstW / _srcTileW;
  final sy   = dstH / sh;

  return ClipRect(
    child: OverflowBox(
      alignment: Alignment.topLeft,
      maxWidth:  _sheetW * sx,
      maxHeight: _sheetH * sy,
      child: Transform.translate(
        offset: Offset(-srcX * sx, -srcY * sy),
        child: Image.asset(
          'assets/images/tiles.png',
          width:  _sheetW * sx,
          height: _sheetH * sy,
          fit: BoxFit.fill,
        ),
      ),
    ),
  );
}

/// Render a tile by [TileSuit].
Widget _tileSprite({
  required TileSuit suit,
  required double dstW,
  required double dstH,
}) {
  int col; int row;
  switch (suit) {
    case TileSuit.sou:         col = 0; row = 0;
    case TileSuit.pin:         col = 0; row = 1;
    case TileSuit.man:         col = 0; row = 2;
    case TileSuit.east:        col = 0; row = 3;
    case TileSuit.south:       col = 1; row = 3;
    case TileSuit.west:        col = 2; row = 3;
    case TileSuit.north:       col = 3; row = 3;
    case TileSuit.redDragon:   col = 0; row = 4;
    case TileSuit.greenDragon: col = 1; row = 4;
    case TileSuit.whiteDragon: col = 2; row = 4;
  }
  return _tileAt(row: row, col: col, dstW: dstW, dstH: dstH);
}

// ── Dialog shell ──────────────────────────────────────────────────────────────

class _RulesFullDialog extends StatelessWidget {
  const _RulesFullDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: _kPageBg,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                const _RulesHeader(),
                const Divider(height: 1, thickness: 1, color: _kDivider),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: const [
                        _BasicsCard(),
                        SizedBox(height: 12),
                        _ScoringCard(),
                        SizedBox(height: 12),
                        _IdentifyCard(),
                        SizedBox(height: 12),
                        _MagicCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fixed header ──────────────────────────────────────────────────────────────

class _RulesHeader extends StatelessWidget {
  const _RulesHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Rules',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: _kText,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: _kText),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section card base ─────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(19, 29, 19, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.playfairDisplay(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: _kText,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: _kDivider),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

// ── 🎮 THE BASICS ─────────────────────────────────────────────────────────────

class _BasicsCard extends StatelessWidget {
  const _BasicsCard();

  @override
  Widget build(BuildContext context) {
    final body = GoogleFonts.inter(fontSize: 16, height: 1.55, color: _kText);
    final bold = GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, height: 1.55, color: _kText);

    return _SectionCard(
      title: '🎮 THE BASICS',
      children: [
        // ── The Board ──
        Text('The Board',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(style: body, children: [
            const TextSpan(text: 'You draw tiles from the '),
            TextSpan(text: 'outer edges', style: bold),
            const TextSpan(text: ' of a 7×5 grid into your hand area. Only tiles exposed on the edges can be selected.'),
          ]),
        ),
        const SizedBox(height: 14),
        // 7×5 board illustration
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/board_diagram.png',
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),

        const SizedBox(height: 20),

        // ── Your Hand & Refilling ──
        Text('Your Hand & Refilling',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(style: body, children: [
            const TextSpan(text: 'Tiles in your hand area can form "'),
            TextSpan(text: 'Chow', style: bold),
            const TextSpan(text: '" or "'),
            TextSpan(text: 'Pung', style: bold),
            const TextSpan(text: '" to score points and clear those tiles.'),
          ]),
        ),
        const SizedBox(height: 14),
        // Hand & refilling illustration
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/clear_diagram.png',
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 20),

        // ── How to Win ──
        Text('How to Win',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(style: body, children: [
            const TextSpan(text: 'Clear all tiles from the board and hand to win. You also win if the draw area runs out of tiles and your remaining hand tiles can no longer form a '),
            TextSpan(text: 'Chow', style: bold),
            const TextSpan(text: ' or '),
            TextSpan(text: 'Pung', style: bold),
            const TextSpan(text: '.'),
          ]),
        ),
      ],
    );
  }
}

// ── 🀄 SCORING & MATCHES ──────────────────────────────────────────────────────

class _ScoringCard extends StatelessWidget {
  const _ScoringCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '🏆 SCORING & MATCHES',
      children: [
        Text(
          'Match tiles in your hand to score points and clear space:',
          style: GoogleFonts.inter(fontSize: 16, height: 1.55, color: _kText),
        ),
        const SizedBox(height: 20),

        // ── Chow ──
        Text('Chow (Sequence)',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 6),
        Text('3 consecutive tiles of the same suit',
            style: GoogleFonts.inter(fontSize: 16, height: 1.55, color: _kText)),
        const SizedBox(height: 4),
        Text('+30 points',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic, color: _kGold)),
        const SizedBox(height: 12),
        // Chow tiles: bamboo 1, 2, 3 (row=0, col=0/1/2)
        const _TileRow(entries: [(0, 0), (0, 1), (0, 2)]),

        const SizedBox(height: 24),

        // ── Pung ──
        Text('Pung (Triplet)',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 6),
        Text('3 identical tiles',
            style: GoogleFonts.inter(fontSize: 16, height: 1.55, color: _kText)),
        const SizedBox(height: 4),
        Text('+100 points',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic, color: _kGold)),
        const SizedBox(height: 12),
        // Pung tiles: 3× dots-1 (row=1, col=0)
        const _TileRow(entries: [(1, 0), (1, 0), (1, 0)]),

        const SizedBox(height: 24),

        // ── Kong ──
        Text('Kong (Quad)',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: GoogleFonts.inter(fontSize: 16, height: 1.55, color: _kText),
            children: [
              const TextSpan(text: 'After a '),
              TextSpan(text: 'Pung', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, height: 1.55, color: _kText)),
              const TextSpan(text: ', if your very next tile click is the same type as the Pung, it triggers a Kong. The 4th tile is consumed instantly.'),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('+500 points',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic, color: _kGold)),
        const SizedBox(height: 12),
        // Kong tiles: 4× dots-1 (row=1, col=0)
        const _TileRow(entries: [(1, 0), (1, 0), (1, 0), (1, 0)]),

        const SizedBox(height: 24),

        // ── Pro Tips ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDE7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡 PRO TIPS',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
              const SizedBox(height: 8),
              Text(
                'Focus on forming Pungs (Triplets) whenever possible - they score significantly more points than Chows!',
                style: GoogleFonts.inter(fontSize: 16, height: 1.55, color: _kText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A row of 3 tiles from the sprite sheet.
/// [entries] is a list of (row, col) pairs.
class _TileRow extends StatelessWidget {
  final List<(int, int)> entries;
  const _TileRow({required this.entries});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 12.0;
      final tW = (constraints.maxWidth - gap * (entries.length - 1)) / entries.length;
      final tH = tW * _rowH[entries.first.$1] / _srcTileW;

      return Row(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            SizedBox(
              width: tW, height: tH,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6, offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _tileAt(
                    row: entries[i].$1,
                    col: entries[i].$2,
                    dstW: tW, dstH: tH,
                  ),
                ),
              ),
            ),
            if (i < entries.length - 1) const SizedBox(width: gap),
          ],
        ],
      );
    });
  }
}

// ── 🀄 IDENTIFY THE TILES ─────────────────────────────────────────────────────

class _IdentifyCard extends StatelessWidget {
  const _IdentifyCard();

  @override
  Widget build(BuildContext context) {
    final body = GoogleFonts.inter(fontSize: 16, height: 1.55, color: _kText);

    return _SectionCard(
      title: '📖 IDENTIFY THE TILES',
      children: [
        Text('The Three Suits (Numbers 1-9)',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
        const SizedBox(height: 14),

        // Dots
        Text('Dots (Circles): Easy to count! The number of circles = the tile value.',
            style: body),
        const SizedBox(height: 8),
        const _SuitStrip(spriteRow: 1), // pin = dots/circles
        const SizedBox(height: 14),

        // Bamboos
        Text('Bamboos (Sticks): Count the sticks. Note: The 1-Bamboo is a Bird.',
            style: body),
        const SizedBox(height: 8),
        const _SuitStrip(spriteRow: 0), // sou = bamboo/sticks
        const SizedBox(height: 14),

        // Characters
        Text('Characters (Numbers): Look for the Chinese character on top - they follow a 1-9 sequence.',
            style: body),
        const SizedBox(height: 8),
        const _SuitStrip(spriteRow: 2), // man = characters
      ],
    );
  }
}

/// A horizontal strip of all 9 tiles for a given sprite sheet row.
class _SuitStrip extends StatelessWidget {
  final int spriteRow;
  const _SuitStrip({required this.spriteRow});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 3.0;
      final tW = (constraints.maxWidth - gap * 8) / 9;
      final tH = tW * _rowH[spriteRow] / _srcTileW;

      return SizedBox(
        height: tH,
        child: Row(
          children: [
            for (int c = 0; c < 9; c++) ...[
              SizedBox(
                width: tW, height: tH,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 3, offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: _tileAt(
                      row: spriteRow, col: c, dstW: tW, dstH: tH,
                    ),
                  ),
                ),
              ),
              if (c < 8) const SizedBox(width: gap),
            ],
          ],
        ),
      );
    });
  }
}

// ── ✨ MAGIC TILES ─────────────────────────────────────────────────────────────

class _MagicCard extends StatelessWidget {
  const _MagicCard();

  static const _entries = [
    (TileSuit.east,        'East Wind',  'Removes itself; sends the tile immediately to its RIGHT to the end of the draw pile'),
    (TileSuit.south,       'South Wind', 'Removes itself; sends the tile directly BELOW it to the end of the draw pile'),
    (TileSuit.west,        'West Wind',  'Removes itself; sends the tile immediately to its LEFT to the end of the draw pile'),
    (TileSuit.north,       'North Wind', 'Removes itself; sends the tile directly ABOVE it to the end of the draw pile'),
    (TileSuit.redDragon,   'Red (中)',   'Removes itself; sends the 4 orthogonal neighbours (↑↓←→) to the end of the draw pile'),
    (TileSuit.whiteDragon, 'White (白板)', 'Removes itself; sends the surrounding 8 tiles (clockwise) to the end of the draw pile'),
    (TileSuit.greenDragon, 'Green (发财)', 'Removes itself; all tiles on screen are randomly reshuffled and every empty slot is filled'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '✨ MAGIC TILES',
      children: [
        for (int i = 0; i < _entries.length; i++) ...[
          _MagicRow(
            suit:   _entries[i].$1,
            name:   _entries[i].$2,
            effect: _entries[i].$3,
          ),
          if (i < _entries.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _MagicRow extends StatelessWidget {
  final TileSuit suit;
  final String name;
  final String effect;

  const _MagicRow({required this.suit, required this.name, required this.effect});

  @override
  Widget build(BuildContext context) {
    const tW = 49.0; const tH = 68.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: tW, height: tH,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4, offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: _tileSprite(suit: suit, dstW: tW, dstH: tH),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
              const SizedBox(height: 4),
              Text(effect,
                  style: GoogleFonts.inter(
                      fontSize: 14, height: 1.4, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}
