import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  /// Presets for different deployment/development environments:
  /// - USB Connected Android Phone (with adb reverse) / Windows / Web: http://127.0.0.1:8000/api
  /// - Wi-Fi Physical Phone: http://192.168.100.98:8000/api (Your PC's Wi-Fi IP)
  /// - Android Emulator: http://10.0.2.2:8000/api
  static const String usbUrl = "http://127.0.0.1:8000/api";
  static const String wifiUrl = "http://192.168.100.98:8000/api";
  static const String emulatorUrl = "http://10.0.2.2:8000/api";
  static const String cloudUrl = "https://palengke-plus-api.onrender.com/api";

  static String activeBaseUrl = cloudUrl;
  static const String _baseUrlKey = 'api_base_url';
  static const String _cacheVersion = 'v4'; // bust Sept cache, 30s cold-start
  static const String _migratedKey = 'v4_migrated_cloud';

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_migratedKey) != true) {
      final old = preferences.getString(_baseUrlKey);
      if (old == null || old.contains('192.168.') || old.contains('127.0.0.1') || old.contains('10.0.2.2') || old.isEmpty) {
        await preferences.setString(_baseUrlKey, cloudUrl);
      }
      // drop old Sept caches
      for (final k in ['v2_commodities_cache','v2_analytics_cache','v3_commodities_cache','v3_analytics_cache']) {
        await preferences.remove(k); await preferences.remove('${k}_saved_at');
      }
      await preferences.setBool(_migratedKey, true);
    }
    final saved = preferences.getString(_baseUrlKey);
    // force cloud if stale local IP survived
    if (saved == null || saved.contains('192.168.') || saved.contains('127.0.0.1') || saved.contains('10.0.2.2')) {
      activeBaseUrl = cloudUrl;
      await preferences.setString(_baseUrlKey, cloudUrl);
    } else {
      activeBaseUrl = saved;
    }
  }

  static Future<void> setActiveBaseUrl(String url) async {
    final normalized = url.trim().replaceFirst(RegExp(r'/$'), '');
    if (normalized.isEmpty) {
      throw ArgumentError('API URL cannot be empty');
    }
    activeBaseUrl = normalized;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_baseUrlKey, normalized);
  }

  String get baseUrl => activeBaseUrl;

  Future<T> _withCache<T>({
    required String key,
    required Future<T> Function() request,
  }) async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      final value = await request();
      await preferences.setString(key, json.encode(value));
      await preferences.setString(
        '${key}_saved_at',
        DateTime.now().toIso8601String(),
      );
      return value;
    } catch (error) {
      // A full native rebuild is required after adding this plugin. Until then,
      // keep the online API usable instead of surfacing MissingPluginException.
      if (preferences == null) return request();
      final cached = preferences.getString(key);
      if (cached == null) rethrow;
      return json.decode(cached) as T;
    }
  }

  Future<DateTime?> cachedAt(String key) async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString('${key}_saved_at');
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<List<dynamic>> fetchCommodities() async {
    return _withCache(
      key: '${_cacheVersion}_commodities_cache',
      request: () async {
        final response = await http
            .get(Uri.parse('$baseUrl/commodities'))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw Exception(
            'Failed to load commodities (status: ${response.statusCode})',
          );
        }
        final data = json.decode(response.body);
        return data['commodities'] as List<dynamic>;
      },
    );
  }

  Future<Map<String, dynamic>> fetchAnalytics() async {
    return _withCache(
      key: '${_cacheVersion}_analytics_cache',
      request: () async {
        final response = await http
            .get(Uri.parse('$baseUrl/analytics'))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) {
          throw Exception(
            'Failed to load market analytics (status: ${response.statusCode})',
          );
        }
        return json.decode(response.body) as Map<String, dynamic>;
      },
    );
  }

  Future<List<dynamic>> fetchHistory(String commodity, {int days = 30}) async {
    final encoded = Uri.encodeComponent(commodity);
    final uri = Uri.parse('$baseUrl/prices/$encoded?days=$days');
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['history'] as List<dynamic>;
    } else {
      throw Exception(
        'Failed to load price history for $commodity (status: ${response.statusCode})',
      );
    }
  }

  Future<Map<String, dynamic>> fetchForecast(
    String commodity, {
    int horizon = 7,
  }) async {
    final encoded = Uri.encodeComponent(commodity);
    return _withCache(
      key:
          '${_cacheVersion}_forecast_${commodity.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_$horizon',
      request: () async {
        final response = await http
            .get(Uri.parse('$baseUrl/forecast/$encoded?horizon=$horizon'))
            .timeout(const Duration(seconds: 90));
        if (response.statusCode != 200) {
          throw Exception(
            'Failed to load forecast for $commodity (status: ${response.statusCode})',
          );
        }
        return json.decode(response.body) as Map<String, dynamic>;
      },
    );
  }
}
