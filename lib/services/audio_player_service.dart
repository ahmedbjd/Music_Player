import 'dart:async';

import 'package:first_app/models/song.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioPlayerState {
  const AudioPlayerState({
    required this.currentIndex,
    required this.isPlaying,
    required this.track,
    required this.hasTracks,
    required this.permissionGranted,
  });

  final int currentIndex;
  final bool isPlaying;
  final Song track;
  final bool hasTracks;
  final bool permissionGranted;

  factory AudioPlayerState.fromMap(Map<dynamic, dynamic> map) {
    return AudioPlayerState(
      currentIndex: map['currentIndex'] as int? ?? 0,
      isPlaying: map['isPlaying'] as bool? ?? false,
      track: Song.fromMap(map['track'] as Map<dynamic, dynamic>? ?? const {}),
      hasTracks: map['hasTracks'] as bool? ?? false,
      permissionGranted: map['permissionGranted'] as bool? ?? false,
    );
  }
}

class AudioPlayerService {
  AudioPlayerService._() {
    _stateSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        stateNotifier.value = AudioPlayerState.fromMap(event);
      }
    });
  }

  static final AudioPlayerService instance = AudioPlayerService._();

  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.first_app/audio',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.first_app/audio_state',
  );

  late final StreamSubscription<dynamic> _stateSubscription;
  final ValueNotifier<AudioPlayerState> stateNotifier = ValueNotifier(
    AudioPlayerState(
      currentIndex: 0,
      isPlaying: false,
      track: const Song(
        title: '',
        file: '',
        author: '',
        description: '',
      ),
      hasTracks: false,
      permissionGranted: false,
    ),
  );

  Future<void> initialize() async {
    final state = await _invokeStateMethod('initialize');
    stateNotifier.value = state;
  }

  Future<void> playPause() => _methodChannel.invokeMethod('playPause');

  Future<void> next() => _methodChannel.invokeMethod('next');

  Future<void> previous() => _methodChannel.invokeMethod('previous');

  Future<void> refreshState() async {
    final state = await _invokeStateMethod('getState');
    stateNotifier.value = state;
  }

  Future<AudioPlayerState> _invokeStateMethod(String method) async {
    final result = await _methodChannel.invokeMethod(method);
    if (result is! Map) {
      throw PlatformException(
        code: 'invalid_state',
        message: 'Native audio service returned an invalid state payload.',
      );
    }

    return AudioPlayerState.fromMap(result);
  }

  Future<void> dispose() async {
    await _stateSubscription.cancel();
    stateNotifier.dispose();
  }
}
