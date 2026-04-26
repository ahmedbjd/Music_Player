import 'package:flutter/material.dart';
import 'package:first_app/db/db_helper.dart';
import 'package:first_app/music_details.dart';

class LikedScreen extends StatefulWidget {
  const LikedScreen({super.key});

  @override
  State<LikedScreen> createState() => _LikedScreenState();
}

class _LikedScreenState extends State<LikedScreen> {
  List<Map<String, dynamic>> likedSongs = [];
  Map<String, dynamic>? selectedMusic;

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final data = await DatabaseHelper.instance.getFavorites();

    setState(() {
      likedSongs = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 600;

        return Scaffold(
          appBar: AppBar(title: const Text('Liked Songs')),

          body: likedSongs.isEmpty
              ? const Center(
                  child: Text(
                    'No liked songs yet!',
                    style: TextStyle(fontSize: 24),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 600;

                    return Row(
                      children: [
                        // ✅ LEFT SIDE (FIXED WIDTH)
                        SizedBox(
                          width: isTablet ? 300 : constraints.maxWidth,
                          child: ListView.builder(
                            itemCount: likedSongs.length,
                            itemBuilder: (context, index) {
                              final music = likedSongs[index];
                              // final isSelected =
                              //     selectedMusic?['title'] == music['title'];

                            return ListTile(
                              leading: const Icon(Icons.music_note),
                              title: Text(music['title']),

                              onTap: () {
                                if (isTablet) {
                                  setState(() {
                                    selectedMusic = music;
                                  });
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MusicDetails(music: music),
                                    ),
                                  );
                                }
                              },

                              // 🆕 LONG PRESS → DELETE
                              onLongPress: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text("Delete Favorite"),
                                      content: Text(
                                        "Do you want to remove '${music['title']}' from favorites?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text(
                                            "Delete",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirm == true) {
                                  await DatabaseHelper.instance
                                      .deleteFavorite(music['title']);

                                  // refresh list
                                  await loadFavorites();

                                  // if deleted song was selected → reset right panel
                                  if (selectedMusic?['title'] == music['title']) {
                                    setState(() {
                                      selectedMusic = likedSongs.isNotEmpty ? likedSongs[0] : null;
                                    });
                                  }
                                }
                              },
                            );                          
                              },
                          ),
                        ),

                        // ✅ RIGHT SIDE (ONLY ON TABLET)
                        if (isTablet)
                          Expanded(
                            child: selectedMusic == null
                                ? const SizedBox.shrink()
                                : MusicDetails(music: selectedMusic!),
                          ),
                      ],
                    );
                  },
                ),        
      );
      },
    );
  }
}