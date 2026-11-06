import 'dart:convert';

/// Nutrient amounts. For a [Food] these are per 100 g; for an entry they are
/// for the eaten amount. Masses in g, except sodium/cholesterol/potassium (mg).
class Nutrients {
  const Nutrients({
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.sugar = 0,
    this.saturatedFat = 0,
    this.sodium = 0,
    this.cholesterol = 0,
    this.potassium = 0,
  });

  final double calories, protein, carbs, fat, fiber, sugar, saturatedFat, sodium, cholesterol, potassium;

  static const zero = Nutrients();

  double get netCarbs => (carbs - fiber).clamp(0, double.infinity);

  Nutrients operator +(Nutrients o) => Nutrients(
        calories: calories + o.calories,
        protein: protein + o.protein,
        carbs: carbs + o.carbs,
        fat: fat + o.fat,
        fiber: fiber + o.fiber,
        sugar: sugar + o.sugar,
        saturatedFat: saturatedFat + o.saturatedFat,
        sodium: sodium + o.sodium,
        cholesterol: cholesterol + o.cholesterol,
        potassium: potassium + o.potassium,
      );

  Nutrients operator *(double f) => Nutrients(
        calories: calories * f,
        protein: protein * f,
        carbs: carbs * f,
        fat: fat * f,
        fiber: fiber * f,
        sugar: sugar * f,
        saturatedFat: saturatedFat * f,
        sodium: sodium * f,
        cholesterol: cholesterol * f,
        potassium: potassium * f,
      );

  Map<String, dynamic> toJson() => {
        'cal': calories,
        'p': protein,
        'c': carbs,
        'f': fat,
        'fib': fiber,
        'sug': sugar,
        'sat': saturatedFat,
        'na': sodium,
        'chol': cholesterol,
        'k': potassium,
      };

  factory Nutrients.fromJson(Map<String, dynamic> j) {
    double g(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return Nutrients(
      calories: g('cal'),
      protein: g('p'),
      carbs: g('c'),
      fat: g('f'),
      fiber: g('fib'),
      sugar: g('sug'),
      saturatedFat: g('sat'),
      sodium: g('na'),
      cholesterol: g('chol'),
      potassium: g('k'),
    );
  }
}

class Serving {
  const Serving(this.label, this.grams);
  final String label;
  final double grams;

  Map<String, dynamic> toJson() => {'l': label, 'g': grams};
  factory Serving.fromJson(Map<String, dynamic> j) => Serving(j['l'] as String, (j['g'] as num).toDouble());
}

enum FoodSource { usda, off, custom, ai, za }

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.per100g,
    required this.source,
    this.brand,
    this.servings = const [],
  });

  final String id; // source-specific id (fdcId, barcode, ...)
  final String name;
  final String? brand;
  final Nutrients per100g;
  final FoodSource source;
  final List<Serving> servings; // extra servings beyond "g" and "100 g"

  /// Servings offered in the picker: food-specific ones first, then defaults.
  List<Serving> get allServings => [...servings, const Serving('100 g', 100), const Serving('g', 1)];

  Nutrients forGrams(double grams) => per100g * (grams / 100);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'n': per100g.toJson(),
        'src': source.name,
        'sv': servings.map((s) => s.toJson()).toList(),
      };

  factory Food.fromJson(Map<String, dynamic> j) => Food(
        id: j['id'] as String,
        name: j['name'] as String,
        brand: j['brand'] as String?,
        per100g: Nutrients.fromJson(j['n'] as Map<String, dynamic>),
        source: FoodSource.values.byName(j['src'] as String),
        servings: ((j['sv'] as List?) ?? []).map((e) => Serving.fromJson(e as Map<String, dynamic>)).toList(),
      );

  String encode() => jsonEncode(toJson());
  static Food decode(String s) => Food.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

enum Meal {
  breakfast('Breakfast'),
  lunch('Lunch'),
  dinner('Dinner'),
  snacks('Snacks');

  const Meal(this.label);
  final String label;

  /// Sensible default meal for the current time of day.
  static Meal forNow([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 11) return breakfast;
    if (h < 16) return lunch;
    if (h < 21) return dinner;
    return snacks;
  }
}

/// A logged food: which food, how much, when.
class Entry {
  const Entry({
    this.id,
    required this.date,
    required this.meal,
    required this.food,
    required this.servingLabel,
    required this.servingGrams,
    required this.quantity,
    required this.createdAt,
  });

  final int? id;
  final String date; // yyyy-MM-dd
  final Meal meal;
  final Food food;
  final String servingLabel;
  final double servingGrams; // grams in one serving
  final double quantity; // number of servings
  final DateTime createdAt;

  double get grams => servingGrams * quantity;
  Nutrients get nutrients => food.forGrams(grams);

  String get amountLabel {
    final q = quantity == quantity.roundToDouble() ? quantity.toInt().toString() : quantity.toStringAsFixed(2);
    if (servingLabel == 'g') return '$q g';
    return '$q × $servingLabel';
  }
}

class WeightEntry {
  const WeightEntry(this.date, this.kg);
  final String date; // yyyy-MM-dd
  final double kg;
}

/// One food inside a recipe, with the grams used.
class Ingredient {
  const Ingredient(this.food, this.grams);
  final Food food;
  final double grams;

