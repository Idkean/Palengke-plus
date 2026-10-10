import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/api_service.dart';

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
          return errorState(snapshot.error.toString(), _refresh);
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
            .map((item) => parseNumber(item['price']))
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
        final currentPrice = parseNumber(selected['latest_price']);
        final outlookPrice = forecasts.isEmpty
            ? currentPrice
            : parseNumber(forecasts.last['predicted_price']);
        final outlookChange = currentPrice == 0
            ? 0.0
            : (outlookPrice - currentPrice) / currentPrice * 100;
        final chartSpots = showForecast
            ? <FlSpot>[
                FlSpot(0, currentPrice),
                ...forecasts.asMap().entries.map(
                  (entry) => FlSpot(
                    (entry.key + 1).toDouble(),
                    parseNumber(entry.value['predicted_price']),
                  ),
                ),
              ]
            : history.asMap().entries.map((entry) {
                return FlSpot(
                  entry.key.toDouble(),
                  parseNumber(entry.value['price']),
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
                    label: Text('${commodityEmoji(name)} ${titleCase(name)}'),
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
                          '${commodityEmoji(selected['name'])} ${titleCase(selected['name'])}',
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
                        '₱${formatPrice(currentPrice)}',
                        style: const TextStyle(
                          color: navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${parseNumber(selected['delta_percent']) >= 0 ? '+' : ''}${parseNumber(selected['delta_percent']).toStringAsFixed(1)}% today',
                        style: TextStyle(
                          color: parseNumber(selected['delta_percent']) >= 0
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
                    '₱${formatPrice(outlookPrice)}',
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
                _statCard('30D AVERAGE', '₱${formatPrice(average)}', navy),
                const SizedBox(width: 8),
                _statCard('30D LOW', '₱${formatPrice(low)}', green),
                const SizedBox(width: 8),
                _statCard('30D HIGH', '₱${formatPrice(high)}', red),
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
    final delta = parseNumber(item['delta_percent']);
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
              titleCase(item['name']),
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

