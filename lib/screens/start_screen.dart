import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/audio_service.dart';
import '../models/tile.dart';
import 'rules_screen.dart';

const Color _kBg = Color(0xFFEDEDED);

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();
    AudioService.instance.playMenuBgm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Scale factor: 1.0 = 402 px Figma base. Cap at 1.4 for wide screens.
            final scale = (constraints.maxWidth / 402.0).clamp(0.88, 1.4);
            return Center(
              child: ConstrainedBox(
                // Limit max width on large screens so content stays readable
                constraints: const BoxConstraints(maxWidth: 560),
                child: _StartContent(scale: scale),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content column
// ---------------------------------------------------------------------------

class _StartContent extends StatelessWidget {
  final double scale;
  const _StartContent({required this.scale});

  @override
  Widget build(BuildContext context) {
    // Horizontal padding mirrors the Figma button margins (53 px on 402 px screen)
    final hPad = (53.0 * scale).clamp(20.0, 80.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: Column(
        children: [
          const Spacer(flex: 3),
          _TileGroup(scale: scale),
          SizedBox(height: 28.0 * scale),
          // ── MAHJONG ──────────────────────────────────────────────────────
          Text(
            'MAHJONG',
            style: GoogleFonts.playfairDisplay(
              fontSize: 52.0 * scale,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              letterSpacing: 4,
            ),
          ),
          SizedBox(height: 8.0 * scale),
          const _OrnamentDivider(),
          SizedBox(height: 8.0 * scale),
          Text(
            'MATCHING',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16.0 * scale,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              letterSpacing: 5,
            ),
          ),
          const Spacer(flex: 4),
          // ── Buttons ──────────────────────────────────────────────────────
          _FlatButton(
            label: 'PLAY',
            filled: true,
            scale: scale,
            onTap: () => Navigator.pushNamed(context, '/levels'),
          ),
          SizedBox(height: 16.0 * scale),
          _FlatButton(
            label: 'HOW TO PLAY',
            filled: false,
            scale: scale,
            onTap: () => _showRules(context),
          ),
          SizedBox(height: 40.0 * scale),
        ],
      ),
    );
  }

  void _showRules(BuildContext context) => showRulesDialog(context);
}

// ---------------------------------------------------------------------------
// Decorative tile group (three rotated tile sprites, mimicking Figma layout)
// ---------------------------------------------------------------------------
// Figma Group 122 bounding box: 149 × 262 px (at 402 px screen width)
// Tile centers within the group (col=0-based from left, row from top):
//   中 redDragon   : center (51,  81), size 82×117,  angle –10.81°
//   發 greenDragon : center (131, 102), size 70×100,  angle +18.25°
//   白 whiteDragon : center (69,  245), size 61× 87,  angle –36.30°

class _TileGroup extends StatelessWidget {
  final double scale;
  const _TileGroup({this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  149.0 * scale,
      height: 280.0 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _tile(TileSuit.redDragon,    82, 117,  51,  81, -0.1887),
          _tile(TileSuit.greenDragon,  70, 100, 131, 102,  0.3186),
          _tile(TileSuit.whiteDragon,  61,  87,  69, 245, -0.6335),
        ],
      ),
    );
  }

  Widget _tile(
    TileSuit suit,
    double baseW,
    double baseH,
    double centerX,
    double centerY,
    double angle,
  ) {
    final w = baseW * scale;
    final h = baseH * scale;
    return Positioned(
      left: centerX * scale - w / 2,
      top:  centerY * scale - h / 2,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8 * scale),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8 * scale),
            child: _tileSprite(suit: suit, dstW: w, dstH: h),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sprite-sheet renderer
// ---------------------------------------------------------------------------
// Sprite layout (tiles.png, 1024×1024):
//   Row 0 (y=22,  h=146): sou 1→9
//   Row 1 (y=230, h=147): pin 1→9
//   Row 2 (y=441, h=146): man 1→9
//   Row 3 (y=646, h=148): east south west north
//   Row 4 (y=856, h=147): redDragon greenDragon whiteDragon
//   Columns: x = 20 + col×111,  tile width = 104 px

Widget _tileSprite({required TileSuit suit, required double dstW, required double dstH}) {
  const double sheetW = 1024;
  const double sheetH = 1024;
  const double srcX0 = 20.0;
  const double srcStep = 111.0;
  const double srcTileW = 104.0;
  const rowY = [22.0, 230.0, 441.0, 646.0, 856.0];
  const rowH = [146.0, 147.0, 146.0, 148.0, 147.0];

  int col;
  int row;
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

  final srcX = srcX0 + col * srcStep;
  final srcY = rowY[row];
  final sh   = rowH[row];
  final sx   = dstW / srcTileW;
  final sy   = dstH / sh;

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

// ---------------------------------------------------------------------------
// Ornamental divider  ── ♦ ──
// ---------------------------------------------------------------------------

class _OrnamentDivider extends StatelessWidget {
  const _OrnamentDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.black54, thickness: 0.8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Transform.rotate(
            angle: 0.7854, // 45°
            child: Container(width: 5, height: 5, color: Colors.black87),
          ),
        ),
        const Expanded(child: Divider(color: Colors.black54, thickness: 0.8)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

class _FlatButton extends StatelessWidget {
  final String label;
  final bool filled;
  final double scale;
  final VoidCallback onTap;

  const _FlatButton({
    required this.label,
    required this.filled,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final h = (56.0 * scale).clamp(48.0, 64.0);
    final labelStyle = GoogleFonts.playfairDisplay(
      fontSize: (16.0 * scale).clamp(14.0, 20.0),
      fontWeight: FontWeight.w400,
      letterSpacing: 3,
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));

    if (filled) {
      return SizedBox(
        width: double.infinity,
        height: h,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: shape,
          ),
          child: Text(label, style: labelStyle),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: h,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 1.5),
          shape: shape,
        ),
        child: Text(label, style: labelStyle),
      ),
    );
  }
}

