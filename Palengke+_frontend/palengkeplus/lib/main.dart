import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';

const navy = Color(0xFF1A2E20);
const navyDark = Color(0xFF13271B);
const canvas = Color(0xFFF4F8F2);
const green = Color(0xFF2F7A4E);
const red = Color(0xFFD15142);
const accent = Color(0xFFE9A53A);
const line = Color(0xFFDDEADF);

class LeafMark extends StatelessWidget {
  final double size;
  final Color color;
  final double rotation;

  const LeafMark({
    super.key,
    required this.size,
    required this.color,
    this.rotation = 0,
  });

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Transform.rotate(
        angle: rotation,
        child: Icon(Icons.eco_outlined, size: size, color: color),
      ),
    ),
  );
}

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initialize();
  runApp(const PalengkePlusApp());
}

class PalengkePlusApp extends StatelessWidget {
  const PalengkePlusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Palengke+ DA Reference',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: navy,
        secondary: accent,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(),
      dividerColor: line,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F1E7),
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? navy
                : Colors.black54,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
      ),
    ),
    builder: (context, child) => ColoredBox(
      color: canvas,
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamilyFallback: [
            'Noto Color Emoji',
            'Segoe UI Emoji',
            'Apple Color Emoji',
          ],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Stack(
              children: [
                Positioned(
                  left: -24,
                  top: 180,
                  child: LeafMark(
                    size: 76,
                    color: green.withValues(alpha: 0.035),
                    rotation: -0.55,
                  ),
                ),
                Positioned(
                  right: -24,
                  bottom: 125,
                  child: LeafMark(
                    size: 82,
                    color: green.withValues(alpha: 0.03),
                    rotation: 0.6,
                  ),
                ),
                ?child,
              ],
            ),
          ),
        ),
      ),
    ),
    home: const Shell(),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int selectedTab = 0;
  final api = ApiService();

  void openServerSettings() {
    final controller = TextEditingController(text: ApiService.activeBaseUrl);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Server connection'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _serverOption(dialogContext, '☁️ Cloud (Render)', ApiService.cloudUrl, isCloud: true),
              const Divider(),
              _serverOption(dialogContext, 'USB / desktop', ApiService.usbUrl),
              _serverOption(dialogContext, 'Wi-Fi phone', ApiService.wifiUrl),
              _serverOption(dialogContext, 'Android emulator', ApiService.emulatorUrl),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(labelText: 'Custom API URL', hintText: 'https://.../api'),
              ),
              const SizedBox(height: 8),
              Text('Active: ${ApiService.activeBaseUrl}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await ApiService.setActiveBaseUrl(controller.text);
              }
              if (!dialogContext.mounted || !mounted) return;
              Navigator.pop(dialogContext);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _serverOption(BuildContext context, String label, String url, {bool isCloud = false}) =>
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(isCloud ? Icons.cloud_done_outlined : Icons.dns_outlined, color: isCloud ? green : navy),
        title: Text(label, style: TextStyle(fontWeight: isCloud ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text(url, style: const TextStyle(fontSize: 11)),
        onTap: () async {
          await ApiService.setActiveBaseUrl(url);
          if (!context.mounted || !mounted) return;
          Navigator.pop(context);
          setState(() {});
        },
      );

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(api: api, onSettings: openServerSettings),
      AnalyticsTab(api: api),
      MarketsTab(api: api),
      BudgetTab(api: api),
      ProfileTab(onSettings: openServerSettings),
    ];
    return Scaffold(
      body: IndexedStack(index: selectedTab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE6F2F4),
        destinations: const [
          NavigationDestination(
            icon: Text('🏠', style: TextStyle(fontSize: 18)),
            selectedIcon: Text('🏠', style: TextStyle(fontSize: 18)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Text('📈', style: TextStyle(fontSize: 18)),
            selectedIcon: Text('📈', style: TextStyle(fontSize: 18)),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Text('🛒', style: TextStyle(fontSize: 18)),
            selectedIcon: Text('🛒', style: TextStyle(fontSize: 18)),
            label: 'Markets',
          ),
          NavigationDestination(
            icon: Text('💰', style: TextStyle(fontSize: 18)),
            selectedIcon: Text('💰', style: TextStyle(fontSize: 18)),
            label: 'Budget',
          ),
          NavigationDestination(
            icon: Text('👤', style: TextStyle(fontSize: 18)),
            selectedIcon: Text('👤', style: TextStyle(fontSize: 18)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

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

  void reload() {
    setState(() {
      future = widget.api.fetchCommodities();
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        _hero(),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _errorState(snapshot.error.toString(), reload);
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
            _number(b['delta_percent']).compareTo(_number(a['delta_percent'])),
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
                  : 'As of ${_displayDate(latestDate)}',
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
    final delta = _number(item?['delta_percent']);
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
              '${_title(item?['name'] ?? 'Market')} $directionText ${delta.abs().toStringAsFixed(1)}% today. Watch for supply changes.',
              style: TextStyle(color: bannerColor, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            item?['last_updated'] == null
                ? 'Latest'
                : _displayDate(item['last_updated'].toString()),
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _moverCard(dynamic item) {
    final delta = _number(item['delta_percent']);
    final rising = delta >= 0;
    return InkWell(
      onTap: () => _openForecast(item['name'].toString()),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
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
                    _title(item['name']),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₱${_price(item['latest_price'])} ${item['unit']}',
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
    final delta = _number(item['delta_percent']);
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
                      _title(item['name']),
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
                width: 78,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₱${_price(item['latest_price'])}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
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

class AnalyticsTab extends StatefulWidget {
  final ApiService api;
  const AnalyticsTab({super.key, required this.api});

  @override
  State<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  late Future<Map<String, dynamic>> dashboardFuture;
  String? selectedCommodity;
  bool showForecast = false;

  @override
  void initState() {
    super.initState();
    dashboardFuture = _loadDashboard();
  }

  // ponytail: show analytics even if forecast hangs on free tier
  Future<Map<String, dynamic>> _loadDashboard() async {
    final results = await Future.wait<dynamic>([
      widget.api.fetchCommodities().catchError((e) => throw e),
      widget.api.fetchAnalytics().catchError((e) => throw e),
    ]);
    final commodities = results[0] as List<dynamic>;
    final analytics = results[1] as Map<String, dynamic>;
    if (commodities.isEmpty) {
      return {'commodities': commodities, 'analytics': analytics, 'history': <dynamic>[], 'forecast': <String, dynamic>{}, 'forecastError': null};
    }
    final selected = commodities.firstWhere(
      (item) => item['name'].toString() == selectedCommodity,
      orElse: () => commodities.first,
    );
    selectedCommodity = selected['name'].toString();
    List<dynamic> history = [];
    Map<String, dynamic> forecast = {};
    String? forecastErr;
    try {
      history = await widget.api.fetchHistory(selectedCommodity!, days: 30).timeout(const Duration(seconds: 35));
    } catch (e) {
      history = [];
    }
    try {
      forecast = await widget.api.fetchForecast(selectedCommodity!).timeout(const Duration(seconds: 90));
    } catch (e) {
      forecastErr = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
    }
    return {'commodities': commodities, 'analytics': analytics, 'history': history, 'forecast': forecast, 'forecastError': forecastErr};
  }

  void _refresh() => setState(() => dashboardFuture = _loadDashboard());

  void _selectCommodity(String name) {
    setState(() {
      selectedCommodity = name;
      dashboardFuture = _loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<Map<String, dynamic>>(
      future: dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState(snapshot.error.toString(), _refresh);
        }
        final data = snapshot.data!;
        final commodities = data['commodities'] as List<dynamic>;
        if (commodities.isEmpty) {
          return const Center(child: Text('No price history is available.'));
        }
        final analytics = data['analytics'] as Map<String, dynamic>;
        final history = data['history'] as List<dynamic>;
        final forecastData = data['forecast'] as Map<String, dynamic>;
        final forecastErr = data['forecastError'] as String?;
        final forecasts = (forecastData['forecast'] as List<dynamic>?) ?? [];
        final quality = forecastData['quality'] as Map<dynamic, dynamic>? ?? {};
        final selected = commodities.firstWhere(
          (item) => item['name'].toString() == selectedCommodity,
          orElse: () => commodities.first,
        );
        final historyPrices = history
            .map((item) => _number(item['price']))
            .where((price) => price > 0)
            .toList();
        final average = historyPrices.isEmpty
            ? 0.0
            : historyPrices.reduce((a, b) => a + b) / historyPrices.length;
        final low = historyPrices.isEmpty
            ? 0.0
            : historyPrices.reduce((a, b) => a < b ? a : b);
        final high = historyPrices.isEmpty
            ? 0.0
            : historyPrices.reduce((a, b) => a > b ? a : b);
        final currentPrice = _number(selected['latest_price']);
        final outlookPrice = forecasts.isEmpty
            ? currentPrice
            : _number(forecasts.last['predicted_price']);
        final outlookChange = currentPrice == 0
            ? 0.0
            : (outlookPrice - currentPrice) / currentPrice * 100;
        final chartSpots = showForecast
            ? <FlSpot>[
                FlSpot(0, currentPrice),
                ...forecasts.asMap().entries.map(
                  (entry) => FlSpot(
                    (entry.key + 1).toDouble(),
                    _number(entry.value['predicted_price']),
                  ),
                ),
              ]
            : history.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  _number(entry.value['price']),
                );
              }).toList();
        final movers = [
          ...(analytics['top_gainers'] as List<dynamic>? ?? []),
          ...(analytics['top_decliners'] as List<dynamic>? ?? []),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PRICE ANALYTICS',
                        style: TextStyle(
                          color: green,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Analytics',
                        style: TextStyle(
                          color: navy,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _refresh,
                  tooltip: 'Refresh analytics',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const Text(
              'Price history and outlook · Official DA-4A data',
              style: TextStyle(color: Colors.blueGrey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: commodities.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (_, index) {
                  final item = commodities[index];
                  final name = item['name'].toString();
                  return ChoiceChip(
                    label: Text('${commodityEmoji(name)} ${_title(name)}'),
                    selected: selectedCommodity == name,
                    onSelected: (_) => _selectCommodity(name),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${commodityEmoji(selected['name'])} ${_title(selected['name'])}',
                          style: const TextStyle(
                            color: navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${selected['source'] ?? 'DA-4A'} · Published ${selected['last_updated'] ?? 'date unavailable'}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₱${_price(currentPrice)}',
                        style: const TextStyle(
                          color: navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${_number(selected['delta_percent']) >= 0 ? '+' : ''}${_number(selected['delta_percent']).toStringAsFixed(1)}% today',
                        style: TextStyle(
                          color: _number(selected['delta_percent']) >= 0
                              ? green
                              : red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '7-DAY OUTLOOK',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${outlookChange >= 0 ? '+' : ''}${outlookChange.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: outlookChange >= 0
                          ? const Color(0xFFB8F2D0)
                          : const Color(0xFFFFB9BD),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '₱${_price(outlookPrice)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                textStyle: WidgetStatePropertyAll(
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('📊 30D History', maxLines: 1, softWrap: false),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('🔮 7D Forecast', maxLines: 1, softWrap: false),
                ),
              ],
              selected: {showForecast},
              onSelectionChanged: (value) =>
                  setState(() => showForecast = value.first),
            ),
            const SizedBox(height: 10),
            if (forecastErr != null && showForecast)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFCC80))),
                child: Row(children: [const Icon(Icons.info_outline, size: 18), const SizedBox(width: 8), Expanded(child: Text('Forecast loading slow on free server (cold start). History & alerts ok. Tap refresh. $forecastErr', style: const TextStyle(fontSize: 11)))])
              ),
            if (forecastErr != null && showForecast) const SizedBox(height: 10),
            Container(
              height: 220,
              padding: const EdgeInsets.fromLTRB(10, 14, 14, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line),
              ),
              child: chartSpots.length < 2
                  ? const Center(
                      child: Text('Not enough price points to chart.'),
                    )
                  : LineChart(
                      LineChartData(
                        lineBarsData: [
                          LineChartBarData(
                            spots: chartSpots,
                            isCurved: true,
                            color: green,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: green.withValues(alpha: 0.08),
                            ),
                          ),
                        ],
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: line, strokeWidth: 0.8),
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _statCard('30D AVERAGE', '₱${_price(average)}', navy),
                const SizedBox(width: 8),
                _statCard('30D LOW', '₱${_price(low)}', green),
                const SizedBox(width: 8),
                _statCard('30D HIGH', '₱${_price(high)}', red),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'History summaries are calculated from the daily series; missing dates may be interpolated.',
                style: TextStyle(color: Colors.blueGrey, fontSize: 10),
              ),
            ),
            const SizedBox(height: 18),
            _sectionCard(
              'Market alerts',
              Column(
                children: movers.isEmpty
                    ? [const Text('No market movements are available.')]
                    : movers.take(6).map(_movementRow).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${quality['validation_points'] ?? 0} recent prices used to check this forecast · nominal 95% ranges are not coverage guarantees.',
              style: const TextStyle(
                color: Colors.blueGrey,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _movementRow(dynamic item) {
    final delta = _number(item['delta_percent']);
    final color = delta >= 0 ? green : red;
    final magnitude = (delta.abs() / 40).clamp(0.04, 1.0).toDouble();
    final alertEmoji = delta.abs() >= 5
        ? '🔴'
        : delta.abs() >= 2
        ? '🟡'
        : '🟢';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(alertEmoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              _title(item['name']),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: LinearProgressIndicator(
              value: magnitude,
              minHeight: 8,
              color: color,
              backgroundColor: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 58,
            child: Text(
              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, dynamic value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(color: Colors.blueGrey, fontSize: 9),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _sectionCard(String title, Widget child) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: line),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔔', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    ),
  );
}

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
            child: Text(_title(item['name'])),
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
          return _errorState(snapshot.error.toString(), _reloadPrices);
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
                '₱${_price(total)}',
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
                      ? '₱${_price(remaining)} remaining'
                      : '₱${_price(-remaining)} over budget',
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
                        '₱${_price(subtotal)}',
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
    final unit = item['unit']?.toString().replaceFirst('per ', '') ?? 'unit';
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
                    '${commodityEmoji(name)} ${_title(name)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '₱${_price(price)} / $unit · ₱${_price(price * quantity)}',
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
              '${quantity == quantity.roundToDouble() ? quantity.toInt() : quantity} $unit',
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

class MarketsTab extends StatefulWidget {
  final ApiService api;

  const MarketsTab({super.key, required this.api});
  @override
  State<MarketsTab> createState() => _MarketsTabState();
}

class _MarketsTabState extends State<MarketsTab> {
  late Future<List<dynamic>> commoditiesFuture;
  String query = '';
  String category = 'All';

  @override
  void initState() {
    super.initState();
    commoditiesFuture = widget.api.fetchCommodities();
  }

  void _reload() =>
      setState(() => commoditiesFuture = widget.api.fetchCommodities());

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<List<dynamic>>(
      future: commoditiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState(snapshot.error.toString(), _reload);
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(child: Text('No commodities available.'));
        }
        return _directoryContent(items);
      },
    ),
  );

  Widget _directoryContent(List<dynamic> items) {
    final categories = [
      'All',
      ...items.map((item) => item['category'].toString()).toSet(),
    ];
    final filtered = items.where((item) {
      final searchText =
          '${item['name']} ${item['category']} ${item['source']} ${item['coverage']}'
              .toLowerCase();
      return searchText.contains(query) &&
          (category == 'All' || item['category'] == category);
    }).toList();
    final grouped = <String, List<dynamic>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item['category'].toString(), () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRICE DIRECTORY',
                    style: TextStyle(
                      color: green,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '🛒 Markets',
                    style: TextStyle(
                      color: navy,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _reload,
              tooltip: 'Refresh prices',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Text(
          '${items.length} commodities tracked · Official DA-4A reference',
          style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: (value) =>
              setState(() => query = value.trim().toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Search commodities',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (_, index) => ChoiceChip(
              label: Text(categories[index]),
              selected: category == categories[index],
              onSelected: (_) => setState(() => category = categories[index]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: Text('No matching commodities.')),
          ),
        ...grouped.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 8, 2, 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            color: navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value.length} items',
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: line),
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < entry.value.length;
                        index++
                      ) ...[
                        _marketRow(entry.value[index]),
                        if (index < entry.value.length - 1)
                          const Divider(height: 1, indent: 58),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Regional DA reference prices may differ from individual market stalls.',
            style: TextStyle(color: Colors.blueGrey, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _marketRow(dynamic item) {
    final name = item['name'].toString();
    final delta = _number(item['delta_percent']);
    final changedColor = delta >= 0 ? green : red;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForecastScreen(commodity: name, api: widget.api),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1E7),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                commodityEmoji(name),
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['source'] ?? 'DA-4A'} · ${item['last_updated'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${_price(item['latest_price'])}',
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: changedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends StatefulWidget {
  final VoidCallback onSettings;
  const ProfileTab({super.key, required this.onSettings});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final settings = {
    'Price Alerts': true,
    'Weekly Report': true,
    'Budget Warning': true,
  };
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
      children: [
        const Text(
          'MY ACCOUNT',
          style: TextStyle(
            color: green,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Text(
          '👤 Profile',
          style: TextStyle(
            color: navy,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: navy,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: Color(0xFF10A39B),
                child: Text('👩‍🍳', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consumer access',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Public browsing · no account required',
                      style: TextStyle(color: Colors.white70),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Official DA-4A CALABARZON reference data',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              LeafMark(
                size: 32,
                color: Colors.white.withValues(alpha: 0.18),
                rotation: 0.35,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _settingsCard(
          'Alert Preferences',
          '🔔',
          settings.entries
              .map(
                (entry) => SwitchListTile(
                  title: Text(entry.key),
                  subtitle: Text(
                    _settingDescription(entry.key),
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
                  value: entry.value,
                  activeThumbColor: green,
                  onChanged: (value) =>
                      setState(() => settings[entry.key] = value),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        _settingsCard('Preferences', '⚙️', [
          ListTile(
            leading: const Icon(Icons.dns_outlined, color: navy),
            title: const Text('Server connection'),
            subtitle: Text(
              ApiService.activeBaseUrl,
              style: const TextStyle(fontSize: 11),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.onSettings,
          ),
          const ListTile(
            leading: Icon(Icons.language, color: navy),
            title: Text('Language'),
            trailing: Text('Filipino / English'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline, color: navy),
            title: Text('App Version'),
            trailing: Text('v1.0.0'),
          ),
        ]),
      ],
    ),
  );
  Widget _settingsCard(String title, String icon, List<Widget> children) =>
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      );
  String _settingDescription(String key) => switch (key) {
    'Price Alerts' ||
    'Price Surge Alert' ||
    'Price Drop Alert' => 'When prices move ±5%',
    'Weekly Report' || 'Weekly Summary' => 'Market summary every Sunday',
    'Budget Warning' => 'When planned spend reaches 80%',
    'Forecast Updates' => 'Daily ARIMA forecast refreshes',
    _ => 'Market updates are shown in Palengke+.',
  };
}

class ForecastScreen extends StatefulWidget {
  final String commodity;
  final ApiService api;
  const ForecastScreen({super.key, required this.commodity, required this.api});
  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  late Future<Map<String, dynamic>> future;
  List<dynamic> _history = [];
  @override
  void initState() {
    super.initState();
    future = _load();
  }
  Future<Map<String, dynamic>> _load() async {
    List<dynamic> history = [];
    Map<String, dynamic> forecast = {};
    String? forecastErr;
    try {
      history = await widget.api.fetchHistory(widget.commodity, days: 30).timeout(const Duration(seconds: 35));
      _history = history;
    } catch (_) { history = _history; }
    try {
      forecast = await widget.api.fetchForecast(widget.commodity).timeout(const Duration(seconds: 90));
    } catch (e) {
      forecastErr = e.toString().replaceAll(RegExp(r'^Exception:\s*'), '');
    }
    if (history.isEmpty && forecast.isEmpty && forecastErr != null) throw Exception(forecastErr);
    return {'history': history, 'forecast': forecast, 'forecastError': forecastErr};
  }

  Widget _modelComparisonCard(List<dynamic> models) {
    final validModels = models.whereType<Map>().toList();
    final bestRmse = validModels
        .map((model) => _number(model['rmse']))
        .where((value) => value > 0)
        .fold<double?>(
          null,
          (best, value) => best == null || value < best ? value : best,
        );
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How the forecast was checked',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lower error means the method was closer to recent known prices.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            ...validModels.map((model) {
              final rmse = _number(model['rmse']);
              final isBest = bestRmse != null && rmse == bestRmse;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        model['model']?.toString() ?? 'Unknown model',
                      ),
                    ),
                    Text(
                      'MAPE ${model['mape'] ?? 'n/a'}%  |  RMSE ${model['rmse'] == null ? 'n/a' : '₱${model['rmse']}'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isBest ? green : Colors.blueGrey,
                        fontWeight: isBest
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.check_circle, size: 15, color: green),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${_title(widget.commodity)} · 7-DAY FORECAST',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: navy,
      foregroundColor: Colors.white,
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState(
            snapshot.error.toString(),
            () => setState(() => future = _load()),
          );
        }
        final data = snapshot.data!;
        final history = (data['history'] as List<dynamic>?) ?? [];
        final forecastMap = (data['forecast'] as Map<String, dynamic>?) ?? {};
        final forecastErr = data['forecastError'] as String?;
        final forecasts = (forecastMap['forecast'] as List<dynamic>?) ?? [];
        final quality = (forecastMap['quality'] as Map<dynamic, dynamic>?) ?? {};
        final qualityStatus = quality['status']?.toString() ?? 'unknown';
        final limitedHistory = qualityStatus != 'validated';
        final observations = quality['observations']?.toString() ?? 'n/a';
        final validationPoints =
            quality['validation_points']?.toString() ?? '0';
        final modelComparison =
            (quality['model_comparison'] as List<dynamic>?) ?? [];
        final points = forecasts
            .asMap()
            .entries
            .map(
              (entry) => FlSpot(
                entry.key.toDouble(),
                _number(entry.value['predicted_price']),
              ),
            )
            .toList();
        final firstForecast = forecasts.isEmpty ? null : forecasts.first;
        final expectedPrice = firstForecast == null
            ? 'n/a'
            : '₱${_price(firstForecast['predicted_price'])}';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              color: const Color(0xFFE8F6F4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Expected price tomorrow',
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expectedPrice,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      limitedHistory
                          ? 'This is a cautious estimate based on limited recent price history.'
                          : 'This estimate was checked against recent known prices.',
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: qualityStatus == 'validated'
                  ? const Color(0xFFEAF7EE)
                  : const Color(0xFFFFF4DE),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      qualityStatus == 'validated'
                          ? Icons.verified_outlined
                          : Icons.warning_amber_outlined,
                      color: qualityStatus == 'validated'
                          ? green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        qualityStatus == 'validated'
                            ? 'Validation: $observations observations, tested on $validationPoints recent prices. The nominal 95% range is model-based, not a coverage guarantee.'
                            : 'Use this as a rough guide: only $observations observations are available, so the app uses the latest price as its safest estimate.',
                        style: const TextStyle(fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (modelComparison.isNotEmpty) ...[
              const SizedBox(height: 14),
              _modelComparisonCard(modelComparison),
            ],
            if (limitedHistory) ...[
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                color: const Color(0xFFF3F7FA),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.show_chart, color: navy),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Why is the line flat? The app does not have enough history to safely predict a rise or fall, so it keeps the expected price near the latest known price. The wider ranges below show that prices could still move.',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (!limitedHistory) ...[
                  Expanded(
                    child: _metric('Error rate', '${forecastMap['metrics']?['mape'] ?? 'n/a'}%'),
                  ),
                  Expanded(
                    child: _metric(
                      'Typical error',
                      '₱${forecastMap['metrics']?['rmse'] ?? 'n/a'}',
                    ),
                  ),
                ],
                Expanded(child: _metric('Range', 'Nominal 95%')),
              ],
            ),

            const SizedBox(height: 18),
            if (forecastErr != null && forecasts.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10), border: Border.all(color: Color(0xFFFFCC80))),
                child: Row(children: [const Icon(Icons.hourglass_top, size: 16), const SizedBox(width: 8), Expanded(child: Text('Forecast warming on free server (cold start) - 30-day history below is live. Pull to refresh. $forecastErr', style: TextStyle(fontSize: 11)))]),
              ),
            const Text(
              'Expected price over 7 days',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (forecasts.isEmpty && history.isNotEmpty)
              Container(
                height: 240,
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                decoration: _cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Forecast not ready yet - showing 30-day history', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [LineChartBarData(spots: history.map((e) => FlSpot(history.indexOf(e).toDouble(), _number(e['price']))).toList().isEmpty ? [FlSpot(0,0)] : history.map((e) => FlSpot(history.indexOf(e).toDouble(), _number(e['price']))).toList(), isCurved: true, color: green, barWidth: 2.5, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: green.withValues(alpha: 0.08)))],
                          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200)),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 240,
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                decoration: _cardDecoration(),
                child: forecasts.isEmpty
                    ? const Center(child: Text('Forecast warming - pull to refresh'))
                    : LineChart(
                        LineChartData(
                          lineBarsData: [LineChartBarData(spots: points, isCurved: true, color: green, barWidth: 3, dotData: const FlDotData(show: true))],
                          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200)),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                        ),
                      ),
              ),
            const SizedBox(height: 18),
            const Text(
              'Daily estimate and likely range',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (forecasts.isEmpty && history.isNotEmpty)
              ...history.take(7).map(
                (item) => Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['date'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 3), Text('History: ₱${_price(item['price'])}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)) ])),
                      FittedBox(fit: BoxFit.scaleDown, child: Text('₱${_price(item['price'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 16))),
                    ]),
                  ),
                ),
              )
            else
              ...forecasts.map(
              (item) => Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['date'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Likely range: ₱${_price(item['ci_lower'])} - ₱${_price(item['ci_upper'])}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '₱${_price(item['predicted_price'])}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: navy,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  Widget _metric(String label, String value) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
    ],
  );
}

String _title(dynamic value) => value
    .toString()
    .split(' ')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _price(dynamic value) => _number(value).toStringAsFixed(2);
String _displayDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

BoxDecoration _cardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: line),
);
Widget _errorState(String message, VoidCallback retry) => Center(
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
