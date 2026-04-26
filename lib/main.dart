import 'dart:async';

import 'package:first_app/db/db_helper.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'liked_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.first_app.audio',
    androidNotificationChannelName: 'Music playback',
    androidNotificationOngoing: true,
  );
  runApp(const MyApp());
}

const List<Map<String, String>> musicList = [
  {
    'title': 'Test 1',
    'file': 'audio/test1.mp3',
    'author': 'Ahmed',
    'description':
        'This track blends smooth melodies with subtle ambient textures, creating a relaxing yet engaging listening experience. The composition evolves gradually, starting with soft tones that build into a layered arrangement of rhythm and harmony. It captures a sense of calm and introspection, making it perfect for late-night listening or focused work sessions. The artist experimented with different sound elements, combining digital beats with organic instruments to achieve a balanced and immersive soundscape.'
  },
  {
    'title': 'Test 2',
    'file': 'audio/test_2.mp3',
    'author': 'John Doe',
    'description':
        'An energetic and dynamic piece that fuses modern electronic sounds with classic musical influences. From the very beginning, the track introduces a catchy rhythm that keeps evolving with unexpected transitions and vibrant layers. The production highlights creativity and attention to detail, with each section offering something new to the listener. Whether you are working out, driving, or just exploring new music, this track delivers a powerful and uplifting vibe that stays memorable long after it ends.'
  },
];

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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Completer<void> _playerReady = Completer<void>();
  late final AnimationController _rotationController;
  StreamSubscription<PlayerException>? _errorSubscription;

  bool isPlaying = false;
  bool showControls = false;
  int currentMusicIndex = 0;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _configurePlayer();

    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing = state.playing;
      setState(() {
        isPlaying = playing;
      });
      if (playing) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });

    _audioPlayer.currentIndexStream.listen((index) {
      if (!mounted || index == null) return;
      setState(() {
        currentMusicIndex = index;
      });
    });

    _errorSubscription = _audioPlayer.errorStream.listen((error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio error: ${error.message}')),
      );
    });
  }

  Future<void> _configurePlayer() async {
    try {
      final playlist = [
        for (var i = 0; i < musicList.length; i++)
          AudioSource.asset(
            'assets/${musicList[i]['file']!}',
            tag: MediaItem(
              id: '$i',
              album: 'First App',
              title: musicList[i]['title']!,
              artist: musicList[i]['author'],
            ),
          ),
      ];

      await _audioPlayer.setLoopMode(LoopMode.all);
      await _audioPlayer.setAudioSources(
        playlist,
        initialIndex: currentMusicIndex,
      );

      if (!_playerReady.isCompleted) {
        _playerReady.complete();
      }
    } catch (error, stackTrace) {
      if (!_playerReady.isCompleted) {
        _playerReady.completeError(error, stackTrace);
      }
    }
  }

  Future<bool> isFavorite(String title) async {
    final favorites = await DatabaseHelper.instance.getFavorites();
    return favorites.any((song) => song['title'] == title);
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _audioPlayer.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> playPause() async {
    showControls = true;
    setState(() {});

    await _playerReady.future;

    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> nextSong() async {
    await _playerReady.future;
    final nextIndex = (currentMusicIndex + 1) % musicList.length;
    await _audioPlayer.seek(Duration.zero, index: nextIndex);
    await _audioPlayer.play();
  }

  Future<void> previousSong() async {
    await _playerReady.future;
    final previousIndex =
        (currentMusicIndex - 1 + musicList.length) % musicList.length;
    await _audioPlayer.seek(Duration.zero, index: previousIndex);
    await _audioPlayer.play();
  }

  @override
  Widget build(BuildContext context) {
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: FutureBuilder<bool>(
                                future: isFavorite(
                                  musicList[currentMusicIndex]['title']!,
                                ),
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
                                final song = musicList[currentMusicIndex];
                                final title = song['title']!;
                                final alreadyFav = await isFavorite(title);

                                if (alreadyFav) {
                                  await DatabaseHelper.instance
                                      .deleteFavorite(title);
                                } else {
                                  await DatabaseHelper.instance
                                      .insertFavorite(song);
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
                            Text(
                              musicList[currentMusicIndex]['title']!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
