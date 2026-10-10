import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/leaf_mark.dart';
import '../services/api_service.dart';

class BudgetCommodityPicker extends StatelessWidget {
  final List<dynamic> available;
  final ValueChanged<String> onSelected;

  const BudgetCommodityPicker({
    super.key,
    required this.available,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey(available.map((item) => item['name'].toString()).join('|')),
    initialValue: null,
    decoration: const InputDecoration(
      labelText: 'Add an item',
      prefixIcon: Icon(Icons.add_shopping_cart),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(),
    ),
    items: available
        .map(
          (item) => DropdownMenuItem<String>(
            value: item['name'].toString(),
            child: Text(titleCase(item['name'])),
          ),
        )
        .toList(),
    onChanged: available.isEmpty
        ? null
        : (name) {
            if (name != null) onSelected(name);
          },
  );
}

class BudgetTab extends StatefulWidget {
  final ApiService api;

  const BudgetTab({super.key, required this.api});

  @override
  State<BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<BudgetTab> {
  static const _budgetKey = 'consumer_budget_limit';
  static const _basketKey = 'consumer_budget_basket';

  late Future<List<dynamic>> commoditiesFuture;
  final budgetController = TextEditingController();
  final quantities = <String, double>{};
  bool restoring = true;

  @override
  void initState() {
    super.initState();
    commoditiesFuture = widget.api.fetchCommodities();
    _restoreBudget();
  }

  @override
  void dispose() {
    budgetController.dispose();
    super.dispose();
  }

  Future<void> _restoreBudget() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      budgetController.text = preferences.getString(_budgetKey) ?? '';
      final savedBasket = preferences.getString(_basketKey);
      if (savedBasket != null) {
        final decoded = jsonDecode(savedBasket);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final quantity = double.tryParse(entry.value.toString());
            if (quantity != null && quantity > 0) {
              quantities[entry.key.toString()] = quantity;
            }
          }
        }
      }
    } catch (_) {
      // The planner remains usable when local preferences are unavailable.
    } finally {
      if (mounted) setState(() => restoring = false);
    }
  }

  Future<void> _saveBudget() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_budgetKey, budgetController.text);
      await preferences.setString(_basketKey, jsonEncode(quantities));
    } catch (_) {
      // Keep editing usable if local persistence is unavailable.
    }
  }

  void _reloadPrices() {
    setState(() => commoditiesFuture = widget.api.fetchCommodities());
  }

  double _stepFor(Map item) =>
      item['unit']?.toString().toLowerCase().contains('piece') == true
      ? 1
      : 0.5;

  void _changeQuantity(String name, double amount) {
    setState(() {
      final next = (quantities[name] ?? 0) + amount;
      if (next <= 0) {
        quantities.remove(name);
      } else {
        quantities[name] = double.parse(next.toStringAsFixed(2));
      }
    });
    _saveBudget();
  }

  void _addCommodity(String name) {
    setState(() => quantities[name] = 1);
    _saveBudget();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<List<dynamic>>(
      future: commoditiesFuture,
      builder: (context, snapshot) {
        if (restoring || snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return errorState(snapshot.error.toString(), _reloadPrices);
        }
        final commodities = snapshot.data ?? [];
        if (commodities.isEmpty) {
          return const Center(child: Text('No market prices available.'));
        }
        return _budgetContent(commodities);
      },
    ),
  );

  Widget _budgetContent(List<dynamic> commodities) {
    final total = estimateBasketTotal(quantities, commodities);
    final budgetText = budgetController.text.trim();
    final budget = double.tryParse(budgetText);
    final hasBudget = budget != null && budget.isFinite && budget > 0;
    final remaining = (budget ?? 0) - total;
    final selected = commodities
        .where(
          (item) =>
              item is Map && (quantities[item['name']?.toString()] ?? 0) > 0,
        )
        .toList();
    final available = commodities
        .where(
          (item) =>
              item is Map && !quantities.containsKey(item['name']?.toString()),
        )
        .toList();
    final selectedByCategory = <String, List<dynamic>>{};
    for (final item in selected) {
      selectedByCategory
          .putIfAbsent(item['category']?.toString() ?? 'Other', () => [])
          .add(item);
    }
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PROCUREMENT TRACKER',
                    style: TextStyle(
                      color: green,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '💰 Budget',
                    style: TextStyle(
                      color: navy,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '${months[DateTime.now().month - 1]} ${DateTime.now().year} · Shopping plan',
                    style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _reloadPrices,
              tooltip: 'Refresh official prices',
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              onPressed: quantities.isEmpty
                  ? null
                  : () {
                      setState(quantities.clear);
                      _saveBudget();
                    },
              tooltip: 'Clear shopping list',
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: budgetController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              return RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text)
                  ? newValue
                  : oldValue;
            }),
          ],
          onChanged: (_) {
            setState(() {});
            _saveBudget();
          },
          decoration: InputDecoration(
            labelText: 'Spending limit',
            prefixText: '₱ ',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
            errorText: budgetText.isEmpty || isValidBudgetLimit(budgetText)
                ? null
                : 'Enter an amount greater than zero.',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PLANNED TOTAL',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  LeafMark(
                    size: 25,
                    color: Colors.white.withValues(alpha: 0.18),
                    rotation: -0.35,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '₱${formatPrice(total)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hasBudget) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (total / budget).clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    color: remaining >= 0 ? const Color(0xFF7BE0A8) : red,
                    backgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  remaining >= 0
                      ? '₱${formatPrice(remaining)} remaining'
                      : '₱${formatPrice(-remaining)} over budget',
                  style: TextStyle(
                    color: remaining >= 0
                        ? const Color(0xFFB8F2D0)
                        : const Color(0xFFFFB9BD),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Set a spending limit to track what remains.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Estimated from the latest official DA reference prices. Actual market prices may differ.',
          style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 18),
        BudgetCommodityPicker(available: available, onSelected: _addCommodity),
        const SizedBox(height: 12),
        if (selected.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Your shopping list is empty.',
                style: TextStyle(color: Colors.blueGrey),
              ),
            ),
          )
        else ...[
          const Padding(
            padding: EdgeInsets.only(top: 2, bottom: 8),
            child: Text(
              'BY CATEGORY · PLANNED BASKET',
              style: TextStyle(
                color: navy,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...selectedByCategory.entries.map((entry) {
            final categoryQuantities = {
              for (final item in entry.value)
                item['name'].toString():
                    quantities[item['name'].toString()] ?? 0,
            };
            final subtotal = estimateBasketTotal(
              categoryQuantities,
              entry.value,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 10, 2, 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${categoryEmoji(entry.key)} ${entry.key}',
                          style: const TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '₱${formatPrice(subtotal)}',
                        style: const TextStyle(
                          color: navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                ...entry.value.map((item) => _basketItem(item as Map)),
              ],
            );
          }),
        ],
      ],
    );
  }

  Widget _basketItem(Map item) {
    final name = item['name'].toString();
    final quantity = quantities[name] ?? 0;
    final step = _stepFor(item);
    final rawUnit = item['unit']?.toString() ?? 'per kg';
    final price = double.tryParse(item['latest_price'].toString()) ?? 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${commodityEmoji(name)} ${titleCase(name)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${priceWithUnit(price, rawUnit)} · ₱${formatPrice(price * quantity)}${isPieceUnit(rawUnit) ? ' (per piece = 1 pc)' : ''}',
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _changeQuantity(name, -step),
              visualDensity: VisualDensity.compact,
              tooltip: 'Reduce quantity',
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '${quantity == quantity.roundToDouble() ? quantity.toInt() : quantity} ${unitLabel(rawUnit, short: true)}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            IconButton(
              onPressed: () => _changeQuantity(name, step),
              visualDensity: VisualDensity.compact,
              tooltip: 'Increase quantity',
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

