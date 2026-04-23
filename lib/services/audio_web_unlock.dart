// Web-specific audio context unlock using dart:html.
// Called synchronously within a pointer event handler to satisfy
// browser autoplay policy before any async audio play calls.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void unlockWebAudioContext() {
  try {
    final ctx = html.AudioContext();
    ctx.resume();
  } catch (_) {}
}
