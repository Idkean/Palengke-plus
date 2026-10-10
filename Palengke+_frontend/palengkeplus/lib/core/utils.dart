import 'package:flutter/material.dart';
import 'theme.dart';

String commodityEmoji(dynamic value) {
  final name = value?.toString().toLowerCase().trim() ?? '';
  if (name.contains('rice')) return '🍚';
  if (name.contains('corn')) return '🌽';
  if (name.contains('ampalaya')) return '🌿';
  if (name.contains('kamatis') || name.contains('tomato')) return '🍅';
  if (name.contains('talong') || name.contains('eggplant')) return '🍆';
  if (name.contains('repolyo') || name.contains('cabbage')) return '🥬';
  if (name.contains('sitaw') || name.contains('sitao')) return '🫛';
  if (name.contains('kalabasa') || name.contains('squash')) return '🎃';
  if (name.contains('carrot')) return '🥕';
  if (name.contains('onion') || name.contains('sibuyas')) return '🧅';
  if (name.contains('bawang') || name.contains('garlic')) return '🧄';
  if (name.contains('luya') || name.contains('ginger')) return '🫚';
  if (name.contains('pork') || name.contains('beef')) return '🥩';
  if (name.contains('chicken')) return '🍗';
  if (name.contains('egg')) return '🥚';
  if (name.contains('bangus')) return '🐟';
  if (name.contains('tilapia')) return '🐠';
  if (name.contains('galunggong')) return '🐡';
  return '🛒';
}

String categoryEmoji(dynamic value) => switch (value?.toString()) {
  'Vegetables' => '🥬',
  'Fish' => '🐟',
  'Meat' => '🥩',
  'Poultry' => '🍗',
  'Grains' => '🌽',
  'Spices' => '🧄',
  _ => '🛒',
};

double estimateBasketTotal(
  Map<String, double> quantities,
  List<dynamic> commodities,
) {
  return commodities.fold(0.0, (total, commodity) {
    if (commodity is! Map) return total;
    final name = commodity['name']?.toString();
    final quantity = name == null ? 0.0 : quantities[name] ?? 0.0;
    final price = double.tryParse(commodity['latest_price'].toString()) ?? 0.0;
    return total + price * quantity;
  });
}

bool isValidBudgetLimit(String value) {
  final amount = double.tryParse(value.trim());
  return amount != null && amount.isFinite && amount > 0;
}

String unitLabel(String unit, {bool short=false}) {
  final u = unit.toLowerCase().trim();
  if (u.contains('piece')) return short ? 'pc' : 'per piece';
  if (u.contains('bundle')) return short ? 'bundle' : 'per bundle';
  if (u.contains('sack')) return short ? 'sack' : 'per sack';
  if (u.contains('pack')) return short ? 'pack' : 'per pack';
  return short ? 'kg' : 'per kg';
}
bool isPieceUnit(String unit) => unit.toLowerCase().contains('piece');
String priceWithUnit(dynamic price, dynamic unit) => '₱${formatPrice(price)} / ${unitLabel(unit?.toString() ?? 'per kg', short: true)}';



String titleCase(dynamic value) => value
    .toString()
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
double parseNumber(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String formatPrice(dynamic value) => parseNumber(value).toStringAsFixed(2);
String displayDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

BoxDecoration cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: line),
);
Widget errorState(String message, VoidCallback retry) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cloud_off, size: 48, color: red),
        const SizedBox(height: 12),
        const Text(
          'Connection error',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.blueGrey),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: retry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try again'),
        ),
      ],
    ),
  ),
);
