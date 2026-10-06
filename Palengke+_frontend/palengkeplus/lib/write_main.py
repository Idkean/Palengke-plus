from pathlib import Path

content = '''import 'package:flutter/material.dart';

void main() {
  runApp(const PalengkePlusApp());
}

class PalengkePlusApp extends StatelessWidget {
  const PalengkePlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Palengke+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: const Color(0xFFF5F8F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const HomePage(),
    const MarketsPage(),
    const TrendsPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.green.shade700,
        unselectedItemColor: Colors.black54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Markets'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Trends'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeHeader(),
          const SizedBox(height: 20),
          const SearchBar(),
          const SizedBox(height: 20),
          const MarketSummaryCards(),
          const SizedBox(height: 20),
          const Expanded(child: HomeTrendsSection()),
        ],
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Palengke+', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Live commodity prices and market forecasts', style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(10),
          child: const Icon(Icons.notifications_none, color: Colors.green),
        ),
      ],
    );
  }
}

class SearchBar extends StatelessWidget {
  const SearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Colors.green),
          hintText: 'Search commodity or market',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

class MarketSummaryCards extends StatelessWidget {
  const MarketSummaryCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: SummaryCard(title: 'Today', value: '₱58.40', subtitle: 'Average price', color: Colors.green.shade600, icon: Icons.calendar_today)),
        const SizedBox(width: 12),
        Expanded(child: SummaryCard(title: 'Trend', value: '+4.2%', subtitle: 'Weekly change', color: Colors.orange.shade700, icon: Icons.trending_up)),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;

  const SummaryCard({super.key, required this.title, required this.value, required this.subtitle, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: 18),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 26, color: color.shade900)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}

class HomeTrendsSection extends StatelessWidget {
  const HomeTrendsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Commodity prices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            children: const [
              CommodityPriceCard(name: 'Rice', unit: 'kg', price: '₱65.50', delta: '+1.8%', color: Colors.green, icon: Icons.grass),
              CommodityPriceCard(name: 'Vegetables', unit: 'kg', price: '₱48.20', delta: '-0.9%', color: Colors.teal, icon: Icons.local_florist),
              CommodityPriceCard(name: 'Fish', unit: 'kg', price: '₱120.00', delta: '+2.1%', color: Colors.blue, icon: Icons.set_meal),
              SizedBox(height: 16),
              ForecastCard(),
            ],
          ),
        ),
      ],
    );
  }
}

class CommodityPriceCard extends StatelessWidget {
  final String name;
  final String unit;
  final String price;
  final String delta;
  final Color color;
  final IconData icon;

  const CommodityPriceCard({super.key, required this.name, required this.unit, required this.price, required this.delta, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(unit, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(delta, style: TextStyle(color: delta.startsWith('-') ? Colors.red : Colors.green, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class ForecastCard extends StatelessWidget {
  const ForecastCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly market outlook', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Forecast the next 7 days for major commodities', style: TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 18),
          const MarketTrendChart(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('View details', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
              Row(
                children: const [
                  Icon(Icons.circle, size: 10, color: Colors.green),
                  SizedBox(width: 6),
                  Text('Price reach estimate', style: TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }
}

class MarketTrendChart extends StatelessWidget {
  const MarketTrendChart({super.key});

  @override
  Widget build(BuildContext context) {
    final bars = [0.4, 0.6, 0.3, 0.7, 0.55, 0.8, 0.65];
    return SizedBox(
      height: 110,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: bars.map((value) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 90 * value,
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MarketsPage extends StatelessWidget {
  const MarketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Market prices', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Browse commodity price listings by category.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: const [
                CommodityPriceCard(name: 'Corn', unit: 'kg', price: '₱70.00', delta: '+0.5%', color: Colors.deepOrange, icon: Icons.grain),
                CommodityPriceCard(name: 'Pork', unit: 'kg', price: '₱320.50', delta: '+3.0%', color: Colors.red, icon: Icons.restaurant),
                CommodityPriceCard(name: 'Chicken', unit: 'kg', price: '₱190.00', delta: '+1.2%', color: Colors.amber, icon: Icons.set_meal),
                CommodityPriceCard(name: 'Tomato', unit: 'kg', price: '₱34.20', delta: '-2.6%', color: Colors.green, icon: Icons.emoji_food_beverage),
                CommodityPriceCard(name: 'Onion', unit: 'kg', price: '₱85.40', delta: '+0.9%', color: Colors.brown, icon: Icons.circle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Forecast trends', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Track price direction for the next week.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 18),
          const TrendSummaryCard(),
          const SizedBox(height: 16),
          const Expanded(child: TrendDetailPanel()),
        ],
      ),
    );
  }
}

class TrendSummaryCard extends StatelessWidget {
  const TrendSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Forecast overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          const Text('Prices are expected to remain stable with slight growth in local vegetable supply.', style: TextStyle(color: Colors.black54, height: 1.4)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              TrendStat(label: 'Up', value: '28%'),
              TrendStat(label: 'Stable', value: '52%'),
              TrendStat(label: 'Down', value: '20%'),
            ],
          ),
        ],
      ),
    );
  }
}

class TrendStat extends StatelessWidget {
  final String label;
  final String value;

  const TrendStat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 13)),
      ],
    );
  }
}

class TrendDetailPanel extends StatelessWidget {
  const TrendDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top trends', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              TrendChip(label: 'Grains'),
              TrendChip(label: 'Vegetables'),
              TrendChip(label: 'Livestock'),
              TrendChip(label: 'Seafood'),
              TrendChip(label: 'Rice'),
            ],
          ),
          const SizedBox(height: 18),
          const Expanded(child: TrendGraphPlaceholder()),
          const SizedBox(height: 14),
          const Text('Legend', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const LegendItem(color: Colors.green, label: 'Projected rise'),
          const LegendItem(color: Colors.blue, label: 'Stable period'),
          const LegendItem(color: Colors.orange, label: 'Mild fluctuation'),
        ],
      ),
    );
  }
}

class TrendChip extends StatelessWidget {
  final String label;

  const TrendChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class TrendGraphPlaceholder extends StatelessWidget {
  const TrendGraphPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.show_chart, size: 42, color: Colors.green),
          SizedBox(height: 12),
          Text('Trend graph preview', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Detailed charts and forecast lines will appear here when data is available.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const LegendItem({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('User profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Manage your app settings and account details.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.person, size: 34, color: Colors.green),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Market Vendor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 6),
                      Text('palengke@localmarket.com', style: TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.edit, color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const ProfileMenuItem(icon: Icons.notifications, title: 'Notifications', subtitle: 'Manage alerts and updates'),
          const ProfileMenuItem(icon: Icons.settings, title: 'App settings', subtitle: 'Theme, currency, and language'),
          const ProfileMenuItem(icon: Icons.help_outline, title: 'Support', subtitle: 'Get help and feedback'),
        ],
      ),
    );
  }
}

class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const ProfileMenuItem({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black26),
        ],
      ),
    );
  }
}
'''
Path('main.dart').write_text(content, encoding='utf-8')

print('written')
