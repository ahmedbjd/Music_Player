# Architecture & Data Flow Diagrams

## 🏗️ Application Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App (Dart)                       │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  main.dart (_MusicPlayerState)                       │   │
│  │  ├─ playPause()                                      │   │
│  │  ├─ nextSong()                                       │   │
│  │  ├─ previousSong()                                   │   │
│  │  └─ Lifecycle handlers                              │   │
│  └──────────────────────────────────────────────────────┘   │
│            │                                                  │
│            │ MethodChannel: "com.example.music/service"     │
│            │ Methods: startService, pauseService, stopService
│            ▼                                                  │
└─────────────────────────────────────────────────────────────┘
                     ║
                     ║ Android Binder
                     ║
┌─────────────────────────────────────────────────────────────┐
│              Native Android Layer (Kotlin)                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  MainActivity                                        │   │
│  │  ├─ configureFlutterEngine()                         │   │
│  │  ├─ MethodChannel handler                           │   │
│  │  └─ Intent helpers                                  │   │
│  └──────────────────────────────────────────────────────┘   │
│            │ Intent(ACTION_PLAY/PAUSE/STOP)                 │
│            ▼                                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  MusicService (Foreground Service)                  │   │
│  │  ├─ onStartCommand()                                │   │
│  │  ├─ playAudio()                                     │   │
│  │  ├─ pauseAudio()                                    │   │
│  │  ├─ stopAudio()                                     │   │
│  │  └─ showNotification()                              │   │
│  └──────────────────────────────────────────────────────┘   │
│     │              │                    │                    │
│     ▼              ▼                    ▼                    │
│  ┌──────┐   ┌─────────────────┐   ┌──────────────┐          │
│  │MediaP│   │Notification     │   │Asset to      │          │
│  │Layer │   │Manager          │   │Cache Copier  │          │
│  └──────┘   └─────────────────┘   └──────────────┘          │
│     │              │                    │                    │
│     ▼              ▼                    ▼                    │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  System Services (Audio, UI, File)                  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Playback Flow Diagram

### Scenario 1: User Presses Play

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User taps Play Button                                        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Flutter: playPause() called                                  │
│    - showControls = true                                        │
│    - isPlaying = false → trigger service start                 │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. MethodChannel Call                                           │
│    platform.invokeMethod('startService', {                      │
│      'filename': 'audio/test1.mp3'                             │
│    })                                                           │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. MainActivity Handler                                         │
│    - Extracts 'audio/test1.mp3'                               │
│    - Calls startMusicService(filename)                        │
│    - Creates Intent(MusicService, ACTION_PLAY)                │
│    - Calls startForegroundService(intent)                     │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. Android System                                               │
│    - Verifies FOREGROUND_SERVICE permission ✓                 │
│    - Allocates service component                              │
│    - Calls MusicService.onCreate()                            │
│    - Calls MusicService.onStartCommand()                      │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. MusicService.onStartCommand()                               │
│    - Detects ACTION_PLAY                                       │
│    - Extracts filename: 'audio/test1.mp3'                     │
│    - Calls playAudio('audio/test1.mp3')                       │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. MusicService.playAudio()                                    │
│    ├─ Release previous MediaPlayer (if any)                   │
│    ├─ Call copyAssetToCache('audio/test1.mp3')               │
│    │  └─ Copies /assets/audio/test1.mp3 → /cache/...mp3     │
│    ├─ Create new MediaPlayer()                                │
│    ├─ setDataSource(cacheFile.absolutePath)                 │
│    ├─ prepare()                                               │
│    ├─ start()                                                 │
│    └─ Call showNotification(isPlaying=true)                  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. MusicService.showNotification()                             │
│    - Create NotificationCompat.Builder()                       │
│    - Add Play/Pause/Stop action buttons                        │
│    - Call startForeground(NOTIFICATION_ID, notification)      │
│    - System shows persistent notification                      │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 9. Result                                                       │
│    ✓ Music plays in background                                 │
│    ✓ Notification visible with controls                        │
│    ✓ Service stays alive (foreground)                         │
│    ✓ User can navigate away or lock screen                    │
│    ✓ result.success(null) returned to Flutter                │
└─────────────────────────────────────────────────────────────────┘
```

---

### Scenario 2: User Presses Pause

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User taps Pause Button (or Notification)                    │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Flutter: playPause() called                                  │
│    - isPlaying = true → trigger pause                          │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. MethodChannel Call                                           │
│    platform.invokeMethod('pauseService')                       │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. MainActivity Handler                                         │
│    - Calls pauseMusicService()                                 │
│    - Creates Intent(MusicService, ACTION_PAUSE)               │
│    - Calls startService(intent)                               │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. MusicService.onStartCommand()                               │
│    - Detects ACTION_PAUSE                                      │
│    - Calls pauseAudio()                                        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. MusicService.pauseAudio()                                   │
│    ├─ mediaPlayer?.pause() if isPlaying                       │
│    └─ showNotification(isPlaying=false)                       │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. Result                                                       │
│    ✓ Music paused                                               │
│    ✓ Notification shows Play button                            │
│    ✓ Service still active (remains foreground)                │
│    ✓ Pressing Play resumes from pause point                   │
└─────────────────────────────────────────────────────────────────┘
```

