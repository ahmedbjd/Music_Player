import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'liked_screen.dart';

import 'package:first_app/db/db_helper.dart';

/// 🔥 GLOBAL ROUTE OBSERVER
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() {
  runApp(const MyApp());
}

/// 🎵 MUSIC DATA
const List<Map<String, String>> musicList = [
  {
    'title': 'Test 1',
    'file': 'audio/test1.mp3',
    'author': 'Ahmed',
    'description': 'This track blends smooth melodies with subtle ambient textures, creating a relaxing yet engaging listening experience. The composition evolves gradually, starting with soft tones that build into a layered arrangement of rhythm and harmony. It captures a sense of calm and introspection, making it perfect for late-night listening or focused work sessions. The artist experimented with different sound elements, combining digital beats with organic instruments to achieve a balanced and immersive soundscape.'
  },
  {
    'title': 'Test 2',
    'file': 'audio/test_2.mp3',
    'author': 'John Doe',
    'description': 'An energetic and dynamic piece that fuses modern electronic sounds with classic musical influences. From the very beginning, the track introduces a catchy rhythm that keeps evolving with unexpected transitions and vibrant layers. The production highlights creativity and attention to detail, with each section offering something new to the listener. Whether you are working out, driving, or just exploring new music, this track delivers a powerful and uplifting vibe that stays memorable long after it ends.'
  },
];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver], 
      home: const MusicPlayer(),
    );
  }
}

class MusicPlayer extends StatefulWidget {
  const MusicPlayer({super.key});

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer>
    with SingleTickerProviderStateMixin,
         WidgetsBindingObserver,
         RouteAware {

  static const platform = MethodChannel('com.example.music/service');
  static const playbackEvents =
      EventChannel('com.example.music/playback_events');
  late AnimationController _rotationController;
  StreamSubscription<dynamic>? _playbackSubscription;

  bool isPlaying = false;

  List<Map<String, String>> likedSongs = [];  
  
  bool showControls = false;
  int currentMusicIndex = 0;

  Future<bool> isFavorite(String title) async {
  final favorites = await DatabaseHelper.instance.getFavorites();

  return favorites.any((song) => song['title'] == title);
}

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _playbackSubscription = playbackEvents.receiveBroadcastStream().listen(
      (dynamic event) {
        final playing = event == true;

        if (!mounted) {
          return;
        }

        if (playing) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }

        setState(() {
          isPlaying = playing;
        });
      },
      onError: (Object error) {
        debugPrint('Playback event error: $error');
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _playbackSubscription?.cancel();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _rotationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _rotationController.stop();
    }

    if (state == AppLifecycleState.resumed && isPlaying) {
      _rotationController.repeat();
    }
  }


  @override
  void didPushNext() async {
    _rotationController.stop();
  }

  @override
  void didPopNext() async {
    if (isPlaying) {
      _rotationController.repeat();
    }
  }


  Future<void> playPause() async {
    showControls = true;

    if (isPlaying) {
      try {
        await platform.invokeMethod('pauseService');
      } catch (e) {
        debugPrint('Error pausing service: $e');
      }
      _rotationController.stop();
    } else {
      try {
        await platform.invokeMethod('startService', {
          'filename': musicList[currentMusicIndex]['file']!,
        });
      } catch (e) {
        debugPrint('Error starting service: $e');
      }
      _rotationController.repeat();
    }

    setState(() {
      isPlaying = !isPlaying;
    });
  }

  Future<void> nextSong() async {
    try {
      await platform.invokeMethod('stopService');
    } catch (e) {
      debugPrint('Error stopping service: $e');
    }

    currentMusicIndex =
        (currentMusicIndex + 1) % musicList.length;

    try {
      await platform.invokeMethod('startService', {
        'filename': musicList[currentMusicIndex]['file']!,
      });
    } catch (e) {
      debugPrint('Error starting service: $e');
    }

    _rotationController.repeat();

    setState(() {
      isPlaying = true;
    });
  }

  Future<void> previousSong() async {
    try {
      await platform.invokeMethod('stopService');
    } catch (e) {
      debugPrint('Error stopping service: $e');
    }

    currentMusicIndex =
        (currentMusicIndex - 1 + musicList.length) %
            musicList.length;

    try {
      await platform.invokeMethod('startService', {
        'filename': musicList[currentMusicIndex]['file']!,
      });
    } catch (e) {
      debugPrint('Error starting service: $e');
    }

    _rotationController.repeat();

    setState(() {
      isPlaying = true;
    });
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
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.skip_previous),
                              iconSize: 50,
                              onPressed: previousSong,
                            ),
                            const SizedBox(width: 20),
                            IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
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
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                              IconButton(
                                icon: FutureBuilder<bool>(
                                  future: isFavorite(
                                    musicList[currentMusicIndex]['title']!,
                                  ),
                                  builder: (context, snapshot) {
                                    final isFav = snapshot.data ?? false;
                  
                                    return Icon(
                                      isFav ? Icons.favorite : Icons.favorite_border,
                                      color: Colors.red,
                                    );
                                  },
                                ),
                  
                                onPressed: () async {
                                  final song = musicList[currentMusicIndex];
                                  final title = song['title']!;
                  
                                  final alreadyFav = await isFavorite(title);
                  
                                  if (alreadyFav) {
                                    await DatabaseHelper.instance.deleteFavorite(title);
                                  } else {
                                    await DatabaseHelper.instance.insertFavorite(song);
                                  }
                  
                                  setState(() {}); // refresh UI
                                },
                  
                                onLongPress: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LikedScreen(),
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
