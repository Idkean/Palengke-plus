import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/api_service.dart';

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
        .map((model) => parseNumber(model['rmse']))
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
              final rmse = parseNumber(model['rmse']);
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
        '${titleCase(widget.commodity)} · 7-DAY FORECAST',
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
          return errorState(
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
                parseNumber(entry.value['predicted_price']),
              ),
            )
            .toList();
        final firstForecast = forecasts.isEmpty ? null : forecasts.first;
        final expectedPrice = firstForecast == null
            ? 'n/a'
            : '₱${formatPrice(firstForecast['predicted_price'])}';
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
                decoration: cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Forecast not ready yet - showing 30-day history', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: LineChart(
                        LineChartData(
                          lineBarsData: [LineChartBarData(spots: history.map((e) => FlSpot(history.indexOf(e).toDouble(), parseNumber(e['price']))).toList().isEmpty ? [FlSpot(0,0)] : history.map((e) => FlSpot(history.indexOf(e).toDouble(), parseNumber(e['price']))).toList(), isCurved: true, color: green, barWidth: 2.5, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: green.withValues(alpha: 0.08)))],
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
                decoration: cardDecoration(),
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
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['date'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 3), Text('History: ₱${formatPrice(item['price'])}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)) ])),
                      FittedBox(fit: BoxFit.scaleDown, child: Text('₱${formatPrice(item['price'])}', style: const TextStyle(fontWeight: FontWeight.bold, color: navy, fontSize: 16))),
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
                              'Likely range: ₱${formatPrice(item['ci_lower'])} - ₱${formatPrice(item['ci_upper'])}',
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
                          '₱${formatPrice(item['predicted_price'])}',
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