---

### Scenario 3: App Goes to Background

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User Presses Home Button                                    │
│    App goes to background                                      │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Flutter Lifecycle                                            │
│    didChangeAppLifecycleState(AppLifecycleState.paused)       │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Check if Already Playing                                     │
│    if (state == AppLifecycleState.paused) {                    │
│      ✓ No action needed - service continues!                   │
│    }                                                            │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Result                                                       │
│    ✓ Music keeps playing                                        │
│    ✓ Notification visible with controls                        │
│    ✓ Service unaffected by app state                          │
│    ✓ System won't kill service (foreground)                   │
└─────────────────────────────────────────────────────────────────┘
```

---

### Scenario 4: User Returns to App

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User Taps App Icon or Returns                                │
│    App comes to foreground                                     │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Flutter Lifecycle                                            │
│    didChangeAppLifecycleState(AppLifecycleState.resumed)      │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Check State and Sync                                         │
│    if (state == AppLifecycleState.resumed && !isPlaying) {     │
│      // Only resume if UI shows paused                         │
│      await platform.invokeMethod('startService', {...})       │
│    }                                                            │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Result                                                       │
│    ✓ UI state synced with service                              │
│    ✓ Buttons show correct state                                │
│    ✓ No duplicated playback                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 💾 Data Flow: Asset Loading

```
┌──────────────────────────┐
│  Flutter Project Root    │
├──────────────────────────┤
│ assets/audio/            │
│ ├─ test1.mp3             │
│ └─ test_2.mp3            │
└──────────────┬───────────┘
               │
               │ Build time
               │ Included in APK (compressed)
               ▼
┌──────────────────────────────────────┐
│  APK Package                         │
├──────────────────────────────────────┤
│ assets/audio/test1.mp3 (compressed) │
│ assets/audio/test_2.mp3 (compressed)│
└──────────────┬──────────────────────┘
               │
               │ Runtime: Flutter calls
               │ platform.invokeMethod('startService', 
               │ {'filename': 'audio/test1.mp3'})
               ▼
┌──────────────────────────────────────┐
│  MainActivity Receives               │
├──────────────────────────────────────┤
│ Extracts filename: 'audio/test1.mp3' │
│ Passes to MusicService               │
└──────────────┬──────────────────────┘
               │
               │ copyAssetToCache()
               ▼
┌──────────────────────────────────────┐
│  Android Cache Directory             │
│  (/data/data/app/cache/)             │
├──────────────────────────────────────┤
│ audio_test1.mp3 (uncompressed)       │ ← Real file path
│ audio_test_2.mp3 (if played)         │
└──────────────┬──────────────────────┘
               │
               │ MediaPlayer uses path:
               │ /data/data/.../cache/audio_test1.mp3
               ▼
┌──────────────────────────────────────┐
│  MediaPlayer Playback                │
│  Audio streams to device speaker     │
└──────────────────────────────────────┘
```

---

## 🔐 Permission & Authorization Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ AndroidManifest.xml Declares Permissions                       │
├─────────────────────────────────────────────────────────────────┤
│ <uses-permission android:name=                                 │
│   "android.permission.FOREGROUND_SERVICE" />                  │
│ <uses-permission android:name=                                 │
│   "android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ Install time
                            │ (pre-API 31)
┌─────────────────────────────────────────────────────────────────┐
│ Runtime Permissions Check (API 31+)                            │
├─────────────────────────────────────────────────────────────────┤
│ Notification permission prompt                                 │
│ (Users can grant/deny)                                        │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ startForegroundService() Called                                 │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│ Android System Checks:                                          │
├─────────────────────────────────────────────────────────────────┤
│ ✓ FOREGROUND_SERVICE in manifest?                             │
│ ✓ FOREGROUND_SERVICE_MEDIA_PLAYBACK in manifest? (if API 31+) │
│ ✓ Notification permission granted? (if API 33+)              │
│ ✓ Service registered in manifest?                            │
│ ✓ foregroundServiceType="mediaPlayback"?                     │
└─────────────────────────────────────────────────────────────────┘
                            │
                  ┌─────────┴─────────┐
                  ▼ All OK            ▼ Missing
         Service Starts        Exception/Denial
         ✓                      ✗
```

