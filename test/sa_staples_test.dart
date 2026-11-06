import 'package:calorie_tracker/data/food_api/sa_staples.dart';
import 'package:calorie_tracker/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds dishes by local names and aliases', () {
    expect(searchSaStaples('pap').first.name, 'Pap (stiff maize porridge)');
    expect(searchSaStaples('mieliepap').first.name, 'Pap (stiff maize porridge)');
    expect(searchSaStaples('amagwinya').first.name, 'Vetkoek (amagwinya)');
    expect(searchSaStaples('boerewors').first.name, 'Boerewors (grilled)');
    expect(searchSaStaples('bunny').first.name, startsWith('Bunny chow'));
    expect(searchSaStaples('umngqusho').first.name, 'Samp and beans (umngqusho)');
  });

  test('multi-word queries need every word', () {
    expect(searchSaStaples('vetkoek mince').map((f) => f.name), contains('Vetkoek with mince'));
    expect(searchSaStaples('biltong lean').first.name, 'Biltong, lean beef');
    expect(searchSaStaples('xyz nothing'), isEmpty);
  });

  test('staples become foods with servings and SA source', () {
    final f = searchSaStaples('biltong').first;
    expect(f.source, FoodSource.za);
    expect(f.servings, isNotEmpty);
    expect(f.forGrams(30).protein, greaterThan(10));
  });

  test('every staple has sane nutrition', () {
    for (final s in saStaples) {
      final n = s.n;
      // Energy from macros should roughly match the stated calories (Atwater ±25%, min slack for tea).
      final atwater = n.protein * 4 + n.carbs * 4 + n.fat * 9;
      expect((atwater - n.calories).abs(), lessThan(n.calories * 0.25 + 10), reason: s.name);
      expect(n.fiber, lessThanOrEqualTo(n.carbs + 10), reason: s.name);
      expect(n.saturatedFat, lessThanOrEqualTo(n.fat), reason: s.name);
      expect(s.servings, isNotEmpty, reason: s.name);
    }
  });
}
