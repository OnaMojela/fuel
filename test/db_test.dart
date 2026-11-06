import 'dart:convert';
import 'dart:io';

import 'package:calorie_tracker/data/db.dart';
import 'package:calorie_tracker/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _food = Food(id: 'x', name: 'Pap', source: FoodSource.za, per100g: Nutrients(calories: 104));

Entry _entry(String date) => Entry(
      date: date,
      meal: Meal.dinner,
      food: _food,
      servingLabel: 'g',
      servingGrams: 1,
      quantity: 250,
      createdAt: DateTime(2026, 10, 9, 19),
    );

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfiNoIsolate;
  late Directory tmp;
  var n = 0;
  final opened = <DiaryDb>[];
  String freshPath() => p.join(tmp.path, 'db${n++}.sqlite');
  // Tracks every database so they can be closed before the temp dir is
  // deleted (Windows refuses to delete open files).
  Future<DiaryDb> open(String path) async {
    final db = await DiaryDb.open(path: path, factory: factory);
    opened.add(db);
    return db;
  }

  setUpAll(() => tmp = Directory.systemTemp.createTempSync('diary_test'));
  tearDownAll(() async {
    for (final db in opened) {
      await db.close();
    }
    tmp.deleteSync(recursive: true);
  });

  test('upgrading a v1 database keeps entries and adds v2 tables', () async {
    // Build a v1 database file exactly as phase 1/2 shipped it.
    final path = freshPath();
    final v1 = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''CREATE TABLE entries (id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL,
              meal INTEGER NOT NULL, food_name TEXT NOT NULL, food_json TEXT NOT NULL, serving_label TEXT NOT NULL,
              serving_grams REAL NOT NULL, quantity REAL NOT NULL, created_at INTEGER NOT NULL)''');
            await db.execute('CREATE INDEX idx_entries_date ON entries(date)');
          },
        ));
    await v1.insert('entries', {
      'date': '2026-10-01',
      'meal': 3,
      'food_name': 'Pap',
      'food_json': _food.encode(),
      'serving_label': 'g',
      'serving_grams': 1.0,
      'quantity': 250.0,
      'created_at': 0,
    });
    await v1.close();

    // Re-open through the app, as after an app update: runs the v1→v2 migration.
    final db = await open(path);
    expect((await db.entriesFor('2026-10-01')).single.food.name, 'Pap');
    await db.setWeight('2026-10-01', 80);
    expect((await db.weights()).single.kg, 80);
    expect(await db.recipes(), isEmpty);
  });

  group('v2 store', () {
    late DiaryDb db;
    setUp(() async {
      db = await open(freshPath());
    });

    test('one weigh-in per day, replaced on re-log, sorted', () async {
      await db.setWeight('2026-10-02', 80.5);
      await db.setWeight('2026-10-01', 81.0);
      await db.setWeight('2026-10-02', 80.2);
      final w = await db.weights();
      expect(w.map((e) => e.date), ['2026-10-01', '2026-10-02']);
      expect(w.last.kg, 80.2);
      await db.deleteWeight('2026-10-01');
      expect(await db.weights(), hasLength(1));
    });

    test('recipes save, update, delete', () async {
      final id = await db.saveRecipe(const Recipe(name: 'Stew', servings: 4, ingredients: [Ingredient(_food, 500)]));
      var all = await db.recipes();
      expect(all.single.id, id);
      await db.saveRecipe(all.single.copyWith(name: 'Beef stew'));
      all = await db.recipes();
      expect(all.single.name, 'Beef stew');
      await db.deleteRecipe(id);
      expect(await db.recipes(), isEmpty);
    });

    test('export → import round-trip replaces data', () async {
      await db.insert(_entry('2026-10-09'));
      await db.setWeight('2026-10-09', 79);
      await db.saveRecipe(const Recipe(name: 'Pap tart', servings: 2, ingredients: [Ingredient(_food, 300)]));
      // Through real JSON, as the backup file does.
      final backup = jsonDecode(jsonEncode(await db.exportAll())) as Map<String, dynamic>;

      final other = await open(freshPath());
      await other.insert(_entry('2020-01-01')); // will be replaced
      await other.importAll(backup);
      expect(await other.entriesFor('2020-01-01'), isEmpty);
      expect((await other.entriesFor('2026-10-09')).single.grams, 250);
      expect((await other.weights()).single.kg, 79);
      expect((await other.recipes()).single.name, 'Pap tart');
    });
  });
}
