import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/leaf_mark.dart';
import '../services/api_service.dart';
import 'forecast_screen.dart';

class HomeTab extends StatefulWidget {
  final ApiService api;
  final VoidCallback onSettings;
  const HomeTab({super.key, required this.api, required this.onSettings});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late Future<List<dynamic>> future;
  String query = '';
  String category = 'All';
  bool forecastMode = false;

  @override
  void initState() {
    super.initState();
    future = widget.api.fetchCommodities();
  }

  // fix: pull-to-refresh must bust stale cache, not re-serve it
  String? staleWarning;
  void reload() async {
    final stop = DateTime.now().subtract(const Duration(hours: 36));
    List<dynamic> items;
    try {
      items = await widget.api.fetchCommodities();
    } catch (e) {
      if (!mounted) return;
      setState(() => future = Future.error(e));
      return;
    }
    if (!mounted) return;
    String? latest;
    for (final it in items) {
      final d = (it is Map ? it['last_updated']?.toString() : null);
      if (d != null && (latest == null || d.compareTo(latest) > 0)) latest = d;
    }
    final stale = latest != null && (DateTime.tryParse(latest)?.isBefore(stop) ?? false);
    setState(() {
      staleWarning = stale ? 'Prices as of $latest \u2014 latest DA report not yet synced. Pull again shortly.' : null;
      future = Future.value(items);
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        if (staleWarning != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF3CD),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(staleWarning!, style: const TextStyle(fontSize: 12, color: Color(0xFF664D03))),
          ),
        _hero(),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return errorState(snapshot.error.toString(), reload);
              }
              final items = snapshot.data ?? [];
              return RefreshIndicator(
                onRefresh: () async => reload(),
                child: _homeContent(items),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _hero() => Container(
    color: navy,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DA-4A CALABARZON',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'PALENGKE+',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onSettings,
              icon: const Icon(Icons.tune, color: Colors.white),
              tooltip: 'Server settings',
            ),
            const SizedBox(width: 2),
            LeafMark(
              size: 30,
              color: Colors.white.withValues(alpha: 0.16),
              rotation: 0.45,
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) => setState(() => query = value.toLowerCase()),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search vegetables, meat, fish...',
            hintStyle: const TextStyle(color: Colors.white60),
            prefixIcon: const Icon(Icons.search, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withValues(alpha: .12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? navyDark
                  : Colors.white12,
            ),
            foregroundColor: const WidgetStatePropertyAll(Colors.white),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Colors.white24),
            ),
          ),
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('⚡ Real-time', maxLines: 1, softWrap: false),
            ),
            ButtonSegment(
              value: true,
              label: Text('📈 7-Day Forecast', maxLines: 1, softWrap: false),
            ),
          ],
          selected: {forecastMode},
          onSelectionChanged: (value) =>
              setState(() => forecastMode = value.first),
        ),
      ],
    ),
  );

  Widget _homeContent(List<dynamic> allItems) {
    final categories = [
      'All',
      'Vegetables',
      'Meat',
      'Poultry',
      'Fish',
      'Grains',
      'Spices',
    ];
    final items = allItems.where((item) {
      final name = item['name'].toString().toLowerCase();
      return name.contains(query) &&
          (category == 'All' || item['category'] == category);
    }).toList();
    final movers = [...allItems]
      ..sort(
        (a, b) =>
            parseNumber(b['delta_percent']).compareTo(parseNumber(a['delta_percent'])),
      );
    final latestDate = allItems
        .map((item) => item['last_updated']?.toString())
        .whereType<String>()
        .where((date) => date.isNotEmpty)
        .fold<String?>(null, (latest, date) {
          if (latest == null || date.compareTo(latest) > 0) return date;
          return latest;
        });
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _alertBanner(movers.isEmpty ? null : movers.first),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              '🔥 Top Price Movers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            const Icon(Icons.schedule, size: 15, color: Colors.blueGrey),
            const SizedBox(width: 4),
            Text(
              latestDate == null
                  ? 'Publication date unavailable'
                  : 'As of ${displayDate(latestDate)}',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: movers.take(4).length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _moverCard(movers[i]),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text(
              'All Commodities',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              '${items.length} items',
              style: const TextStyle(color: Colors.blueGrey),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(categories[i]),
              selected: category == categories[i],
              onSelected: (_) => setState(() => category = categories[i]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('No matching commodities.')),
          ),
        ...items.map((item) => _commodityCard(item, forecastMode)),
      ],
    );
  }

  Widget _alertBanner(dynamic item) {
    final delta = parseNumber(item?['delta_percent']);
    final isRising = delta >= 0;
    final bannerColor = isRising ? green : red;
    final containerColor = isRising
        ? const Color(0xFFE8F8F1)
        : const Color(0xFFFFF1F0);
    final borderColor = isRising
        ? const Color(0xFFBEE6D1)
        : const Color(0xFFF4D2CF);
    final directionText = isRising ? 'rose' : 'fell';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: containerColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 19)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${titleCase(item?['name'] ?? 'Market')} $directionText ${delta.abs().toStringAsFixed(1)}% today. Watch for supply changes.',
              style: TextStyle(color: bannerColor, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            item?['last_updated'] == null
                ? 'Latest'
                : displayDate(item['last_updated'].toString()),
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _moverCard(dynamic item) {
    final delta = parseNumber(item['delta_percent']);
    final rising = delta >= 0;
    return InkWell(
      onTap: () => _openForecast(item['name'].toString()),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (rising ? green : red).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                commodityEmoji(item['name']),
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    titleCase(item['name']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₱${formatPrice(item['latest_price'])} ${item['unit']}',
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _deltaChip(delta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commodityCard(dynamic item, bool forecast) {
    final delta = parseNumber(item['delta_percent']);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openForecast(item['name'].toString()),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1E7),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  commodityEmoji(item['name']),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      titleCase(item['name']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item['category']} · ${item['data_points']} days',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₱${formatPrice(item['latest_price'])} / kg',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if(item['per_piece_estimate']!=null) FittedBox(fit: BoxFit.scaleDown, child: Text(perPieceLabel(item['name'].toString(), item['latest_price']), style: const TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 3),
                    _deltaChip(delta),
                    if (forecast)
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Forecast ›',
                          style: TextStyle(color: navy, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deltaChip(double delta) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: (delta >= 0 ? green : red).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
      style: TextStyle(
        color: delta >= 0 ? green : red,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
  void _openForecast(String commodity) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ForecastScreen(commodity: commodity, api: widget.api),
    ),
  );
}

