import 'package:audioplayers/audioplayers.dart';
import '../models/sound_event.dart';

/// Singleton audio service for BGM and sound effects.
/// All public methods silently swallow errors so missing audio files
/// never crash the app — just place the correct .mp3 files in
/// assets/audio/ when they are ready.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  // ─── BGM player (looping) ────────────────────────────────────────────

  final AudioPlayer _bgmPlayer = AudioPlayer();
  String? _currentBgm; // tracks which BGM source is active

  static const double _bgmVolume = 0.30;
  static const double _sfxVolume = 0.85;

  // ─── SFX round-robin pool (avoids creating a new player per tap) ─────

  static const int _poolSize = 4;
  final List<AudioPlayer> _sfxPool = List.generate(_poolSize, (_) => AudioPlayer());
  int _sfxIdx = 0;

  // ─── BGM public API ──────────────────────────────────────────────────

  /// Start (or keep playing) the menu / level-select background music.
  Future<void> playMenuBgm() async {
    if (_currentBgm == 'menu') return;
    _currentBgm = 'menu';
    try {
      await _bgmPlayer.setVolume(_bgmVolume);
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('audio/bgm_menu.mp3'));
    } catch (_) {}
  }

  /// Start (or keep playing) the in-game background music.
  Future<void> playGameBgm() async {
    if (_currentBgm == 'game') return;
    _currentBgm = 'game';
    try {
      await _bgmPlayer.setVolume(_bgmVolume);
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.play(AssetSource('audio/bgm_game.mp3'));
    } catch (_) {}
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
      case SoundEvent.tileToHand:     return 'audio/sfx_tile.mp3';
      case SoundEvent.chow:           return 'audio/sfx_chow.mp3';
      case SoundEvent.pung:           return 'audio/sfx_pung.mp3';
      case SoundEvent.magicWind:      return 'audio/sfx_wind.mp3';
      case SoundEvent.magicDisappear: return 'audio/sfx_vanish.mp3';
      case SoundEvent.magicShuffle:   return 'audio/sfx_shuffle.mp3';
      case SoundEvent.gameEnd:        return 'audio/sfx_end.mp3';
    }
  }
}
