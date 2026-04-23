// Web-specific audio context unlock using dart:web_audio.
// Called synchronously within a pointer event handler to satisfy
// browser autoplay policy before any async audio play calls.
// ignore: avoid_web_libraries_in_flutter
import 'dart:web_audio';

void unlockWebAudioContext() {
  try {
    AudioContext().resume();
  } catch (_) {}
}