---

## 📊 State Machine: MusicService

```
                    ┌────────────────────┐
                    │    IDLE STATE      │
                    │ (Service Created)  │
                    └────────┬───────────┘
                             │
                   ┌─────────┴──────────┐
                   │                    │
                   ▼                    ▼
            ACTION_PLAY          (App destroyed)
                   │                    │
                   ▼                    ▼
            ┌──────────────────┐   stopSelf()
            │  PLAYING STATE   │
            │ (MediaPlayer)    │
            └────┬─────┬───┬───┘
                 │     │   │
          ┌──────┘     │   └──────┐
          │            │         │
          ▼            ▼         ▼
    ACTION_PAUSE  ACTION_STOP  onCompletion()
          │            │         │
          ▼            ▼         ▼
    PAUSED STATE  stopSelf()  IDLE STATE
    (MediaPlayer)      │
    paused)       (cleanup)
          │            │
          │            ▼
          │      Service Destroyed
          │
    (can resume)
          │
          ├─→ ACTION_PLAY → PLAYING STATE
          │
          └─→ ACTION_STOP → stopSelf() → Service Destroyed
```

---

## 🔌 Method Channel Protocol

```
Flutter Side                          Android Side
─────────────────────────────────────────────────────────────
                                      MainActivitys.kt
main.dart                             override fun configureFlutterEngine()
                                      
│                                     │
├──invoke 'startService'──────────────▶│
│  {'filename': 'audio/test1.mp3'}   │  MethodChannel Handler
│                                     │  when (call.method) 
│  (awaits response)                  │    "startService" → {
│                                     │      startMusicService()
│                                     │      result.success(null)
│  ◀────result: success───────────────┤    }
│                                     │
│                                     │    startMusicService() {
│                                     │      Intent(ACTION_PLAY)
│                                     │      startForegroundService()
│                                     │    }
│                                     │
├──invoke 'pauseService'──────────────▶│
│  {} (no params)                     │  "pauseService" → {
│                                     │    pauseMusicService()
│  ◀────result: success───────────────┤    result.success(null)
│                                     │  }
│                                     │
├──invoke 'stopService'───────────────▶│
│  {} (no params)                     │  "stopService" → {
│                                     │    stopMusicService()
│  ◀────result: success───────────────┤    result.success(null)
│                                     │  }
│                                     │
```

---

## 📱 UI State Sync Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                Flutter UI (_MusicPlayerState)                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  isPlaying = false                                     │  │
│  │  currentMusicIndex = 0                                 │  │
│  │  showControls = false                                  │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────┬───────────────────────────────────────────────────┘
           │
           │ User Action:
           │ Tap play button
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  playPause() Function                                        │
│  ├─ showControls = true                                     │
│  ├─ platform.invokeMethod('startService', {...})           │
│  ├─ setState(() { isPlaying = !isPlaying })               │
│  │  (UI updates immediately)                               │
│  └─ MusicService starts in background                      │
└──────────┬───────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  UI State Updates                                            │
│  ├─ isPlaying = true        ◄─ Play icon → Pause icon      │
│  ├─ showControls = true      ◄─ Show controls               │
│  └─ Build tree rebuilds      ◄─ setState() triggers rebuild │
└──────────┬───────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────────────────────────────────────────────┐
│  Service State (Independent)                                │
│  ├─ mediaPlayer.start()                                    │
│  ├─ showNotification(true)                                 │
│  └─ startForeground()                                      │
└──────────────────────────────────────────────────────────────┘

Note: UI state and Service state are kept in sync through
      lifecycle methods and user interactions, but operate
      independently for robust background playback.
```

---

## 🎯 File Organization

```
first_app/
│
├── lib/
│   ├── main.dart ................................. Main UI & business logic
│   ├── liked_screen.dart .......................... Favorites screen
│   ├── music_details.dart ......................... Details page
│   └── db/
│       └── db_helper.dart ........................ SQLite for favorites
│
├── android/app/src/main/
│   ├── kotlin/com/example/first_app/
│   │   ├── MainActivity.kt ........................ MethodChannel bridge ✨
│   │   └── MusicService.kt ........................ Foreground service ✨
│   │
│   └── AndroidManifest.xml ........................ Permissions & registration ✨
│
├── assets/
│   ├── audio/
│   │   ├── test1.mp3 ............................. Audio file
│   │   └── test_2.mp3 ............................ Audio file
│   └── images/
│       ├── music.png
│       ├── bg.png
│       └── bg2.png
│
└── pubspec.yaml ................................... Dependencies (audioplayers removed)

✨ = Files created or modified for foreground service implementation
```

---

This comprehensive documentation provides visual understanding of how all components interact to deliver background music playback! 🎵
