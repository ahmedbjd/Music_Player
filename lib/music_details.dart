import 'package:flutter/material.dart';

class MusicDetails extends StatelessWidget {
  final Map<String, dynamic> music;

  const MusicDetails({super.key, required this.music});

@override
Widget build(BuildContext context) {
  final isWide = MediaQuery.of(context).size.width >= 600;

  final content = SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          music['title'] ?? '',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          music['author'] ?? 'Unknown Artist',
          style: const TextStyle(fontSize: 18),
        ),

        const SizedBox(height: 20),

        Text(
          music['description'] ?? '',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  // 📱 mobile → full page with scroll
  if (!isWide) {
    return Scaffold(
      appBar: AppBar(
        title: Text(music['title'] ?? ''),
      ),
      body: content,
    );
  }

  // 💻 tablet/split → just scrollable content (NO scaffold)
  return content;
}}