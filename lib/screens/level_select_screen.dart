import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_config.dart';
import '../services/progress_service.dart';
import '../services/audio_service.dart';

const Color _kBg = Color(0xFFEDEDED);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  Map<LevelMode, bool> _progress = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AudioService.instance.playMenuBgm();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final p = await ProgressService.loadAllProgress();
    if (mounted) setState(() { _progress = p; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black54),
                    )
                  : _LevelList(
                      progress: _progress,
                      onLevelSelected: _startLevel,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _startLevel(GameConfig config) {
    Navigator.pushNamed(context, '/game', arguments: config).then((_) {
      _loadProgress();
    });
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back, color: Colors.black, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'LEVEL SELECT',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level list — responsive: single column on phones and tablets,
// 2-column grid on landscape / desktop (≥ 760 px)
// ---------------------------------------------------------------------------

class _LevelList extends StatelessWidget {
  final Map<LevelMode, bool> progress;
  final void Function(GameConfig) onLevelSelected;

  const _LevelList({required this.progress, required this.onLevelSelected});

  @override
  Widget build(BuildContext context) {
    final cards = GameConfig.all.map((config) {
      return _LevelCard(
        config: config,
        completed: progress[config.mode] ?? false,
        onTap: () => onLevelSelected(config),
      );
    }).toList();

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;

      // ── Expanded (≥ 760 px): 2-column grid centered at max 840 px ──────
      if (w >= 760) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              // At 840 px container: card width ≈ 412 px, height ≈ 190 px
              childAspectRatio: 2.2,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: cards,
            ),
          ),
        );
      }

      // ── Compact / medium: single-column list, constrained to 560 px ────
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (_, i) => cards[i],
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Level card
// ---------------------------------------------------------------------------

class _LevelCard extends StatefulWidget {
  final GameConfig config;
  final bool completed;
  final VoidCallback onTap;

  const _LevelCard({
    required this.config,
    required this.completed,
    required this.onTap,
  });

  @override
  State<_LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<_LevelCard> {
  bool _hovered = false;

  Widget get _iconWidget {
    switch (widget.config.mode) {
      case LevelMode.basic:
        return SvgPicture.asset(
          'assets/images/icon_basic.svg',
          width: 36, height: 36,
        );
      case LevelMode.advanced:
        return SvgPicture.asset(
          'assets/images/icon_fun.svg',
          width: 36, height: 36,
        );
      case LevelMode.challenge:
        return SvgPicture.asset(
          'assets/images/icon_challenge.svg',
          width: 36, height: 36,
        );
      case LevelMode.nightmare:
        return SvgPicture.asset(
          'assets/images/icon_nightmare.svg',
          width: 36, height: 36,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: _hovered ? 6 : 0,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.black.withValues(alpha: 0.08),
            highlightColor: Colors.black.withValues(alpha: 0.04),
            // MouseRegion handles hover visuals; keep InkWell hover transparent
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconWidget,
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                widget.config.displayName.toUpperCase(),
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            if (widget.completed) const SizedBox(width: 8),
                            if (widget.completed) const _DoneBadge(),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.config.description,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xBF000000),
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "DONE" badge
// ---------------------------------------------------------------------------

class _DoneBadge extends StatelessWidget {
  const _DoneBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'DONE',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
