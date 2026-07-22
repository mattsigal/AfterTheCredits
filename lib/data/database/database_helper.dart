import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/movie_model.dart';
import '../models/upcoming_movie_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('after_the_credits.db');
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

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cached_movies (
        url TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        posterUrl TEXT,
        rating TEXT,
        director TEXT,
        writers TEXT,
        starring TEXT,
        releaseDate TEXT,
        runningTime TEXT,
        officialSiteUrl TEXT,
        imdbUrl TEXT,
        synopsis TEXT,
        duringCreditsYesNo INTEGER,
        duringCreditsText TEXT,
        afterCreditsYesNo INTEGER,
        afterCreditsText TEXT,
        stingerRatingText TEXT,
        cachedAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE upcoming_movies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        movieUrl TEXT NOT NULL,
        movieTitle TEXT NOT NULL,
        posterUrl TEXT,
        plannedDate INTEGER NOT NULL,
        duringCreditsYesNo INTEGER,
        afterCreditsYesNo INTEGER,
        notes TEXT
      )
    ''');
  }

  // --- Movie Cache Operations ---

  Future<void> saveCachedMovie(MovieModel movie) async {
    final db = await instance.database;
    await db.insert(
      'cached_movies',
      movie.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MovieModel?> getCachedMovie(String url) async {
    final db = await instance.database;
    final maps = await db.query(
      'cached_movies',
      where: 'url = ?',
      whereArgs: [url],
    );

    if (maps.isNotEmpty) {
      return MovieModel.fromMap(maps.first);
    }
    return null;
  }

  Future<MovieModel?> searchCachedMovieByTitle(String title) async {
    final db = await instance.database;
    final maps = await db.query(
      'cached_movies',
      where: 'title LIKE ?',
      whereArgs: ['%$title%'],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return MovieModel.fromMap(maps.first);
    }
    return null;
  }

  // --- Upcoming Movies Operations ---

  Future<int> insertUpcomingMovie(UpcomingMovieModel movie) async {
    final db = await instance.database;
    return await db.insert('upcoming_movies', movie.toMap());
  }

  Future<List<UpcomingMovieModel>> getUpcomingMovies() async {
    final db = await instance.database;
    final maps = await db.query(
      'upcoming_movies',
      orderBy: 'plannedDate ASC',
    );

    return maps.map((m) => UpcomingMovieModel.fromMap(m)).toList();
  }

  Future<void> deleteUpcomingMovie(int id) async {
    final db = await instance.database;
    await db.delete(
      'upcoming_movies',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateUpcomingStingerStatus(
      String movieUrl, bool? during, bool? after) async {
    final db = await instance.database;
    await db.update(
      'upcoming_movies',
      {
        'duringCreditsYesNo': during == null ? null : (during ? 1 : 0),
        'afterCreditsYesNo': after == null ? null : (after ? 1 : 0),
      },
      where: 'movieUrl = ?',
      whereArgs: [movieUrl],
    );
  }

  Future<void> clearAllCache() async {
    final db = await instance.database;
    await db.delete('cached_movies');
  }
}
