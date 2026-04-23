import 'package:audioplayers/audioplayers.dart';
import '../models/sound_event.dart';

/// Singleton audio service for BGM and sound effects.
/// All public methods silently swallow errors so missing audio files
/// never crash the app — just place the correct .mp3 files in
/// assets/audio/ when they are ready.
class AudioService {
  AudioService._() {
    _bgmPlayer.onPlayerStateChanged.listen((state) {
      _bgmPlaying = state == PlayerState.playing;
    });
  }
  static final AudioService instance = AudioService._();

  // ─── BGM player (looping) ────────────────────────────────────────────

  final AudioPlayer _bgmPlayer = AudioPlayer();
  String? _currentBgm; // tracks which BGM source is active
  String? _bgmWanted;  // tracks which BGM should be playing (for autoplay retry)
  bool _bgmPlaying = false; // actual playback state

  static const double _menuBgmVolume = 0.10;
  static const double _gameBgmVolume = 0.02;
  static const double _sfxVolume = 1.0;

  // ─── SFX round-robin pool (avoids creating a new player per tap) ─────

  static const int _poolSize = 4;
  final List<AudioPlayer> _sfxPool = List.generate(_poolSize, (_) => AudioPlayer());
  int _sfxIdx = 0;

  // ─── BGM public API ──────────────────────────────────────────────────

  /// Start (or keep playing) the menu / level-select background music.
  Future<void> playMenuBgm() async {
    _bgmWanted = 'menu';
    if (_currentBgm == 'menu' && _bgmPlaying) return;
    _currentBgm = 'menu';
    try {
      await _bgmPlayer.setVolume(_menuBgmVolume);
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('assets/audio/bgm_menu.mp3'));
    } catch (_) {}
  }

  /// Start (or keep playing) the in-game background music.
  Future<void> playGameBgm() async {
    _bgmWanted = 'game';
    if (_currentBgm == 'game' && _bgmPlaying) return;
    _currentBgm = 'game';
    try {
      await _bgmPlayer.setVolume(_gameBgmVolume);
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('assets/audio/bgm_game.mp3'));
    } catch (_) {}
  }

  /// Call this on any user interaction to retry BGM blocked by browser autoplay policy.
  Future<void> onUserInteraction() async {
    if (_bgmWanted != null && !_bgmPlaying) {
      _currentBgm = null; // reset guard so play methods don't skip
      if (_bgmWanted == 'menu') await playMenuBgm();
      if (_bgmWanted == 'game') await playGameBgm();
    }
  }

  /// Stop background music (clears tracking so the next call restarts it).
  Future<void> stopBgm() async {
    _currentBgm = null;
    try {
      await _bgmPlayer.stop();
    } catch (_) {}
  }

  // ─── SFX public API ──────────────────────────────────────────────────

  /// Play a one-shot sound effect for the given [event].
  /// If multiple sounds need to play close together the pool lets up to
  /// [_poolSize] sounds overlap naturally.
  Future<void> playSfx(SoundEvent event) async {
    final path = _sfxPath(event);
    if (path == null) return;
    try {
      final player = _sfxPool[_sfxIdx % _poolSize];
      _sfxIdx++;
      await player.stop();
      await player.setVolume(_sfxVolume);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource(path));
    } catch (_) {}
  }

  // ─── Disposal ────────────────────────────────────────────────────────

  Future<void> dispose() async {
    try { await _bgmPlayer.dispose(); } catch (_) {}
    for (final p in _sfxPool) {
      try { await p.dispose(); } catch (_) {}
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  String? _sfxPath(SoundEvent event) {
    switch (event) {
      case SoundEvent.tileToHand:     return 'assets/audio/sfx_tile.mp3';
      case SoundEvent.chow:           return 'assets/audio/sfx_chow.mp3';
      case SoundEvent.pung:           return 'assets/audio/sfx_pung.mp3';
      case SoundEvent.magicWind:      return 'assets/audio/sfx_wind.mp3';
      case SoundEvent.magicDisappear: return 'assets/audio/sfx_vanish.mp3';
      case SoundEvent.magicShuffle:   return 'assets/audio/sfx_shuffle.mp3';
      case SoundEvent.gameEnd:        return 'assets/audio/sfx_end.mp3';
    }
  }
}
