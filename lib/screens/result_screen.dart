import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_config.dart';
import '../services/progress_service.dart';

class ResultScreen extends StatefulWidget {
  final ResultArgs args;
  const ResultScreen({super.key, required this.args});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    if (widget.args.isVictory) {
      ProgressService.markCompleted(widget.args.level);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: _ResultContent(args: widget.args),
        ),
      ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  final ResultArgs args;
  const _ResultContent({required this.args});

  @override
  Widget build(BuildContext context) {
    final isVictory = args.isVictory;
    final screenH = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: LayoutBuilder(builder: (context, constraints) {
          final s = math.min(screenH / 874, constraints.maxWidth / 402);
          return SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 53 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: (isVictory ? 187 : 181) * s),
                  // Icon: sad or happy face
                  SizedBox(
                    width: 90 * s,
                    height: 90 * s,
                    child: CustomPaint(
                      painter: _FacePainter(isSmiling: isVictory),
                    ),
                  ),
                  SizedBox(height: 28 * s),
                  // Title
                  Text(
                    isVictory ? 'Succeed' : 'Defeated',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 57.72 * s,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 20 * s),
                  // Decorative divider
                  _DividerRow(scale: s),
                  SizedBox(height: 18 * s),
                  // Score label
                  Text(
                    'Score',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24 * s,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 12 * s),
                  // Score value
                  Text(
                    '${args.score}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 57.72 * s,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      height: 1.1,
                    ),
                  ),
                  const Spacer(),
                  // Play again button
                  _ActionButton(
                    label: 'Play again',
                    filled: true,
                    scale: s,
                    onTap: () => Navigator.pushReplacementNamed(
                      context,
                      '/game',
                      arguments: GameConfig.all
                          .firstWhere((c) => c.mode == args.level),
                    ),
                  ),
                  SizedBox(height: 14 * s),
                  // Home Menu button
                  _ActionButton(
                    label: 'Home Menu',
                    filled: false,
                    scale: s,
                    onTap: () => Navigator.pushNamedAndRemoveUntil(
                        context, '/', (_) => false),
                  ),
                  SizedBox(height: 60 * s),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Decorative divider with diamond ornament ───────────────────────────────

class _DividerRow extends StatelessWidget {
  final double scale;
  const _DividerRow({required this.scale});

  @override
  Widget build(BuildContext context) {
    final lineH = 1.0 * scale;
    final gapW = 29.0 * scale;
    final diamond = 7.07 * scale;

    return SizedBox(
      height: diamond + 4,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left line
          Expanded(
            child: Container(
              height: lineH,
              color: Colors.black,
            ),
          ),
          SizedBox(width: (gapW - diamond) / 2),
          // Diamond ornament
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: diamond,
              height: diamond,
              color: Colors.black,
            ),
          ),
          SizedBox(width: (gapW - diamond) / 2),
          // Right line
          Expanded(
            child: Container(
              height: lineH,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action button ──────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final double scale;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.scale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60 * scale,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: filled ? Colors.black : Colors.transparent,
          foregroundColor: filled ? Colors.white : Colors.black,
          side: const BorderSide(color: Colors.black, width: 3),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          style: GoogleFonts.playfairDisplay(
            fontSize: 24 * scale,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ── Face icon painter ──────────────────────────────────────────────────────

class _FacePainter extends CustomPainter {
  final bool isSmiling;
  const _FacePainter({required this.isSmiling});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = const Color(0xFF151515)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Ring: stroke a circle whose midline is at radius ~41.25/90 of s
    // Outer edge ~45, inner edge ~37.5 → stroke width ~7.5
    paint.strokeWidth = s * 0.0833; // ~7.5/90
    canvas.drawCircle(
      Offset(s / 2, s / 2),
      s * 0.4166, // midline between inner and outer rim
      paint,
    );

    // Eyes (filled circles)
    final eyePaint = Paint()
      ..color = const Color(0xFF151515)
      ..style = PaintingStyle.fill;

    // Left eye: center at (33.75, 33.75) in 90×90 → 0.375 × s
    canvas.drawCircle(
      Offset(s * 0.375, s * 0.375),
      s * 0.0625, // radius 5.625/90
      eyePaint,
    );
    // Right eye: center at (56.25, 33.75) → 0.625 × s
    canvas.drawCircle(
      Offset(s * 0.625, s * 0.375),
      s * 0.0625,
      eyePaint,
    );

    // Mouth
    paint.strokeWidth = s * 0.055;
    final mouthPath = Path();

    if (isSmiling) {
      // Smile: corners higher, center lower (arc opens downward)
      // Derived from path: starts ~y:54.8/90, curves down to ~y:64.7/90
      mouthPath.moveTo(s * 0.2925, s * 0.610);
      mouthPath.quadraticBezierTo(
        s * 0.5, s * 0.725,   // center nadir
        s * 0.7075, s * 0.610,
      );
    } else {
      // Frown: corners lower, center higher (arc opens upward)
      // Derived from path: viewBox positioned at y:45.5, curves down to y:61.8 at corners
      mouthPath.moveTo(s * 0.2925, s * 0.655);
      mouthPath.quadraticBezierTo(
        s * 0.5, s * 0.510,   // center apex
        s * 0.7075, s * 0.655,
      );
    }
    canvas.drawPath(mouthPath, paint);
  }

  @override
  bool shouldRepaint(_FacePainter oldDelegate) =>
      oldDelegate.isSmiling != isSmiling;
}
