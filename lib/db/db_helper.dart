import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('favorites.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        file TEXT NOT NULL,
        author TEXT,
        description TEXT
      )
    ''');
  }

  // ✅ INSERT
  Future<void> insertFavorite(Map<String, String> song) async {
    final db = await instance.database;

    await db.insert(
      'favorites',
      song,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ✅ GET ALL
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await instance.database;
    return await db.query('favorites');
  }

  // ✅ DELETE
  Future<void> deleteFavorite(String title) async {
    final db = await instance.database;

    await db.delete(
      'favorites',
      where: 'title = ?',
      whereArgs: [title],
    );
  }
}