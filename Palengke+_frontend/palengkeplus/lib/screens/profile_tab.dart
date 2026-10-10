import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../widgets/leaf_mark.dart';
import '../services/api_service.dart';

class ProfileTab extends StatefulWidget {
  final VoidCallback onSettings;
  final String role;
  final String vendorUser;
  final Future<void> Function(String role, String user) onRoleChanged;
  const ProfileTab({super.key, required this.onSettings, this.role='consumer', this.vendorUser='', required this.onRoleChanged});
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
              CircleAvatar(
                radius: 27,
                backgroundColor: const Color(0xFF10A39B),
                child: Text(widget.role=='vendor' ? '🏪' : '👩‍🍳', style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.role=='vendor' ? 'Vendor: ${widget.vendorUser}' : 'Consumer access',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.role=='vendor' ? 'You can add & manage your stall prices' : 'Public browsing · no account required',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Text('Official DA-4A CALABARZON reference data', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              LeafMark(size: 32, color: Colors.white.withValues(alpha: 0.18), rotation: 0.35),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(elevation:0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: line)), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          const Text('Account mode', style: TextStyle(fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value:'consumer', label: Text('Consumer')), ButtonSegment(value:'vendor', label: Text('Vendor'))],
            selected: {widget.role},
            onSelectionChanged: (s) async {
              final next=s.first;
              if(next=='vendor' && widget.vendorUser.isEmpty){
                await _showVendorLogin(context);
              } else {
                await widget.onRoleChanged(next, widget.vendorUser);
                if(mounted) setState((){});
              }
            },
          ),
          const SizedBox(height: 6),
          Text(widget.role=='vendor' ? 'Vendor sees Add price + delete own prices. Consumer is read-only.' : 'Consumer: view DA + vendor prices, plan budget.', style: const TextStyle(color: Colors.blueGrey, fontSize:12)),
          if(widget.role=='vendor') Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: ()=>_showVendorLogin(context), icon: const Icon(Icons.login, size:16), label: Text(widget.vendorUser.isEmpty ? 'Login / Register' : 'Switch vendor'))),
          if(widget.role=='vendor' && widget.vendorUser.isNotEmpty) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () async { await widget.onRoleChanged('consumer',''); if(mounted) setState((){}); }, icon: const Icon(Icons.logout, size:16), label: const Text('Logout vendor'))),
        ]))),
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
  Future<void> _showVendorLogin(BuildContext context) async {
    final api=ApiService();
    final uCtrl=TextEditingController(text: widget.vendorUser);
    final pCtrl=TextEditingController();
    final mCtrl=TextEditingController();
    bool isLogin=true;
    await showDialog<void>(context: context, builder: (ctx)=> StatefulBuilder(builder: (ctx,setS)=> AlertDialog(
      title: Text(isLogin ? 'Vendor login' : 'Vendor register'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children:[
        TextField(controller: uCtrl, decoration: const InputDecoration(labelText:'Username', border: OutlineInputBorder())),
        const SizedBox(height:10),
        TextField(controller: pCtrl, decoration: const InputDecoration(labelText:'Password', border: OutlineInputBorder()), obscureText:true),
        if(!isLogin) ...[const SizedBox(height:10), TextField(controller: mCtrl, decoration: const InputDecoration(labelText:'Market / stall', border: OutlineInputBorder()))],
        const SizedBox(height:8),
        TextButton(onPressed: ()=> setS(()=> isLogin=!isLogin), child: Text(isLogin ? 'Need account? Register' : 'Have account? Login')),
      ])),
      actions:[
        TextButton(onPressed: ()=> Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () async {
          final u=uCtrl.text.trim(); final p=pCtrl.text.trim(); final m=mCtrl.text.trim();
          if(u.length<3 || p.length<4 || (!isLogin && m.length<2)){ ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Fill username, password, market'))); return; }
          try{
            Map<String,dynamic> res;
            if(isLogin){ res=await api.vendorLogin(username:u,password:p); }
            else { res=await api.vendorRegister(username:u,password:p,market:m); }
            final user=(res['username']??u).toString();
            await widget.onRoleChanged('vendor', user);
            if(ctx.mounted) Navigator.pop(ctx);
            if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isLogin ? 'Logged in as $user' : 'Registered $user')));
            if(mounted) setState((){});
          }catch(e){ ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString()))); }
        }, child: Text(isLogin ? 'Login' : 'Register'))
      ],
    )));
  }
}

