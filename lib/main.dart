import 'dart:async';

import 'package:first_app/db/db_helper.dart';
import 'package:first_app/services/audio_player_service.dart';
import 'package:flutter/material.dart';

import 'liked_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MusicPlayer(),
    );
  }
}

class MusicPlayer extends StatefulWidget {
  const MusicPlayer({super.key});

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer>
    with SingleTickerProviderStateMixin {
  final AudioPlayerService _audioService = AudioPlayerService.instance;
  late final AnimationController _rotationController;

  bool showControls = false;

  AudioPlayerState get playerState => _audioService.stateNotifier.value;
  bool get isPlaying => playerState.isPlaying;
  bool get hasTracks => playerState.hasTracks;
  bool get permissionGranted => playerState.permissionGranted;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _audioService.stateNotifier.addListener(_handlePlaybackStateChanged);

    unawaited(_initializeAudio());
  }

  Future<void> _initializeAudio() async {
    try {
      await _audioService.initialize();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio error: $error')),
      );
    }
  }

  void _handlePlaybackStateChanged() {
    if (!mounted) return;

    setState(() {});

    if (isPlaying) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }
  }

  Future<bool> isFavorite(String title) async {
    final favorites = await DatabaseHelper.instance.getFavorites();
    return favorites.any((song) => song['title'] == title);
  }

  @override
  void dispose() {
    _audioService.stateNotifier.removeListener(_handlePlaybackStateChanged);
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> playPause() async {
    if (!hasTracks) return;
    showControls = true;
    setState(() {});
    await _audioService.playPause();
  }

  Future<void> nextSong() async {
    if (!hasTracks) return;
    await _audioService.next();
  }

  Future<void> previousSong() async {
    if (!hasTracks) return;
    await _audioService.previous();
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = playerState.track;
    final statusMessage = !permissionGranted
        ? 'Allow audio access to read songs from your phone.'
        : !hasTracks
            ? 'No audio files were found on this device.'
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Player'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotationTransition(
                turns: _rotationController,
                child: Image.asset(
                  'assets/images/bg2.png',
                  width: 300,
                  height: 300,
                ),
              ),
              const SizedBox(height: 30),
              if (statusMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    statusMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              if (statusMessage != null) const SizedBox(height: 24),
              showControls
                  ? Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              iconSize: 50,
                              onPressed: previousSong,
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: Icon(
                                isPlaying ? Icons.pause : Icons.play_arrow,
                              ),
                              iconSize: 75,
                              onPressed: playPause,
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: const Icon(Icons.skip_next),
                              iconSize: 50,
                              onPressed: nextSong,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              IconButton(
                                icon: FutureBuilder<bool>(
                                  future: isFavorite(currentSong.title),
                                  builder: (context, snapshot) {
                                    final isFav = snapshot.data ?? false;
                                    return Icon(
                                      isFav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: Colors.red,
                                    );
                                  },
                                ),
                                onPressed: () async {
                                  if (currentSong.title.isEmpty) return;
                                  final alreadyFav = await isFavorite(currentSong.title);

                                  if (alreadyFav) {
                                    await DatabaseHelper.instance.deleteFavorite(
                                      currentSong.title,
                                    );
                                  } else {
                                    await DatabaseHelper.instance.insertFavorite(
                                      currentSong.toMap(),
                                    );
                                  }

                                  setState(() {});
                                },
                                onLongPress: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LikedScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  currentSong.title.isEmpty
                                      ? 'No track selected'
                                      : currentSong.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : IconButton(
                      icon: const Icon(Icons.play_arrow),
                      iconSize: 75,
                      onPressed: playPause,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
