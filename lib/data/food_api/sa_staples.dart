import '../../domain/models.dart';

/// Built-in South African dishes and staples that packaged-food databases
/// don't cover. Values are typical per-100 g estimates for the dish as usually
/// prepared (recipes vary a lot), so the UI labels them "approx.".
/// Searched locally: instant and offline.
class SaStaple {
  const SaStaple(this.name, this.aliases, this.n, this.servings);
  final String name;
  final List<String> aliases;
  final Nutrients n;
  final List<Serving> servings;

  Food toFood() => Food(
        id: 'za:${name.toLowerCase()}',
        name: name,
        brand: 'SA staple · approx.',
        source: FoodSource.za,
        per100g: n,
        servings: servings,
      );
}

Nutrients _n(double cal, double p, double c, double f,
        {double fib = 0, double sug = 0, double sat = 0, double na = 0, double chol = 0}) =>
    Nutrients(
        calories: cal, protein: p, carbs: c, fat: f, fiber: fib, sugar: sug, saturatedFat: sat, sodium: na, cholesterol: chol);

const _cup = 'cup';

final saStaples = <SaStaple>[
  // ---- Maize, sorghum & breads
  SaStaple('Pap (stiff maize porridge)', ['mieliepap', 'pap', 'ugali', 'bogobe', 'vuswa', 'sadza', 'stywe pap', 'isitshwala'],
      _n(104, 2.4, 22.5, 0.5, fib: 1.1, sug: 0.2, sat: 0.1, na: 2), const [Serving('1 $_cup (250 g)', 250), Serving('1 scoop (150 g)', 150)]),
  SaStaple('Soft maize porridge', ['slap pap', 'soft pap', 'maize porridge', 'breakfast porridge', 'motogo'],
      _n(55, 1.2, 12, 0.3, fib: 0.5, na: 2), const [Serving('1 bowl (250 g)', 250)]),
  SaStaple('Phutu (krummelpap)', ['uphuthu', 'krummelpap', 'crumbly pap', 'putu'],
      _n(160, 3.6, 34, 0.8, fib: 1.6, na: 3), const [Serving('1 $_cup (150 g)', 150)]),
  SaStaple('Ting (fermented sorghum porridge)', ['ting', 'sorghum porridge', 'mabele', 'bogobe jwa mabele'],
      _n(70, 1.8, 14.5, 0.6, fib: 1, na: 2), const [Serving('1 bowl (250 g)', 250)]),
  SaStaple('Samp (cooked)', ['samp', 'stampmielies', 'isitambu'],
      _n(100, 2.2, 21, 0.6, fib: 2, na: 3), const [Serving('1 $_cup (180 g)', 180)]),
  SaStaple('Samp and beans (umngqusho)', ['umngqusho', 'samp and beans', 'dikgobe', 'isitambu nobhontshisi'],
      _n(120, 4.5, 22, 0.7, fib: 4.5, na: 120), const [Serving('1 $_cup (200 g)', 200)]),
  SaStaple('Vetkoek (amagwinya)', ['vetkoek', 'amagwinya', 'magwinya', 'fat cake', 'fatcake', 'makoenya'],
      _n(330, 7, 45, 14, fib: 1.8, sug: 5, sat: 3, na: 350), const [Serving('1 vetkoek (80 g)', 80)]),
  SaStaple('Vetkoek with mince', ['vetkoek mince', 'vetkoek and mince'],
      _n(280, 10, 30, 13, fib: 1.8, sug: 4, sat: 4, na: 400, chol: 25), const [Serving('1 vetkoek (180 g)', 180)]),
  SaStaple('Dombolo (steamed bread)', ['dombolo', 'ujeqe', 'steamed bread', 'dumpling'],
      _n(240, 7, 48, 2, fib: 2, sug: 3, sat: 0.5, na: 380), const [Serving('1 piece (100 g)', 100)]),
  SaStaple('Roosterkoek', ['roosterkoek', 'braai bread', 'grill bread'],
      _n(260, 8, 50, 3, fib: 2.2, sug: 3, sat: 0.6, na: 420), const [Serving('1 roll (90 g)', 90)]),
  SaStaple('Roti', ['roti', 'rooti', 'chapati'],
      _n(300, 8, 46, 9, fib: 2.5, sug: 1.5, sat: 2.5, na: 380), const [Serving('1 roti (80 g)', 80)]),
  SaStaple('Rusk (buttermilk)', ['rusk', 'beskuit', 'ouma rusk', 'karringmelk beskuit'],
      _n(410, 8, 64, 13, fib: 3, sug: 18, sat: 6, na: 380), const [Serving('1 rusk (35 g)', 35)]),

  // ---- Meat & mains
  SaStaple('Boerewors (grilled)', ['boerewors', 'wors', 'sausage braai', 'farmer sausage'],
      _n(300, 16, 2, 26, sat: 10, na: 750, chol: 70), const [Serving('1 portion (120 g)', 120), Serving('1 coil slice (80 g)', 80)]),
  SaStaple('Biltong, lean beef', ['biltong', 'lean biltong', 'dried meat'],
      _n(260, 52, 2, 4.5, sat: 1.8, na: 1900, chol: 120), const [Serving('1 handful (30 g)', 30), Serving('1 bag (50 g)', 50)]),
  SaStaple('Biltong, fatty beef', ['fatty biltong', 'biltong with fat', 'wet biltong'],
      _n(380, 45, 2, 22, sat: 9, na: 1800, chol: 120), const [Serving('1 handful (30 g)', 30)]),
  SaStaple('Droëwors', ['droewors', 'droëwors', 'dry wors', 'dried sausage'],
      _n(470, 40, 2, 34, sat: 14, na: 1700, chol: 110), const [Serving('1 stick (20 g)', 20)]),
  SaStaple('Bobotie', ['bobotie'],
      _n(170, 12, 8, 10, fib: 1, sug: 4, sat: 4, na: 350, chol: 80), const [Serving('1 portion (200 g)', 200)]),
  SaStaple('Sosatie', ['sosatie', 'kebab', 'skewer'],
      _n(210, 20, 6, 12, sug: 5, sat: 4.5, na: 450, chol: 65), const [Serving('1 skewer (120 g)', 120)]),
  SaStaple('Potjiekos (beef & veg)', ['potjiekos', 'potjie', 'stew pot'],
      _n(140, 10, 7, 8, fib: 1.5, sug: 2.5, sat: 3, na: 320, chol: 35), const [Serving('1 plate (350 g)', 350)]),
  SaStaple('Bredie (lamb & tomato stew)', ['bredie', 'tamatiebredie', 'waterblommetjiebredie', 'lamb stew'],
      _n(140, 10, 6, 8.5, fib: 1.2, sug: 3, sat: 3.5, na: 300, chol: 40), const [Serving('1 plate (300 g)', 300)]),
  SaStaple('Chicken breyani', ['breyani', 'biryani', 'biriyani'],
      _n(180, 9, 22, 6, fib: 1, sug: 1, sat: 2, na: 380, chol: 30), const [Serving('1 plate (350 g)', 350)]),
  SaStaple('Durban chicken curry', ['curry', 'chicken curry', 'durban curry'],
      _n(150, 13, 5, 9, fib: 1.2, sug: 2, sat: 2.5, na: 420, chol: 50), const [Serving('1 $_cup (250 g)', 250)]),
  SaStaple('Bunny chow (quarter, curry)', ['bunny chow', 'bunny', 'quarter bunny'],
      _n(200, 8, 24, 8, fib: 2, sug: 3, sat: 2.5, na: 380, chol: 20), const [Serving('1 quarter (450 g)', 450), Serving('1 half (850 g)', 850)]),
  SaStaple('Kota', ['kota', 'spatlo', 'sphatlho', 'skhambane'],
      _n(250, 8, 28, 12, fib: 2, sug: 4, sat: 4, na: 600, chol: 30), const [Serving('1 kota (500 g)', 500)]),
  SaStaple('Gatsby', ['gatsby', 'gatsby sandwich'],
      _n(230, 9, 27, 10, fib: 2, sug: 3, sat: 3, na: 500, chol: 25), const [Serving('1/4 gatsby (400 g)', 400)]),
  SaStaple('Mogodu (tripe, cooked)', ['mogodu', 'tripe', 'ulusu', 'pens en pootjies'],
      _n(95, 12, 0, 4.5, sat: 1.8, na: 90, chol: 150), const [Serving('1 portion (200 g)', 200)]),
  SaStaple('Chicken feet (walkie talkies)', ['chicken feet', 'walkie talkies', 'maotwana', 'runaways'],
      _n(215, 19, 0.2, 15, sat: 4, na: 70, chol: 85), const [Serving('1 portion (100 g)', 100)]),
  SaStaple('Mopane worms (dried)', ['mopane', 'mashonzha', 'masonja', 'mopani worms'],
      _n(430, 56, 7, 16, fib: 10, sat: 6, na: 400), const [Serving('1 handful (30 g)', 30)]),
  SaStaple('Polony', ['polony', 'bologna'],
      _n(250, 11, 6, 20, sug: 1.5, sat: 7.5, na: 1000, chol: 55), const [Serving('2 slices (40 g)', 40)]),
  SaStaple('Russian sausage (fried)', ['russian', 'russian sausage', 'vienna'],
      _n(300, 12, 4, 26, sat: 9.5, na: 1000, chol: 60), const [Serving('1 russian (100 g)', 100)]),

  // ---- Veg, sides & relishes
  SaStaple('Chakalaka', ['chakalaka'],
      _n(65, 2, 9, 2.5, fib: 2.5, sug: 4, sat: 0.4, na: 300), const [Serving('½ $_cup (125 g)', 125)]),
  SaStaple('Morogo (wild spinach, cooked)', ['morogo', 'imifino', 'muroho', 'marog', 'african spinach'],
      _n(40, 3.5, 4, 1.2, fib: 3, sug: 0.5, sat: 0.2, na: 60), const [Serving('1 $_cup (150 g)', 150)]),
  SaStaple('Tomato & onion relish (smoor)', ['smoor', 'tamatie en uie', 'sheba', 'gravy relish', 'tomato relish'],
      _n(60, 1.2, 7, 3, fib: 1.5, sug: 4.5, sat: 0.4, na: 250), const [Serving('½ $_cup (120 g)', 120)]),
  SaStaple('Mango atchar', ['atchar', 'achar', 'mango pickle'],
      _n(200, 1, 8, 18, fib: 2, sug: 4, sat: 2, na: 1500), const [Serving('1 tbsp (20 g)', 20)]),
  SaStaple('Beetroot salad', ['beetroot salad', 'beet salad'],
      _n(70, 1.2, 15, 0.2, fib: 2, sug: 12, na: 120), const [Serving('½ $_cup (100 g)', 100)]),
  SaStaple('Pumpkin fritters (pampoenkoekies)', ['pampoenkoekies', 'pumpkin fritters'],
      _n(230, 4, 30, 10, fib: 1.5, sug: 12, sat: 2, na: 200, chol: 30), const [Serving('2 fritters (100 g)', 100)]),
  SaStaple('Slap chips', ['slap chips', 'chips', 'fries', 'slaptjips'],
      _n(230, 3, 30, 11, fib: 2.5, sug: 0.3, sat: 1.5, na: 300), const [Serving('small (150 g)', 150), Serving('large (300 g)', 300)]),
  SaStaple('Samoosa (beef)', ['samoosa', 'samosa'],
      _n(290, 9, 25, 17, fib: 1.8, sug: 1.5, sat: 4, na: 400, chol: 20), const [Serving('1 samoosa (45 g)', 45)]),
  SaStaple('Braaibroodjie', ['braaibroodjie', 'braai broodjie', 'toasted sandwich braai'],
      _n(260, 10, 30, 11, fib: 1.8, sug: 4, sat: 5.5, na: 520, chol: 25), const [Serving('1 broodjie (150 g)', 150)]),

  // ---- Sweet things
  SaStaple('Koeksister (plaited)', ['koeksister', 'koeksisters'],
      _n(395, 3.5, 60, 16, fib: 1, sug: 35, sat: 3.5, na: 150), const [Serving('1 koeksister (60 g)', 60)]),
  SaStaple('Koesister (Cape Malay)', ['koesister', 'koe sister', 'cape malay koesister'],
      _n(380, 5, 50, 18, fib: 2, sug: 22, sat: 8, na: 180), const [Serving('1 koesister (70 g)', 70)]),
  SaStaple('Melktert (milk tart)', ['melktert', 'milk tart'],
      _n(230, 5.5, 30, 10, fib: 0.5, sug: 17, sat: 5.5, na: 160, chol: 60), const [Serving('1 slice (100 g)', 100)]),
  SaStaple('Malva pudding', ['malva', 'malva pudding'],
      _n(330, 4, 48, 14, fib: 0.6, sug: 32, sat: 8, na: 280, chol: 50), const [Serving('1 portion (120 g)', 120)]),
  SaStaple('Peppermint crisp tart', ['peppermint crisp tart', 'peppermint tart'],
      _n(330, 4, 34, 20, fib: 0.5, sug: 26, sat: 12, na: 180, chol: 40), const [Serving('1 slice (120 g)', 120)]),

  // ---- Drinks & dairy
  SaStaple('Mageu (amahewu)', ['mageu', 'mahewu', 'amahewu', 'magou'],
      _n(60, 0.8, 13, 0.3, fib: 0.3, sug: 6, na: 20), const [Serving('1 glass (250 ml)', 250), Serving('1 litre', 1000)]),
  SaStaple('Amasi (maas)', ['amasi', 'maas', 'sour milk', 'inkomazi'],
      _n(70, 3.3, 4.5, 3.7, sug: 4.5, sat: 2.4, na: 45, chol: 12), const [Serving('1 $_cup (250 ml)', 250)]),
  SaStaple('Rooibos tea (no milk or sugar)', ['rooibos', 'red bush tea', 'rooibos tea'],
      _n(1, 0, 0.2, 0), const [Serving('1 mug (250 ml)', 250)]),
];

/// Matches when every query word starts a word in the name or an alias.
List<Food> searchSaStaples(String query, {int limit = 8}) {
  final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return const [];
  final scored = <(int, SaStaple)>[];
  for (final s in saStaples) {
    var best = -1;
    for (final hay in [s.name.toLowerCase(), ...s.aliases]) {
      final tokens = hay.split(RegExp(r'[^a-zëê]+'));
      if (!words.every((w) => tokens.any((t) => t.startsWith(w)))) continue;
      // Rank: exact phrase start > all-words match.
      final score = hay.startsWith(query.toLowerCase()) ? 2 : 1;
      if (score > best) best = score;
    }
    if (best > 0) scored.add((best, s));
  }
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  return scored.take(limit).map((e) => e.$2.toFood()).toList();
}
