class Song {
  const Song({
    required this.title,
    required this.file,
    required this.author,
    required this.description,
  });

  final String title;
  final String file;
  final String author;
  final String description;

  factory Song.fromMap(Map<dynamic, dynamic> map) {
    return Song(
      title: map['title'] as String? ?? '',
      file: map['file'] as String? ?? '',
      author: map['author'] as String? ?? '',
      description: map['description'] as String? ?? '',
    );
  }

  Map<String, String> toMap() {
    return {
      'title': title,
      'file': file,
      'author': author,
      'description': description,
    };
  }
}
