import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

/// Local SQLite store for the food diary. Each entry keeps a JSON snapshot
/// of the food so logs stay correct even if the source database changes.
class DiaryDb {
  DiaryDb(this._db);
  final Database _db;

  static Future<DiaryDb> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), 'diary.db');
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE entries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date TEXT NOT NULL,
              meal INTEGER NOT NULL,
              food_name TEXT NOT NULL,
              food_json TEXT NOT NULL,
              serving_label TEXT NOT NULL,
              serving_grams REAL NOT NULL,
              quantity REAL NOT NULL,
              created_at INTEGER NOT NULL
            )''');
          await db.execute('CREATE INDEX idx_entries_date ON entries(date)');
          await _createV2(db);
        },
        onUpgrade: (db, from, to) async {
          if (from < 2) await _createV2(db);
        },
      ),
    );
    return DiaryDb(db);
  }

  // v2: weight log + recipes.
  static Future<void> _createV2(Database db) async {
    await db.execute('CREATE TABLE weights (date TEXT PRIMARY KEY, kg REAL NOT NULL)');
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
  }

  Future<void> close() => _db.close();

  // ---------- Weights ----------

  /// One weigh-in per day; logging again the same day replaces it.
  Future<void> setWeight(String date, double kg) =>
      _db.insert('weights', {'date': date, 'kg': kg}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteWeight(String date) => _db.delete('weights', where: 'date = ?', whereArgs: [date]);

  Future<List<WeightEntry>> weights() async {
    final rows = await _db.query('weights', orderBy: 'date');
    return [for (final r in rows) WeightEntry(r['date'] as String, (r['kg'] as num).toDouble())];
  }

  // ---------- Recipes ----------

  Future<List<Recipe>> recipes() async {
    final rows = await _db.query('recipes', orderBy: 'updated_at DESC');
    return [for (final r in rows) Recipe.decode(r['id'] as int, r['json'] as String)];
  }

  Future<int> saveRecipe(Recipe r) async {
    final row = {'json': r.encode(), 'updated_at': DateTime.now().millisecondsSinceEpoch};
    if (r.id == null) return _db.insert('recipes', row);
    await _db.update('recipes', row, where: 'id = ?', whereArgs: [r.id]);
    return r.id!;
  }

  Future<void> deleteRecipe(int id) => _db.delete('recipes', where: 'id = ?', whereArgs: [id]);

  // ---------- Backup ----------

  /// Everything the user has entered, as plain JSON-able maps.
  Future<Map<String, Object?>> exportAll() async => {
        'version': 2,
        'exportedAt': DateTime.now().toIso8601String(),
        'entries': await _db.query('entries'),
        'weights': await _db.query('weights'),
        'recipes': await _db.query('recipes'),
      };

  /// Replaces all local data with a backup made by [exportAll].
  Future<void> importAll(Map<String, dynamic> data) async {
    List<Map<String, Object?>> rows(String k) =>
        [for (final r in (data[k] as List? ?? const [])) Map<String, Object?>.from(r as Map)];
    final entries = rows('entries'), weights = rows('weights'), recipes = rows('recipes');
    await _db.transaction((tx) async {
      for (final t in ['entries', 'weights', 'recipes']) {
        await tx.delete(t);
      }
      final b = tx.batch();
      for (final r in entries) {
        b.insert('entries', r);
      }
      for (final r in weights) {
        b.insert('weights', r);
      }
      for (final r in recipes) {
        b.insert('recipes', r);
      }
      await b.commit(noResult: true);
    });
  }

  Map<String, Object?> _toRow(Entry e) => {
        'date': e.date,
        'meal': e.meal.index,
        'food_name': e.food.name,
        'food_json': e.food.encode(),
        'serving_label': e.servingLabel,
        'serving_grams': e.servingGrams,
        'quantity': e.quantity,
        'created_at': e.createdAt.millisecondsSinceEpoch,
      };

  Entry _fromRow(Map<String, Object?> r) => Entry(
        id: r['id'] as int,
        date: r['date'] as String,
        meal: Meal.values[r['meal'] as int],
        food: Food.decode(r['food_json'] as String),
        servingLabel: r['serving_label'] as String,
        servingGrams: (r['serving_grams'] as num).toDouble(),
        quantity: (r['quantity'] as num).toDouble(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      );

  Future<List<Entry>> entriesFor(String date) async {
    final rows = await _db.query('entries', where: 'date = ?', whereArgs: [date], orderBy: 'created_at');
    return rows.map(_fromRow).toList();
  }

  Future<List<Entry>> entriesBetween(String from, String to) async {
    final rows = await _db.query('entries',
        where: 'date >= ? AND date <= ?', whereArgs: [from, to], orderBy: 'date, created_at');
    return rows.map(_fromRow).toList();
  }

  Future<int> insert(Entry e) => _db.insert('entries', _toRow(e));

  Future<void> update(Entry e) =>
      _db.update('entries', _toRow(e), where: 'id = ?', whereArgs: [e.id]);

  Future<void> delete(int id) => _db.delete('entries', where: 'id = ?', whereArgs: [id]);

  /// Most recently logged distinct foods, newest first.
  Future<List<Food>> recentFoods({int limit = 20}) async {
    final rows = await _db.rawQuery('''
      SELECT food_json, MAX(created_at) AS last FROM entries
      GROUP BY food_name ORDER BY last DESC LIMIT ?''', [limit]);
    return rows.map((r) => Food.decode(r['food_json'] as String)).toList();
  }
}