  Map<String, dynamic> toJson() => {'food': food.toJson(), 'g': grams};
  factory Ingredient.fromJson(Map<String, dynamic> j) =>
      Ingredient(Food.fromJson(j['food'] as Map<String, dynamic>), (j['g'] as num).toDouble());
}

/// A home recipe: ingredients combined, split into servings.
class Recipe {
  const Recipe({this.id, required this.name, required this.servings, required this.ingredients});
  final int? id;
  final String name;
  final int servings;
  final List<Ingredient> ingredients;

  double get totalGrams => ingredients.fold(0, (a, i) => a + i.grams);
  Nutrients get total => ingredients.fold(Nutrients.zero, (a, i) => a + i.food.forGrams(i.grams));
  Nutrients get perServing => servings <= 0 ? total : total * (1 / servings);

  /// The recipe as a loggable food: nutrients per 100 g of the finished dish,
  /// with "1 serving" as the default portion.
  Food toFood() {
    final g = totalGrams;
    final perServingG = servings <= 0 ? g : g / servings;
    return Food(
      id: 'recipe:$id',
      name: name,
      brand: 'My recipe',
      source: FoodSource.custom,
      per100g: g <= 0 ? Nutrients.zero : total * (100 / g),
      servings: [if (perServingG > 0) Serving('1 serving (${perServingG.round()} g)', perServingG)],
    );
  }

  String encode() => jsonEncode({
        'name': name,
        'servings': servings,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
      });

  static Recipe decode(int id, String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return Recipe(
      id: id,
      name: j['name'] as String,
      servings: (j['servings'] as num).toInt(),
      ingredients: [for (final i in j['ingredients'] as List) Ingredient.fromJson(i as Map<String, dynamic>)],
    );
  }

  Recipe copyWith({String? name, int? servings, List<Ingredient>? ingredients}) => Recipe(
        id: id,
        name: name ?? this.name,
        servings: servings ?? this.servings,
        ingredients: ingredients ?? this.ingredients,
      );
}

class Goals {
  const Goals({
    this.calories = 2000,
    this.carbPct = 40,
    this.proteinPct = 30,
    this.fatPct = 30,
    this.sex = 'female',
    this.age = 28,
    this.heightCm = 168,
    this.weightKg = 70,
    this.activity = 1.375,
    this.weeklyChangeKg = 0,
    this.isSet = false,
  });

  final double calories;
  final double carbPct, proteinPct, fatPct; // sum to 100
  final String sex;
  final int age;
  final double heightCm, weightKg;
  final double activity; // TDEE multiplier
  final double weeklyChangeKg; // negative = lose
  final bool isSet;

  double get carbsG => calories * carbPct / 100 / 4;
  double get proteinG => calories * proteinPct / 100 / 4;
  double get fatG => calories * fatPct / 100 / 9;

  // Heart-healthy targets (AHA-style): sat fat < 10% kcal, sodium < 2300 mg, fiber >= 14 g / 1000 kcal.
  double get satFatLimitG => calories * 0.10 / 9;
  double get sodiumLimitMg => 2300;
  double get fiberTargetG => calories / 1000 * 14;
  // Low-carb: net carbs under 100 g/day.
  double get netCarbLimitG => 100;
  // WHO: free sugars under 10% of energy.
  double get sugarLimitG => calories * 0.10 / 4;
  double get cholesterolLimitMg => 300;
  double get potassiumTargetMg => 3500;

  Goals copyWith({
    double? calories,
    double? carbPct,
    double? proteinPct,
    double? fatPct,
    String? sex,
    int? age,
    double? heightCm,
    double? weightKg,
    double? activity,
    double? weeklyChangeKg,
    bool? isSet,
  }) =>
      Goals(
        calories: calories ?? this.calories,
        carbPct: carbPct ?? this.carbPct,
        proteinPct: proteinPct ?? this.proteinPct,
        fatPct: fatPct ?? this.fatPct,
        sex: sex ?? this.sex,
        age: age ?? this.age,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activity: activity ?? this.activity,
        weeklyChangeKg: weeklyChangeKg ?? this.weeklyChangeKg,
        isSet: isSet ?? this.isSet,
      );

  Map<String, dynamic> toJson() => {
        'cal': calories,
        'cp': carbPct,
        'pp': proteinPct,
        'fp': fatPct,
        'sex': sex,
        'age': age,
        'h': heightCm,
        'w': weightKg,
        'act': activity,
        'wk': weeklyChangeKg,
        'set': isSet,
      };

  factory Goals.fromJson(Map<String, dynamic> j) => Goals(
        calories: (j['cal'] as num).toDouble(),
        carbPct: (j['cp'] as num).toDouble(),
        proteinPct: (j['pp'] as num).toDouble(),
        fatPct: (j['fp'] as num).toDouble(),
        sex: j['sex'] as String,
        age: j['age'] as int,
        heightCm: (j['h'] as num).toDouble(),
        weightKg: (j['w'] as num).toDouble(),
        activity: (j['act'] as num).toDouble(),
        weeklyChangeKg: (j['wk'] as num).toDouble(),
        isSet: j['set'] as bool? ?? true,
      );
}
