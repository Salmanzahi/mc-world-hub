import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const HUB_URL = 'https://mc.salmanzahi.my.id';
const RELAY_IP = '172.197.221.186';

class World {
  final String code, name;
  final int players, port, uptimeSec;
  World({required this.code, required this.name, required this.players, required this.port, required this.uptimeSec});

  factory World.fromJson(Map<String, dynamic> j) => World(
    code: j['code'] ?? '', name: j['name'] ?? '?',
    players: j['players'] ?? 0, port: j['port'] ?? 19132,
    uptimeSec: j['uptime_sec'] ?? 0,
  );
}

class WorldsPage extends StatefulWidget {
  const WorldsPage({super.key});
  @override
  State<WorldsPage> createState() => _WorldsPageState();
}

class _WorldsPageState extends State<WorldsPage> {
  List<World> worlds = [];
  bool loading = true;
  String? error;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    fetchWorlds();
    timer = Timer.periodic(const Duration(seconds: 10), (_) => fetchWorlds());
  }

  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  Future<void> fetchWorlds() async {
    try {
      final res = await http.get(Uri.parse('$HUB_URL/api/worlds')).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['ok'] == true) {
        setState(() {
          worlds = (data['worlds'] as List).map((w) => World.fromJson(w)).toList();
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      setState(() { loading = false; error = 'Tidak bisa terhubung ke server'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MC World Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF141821),
        actions: [
          IconButton(onPressed: fetchWorlds, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchWorlds,
        child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null && worlds.isEmpty
            ? Center(child: Text(error!, style: const TextStyle(color: Colors.redAccent)))
            : worlds.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videogame_asset_off, size: 56, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('Belum ada world yang di-host', style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: worlds.length,
                  itemBuilder: (_, i) => WorldCard(world: worlds[i]),
                ),
      ),
    );
  }
}

class WorldCard extends StatelessWidget {
  final World world;
  const WorldCard({super.key, required this.world});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF171B26),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
              ]),
            ),
            const Spacer(),
            Text('${world.players} pemain', style: const TextStyle(fontSize: 12, color: Colors.white38)),
          ]),
          const SizedBox(height: 10),
          Text(world.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Kode: ${world.code} · Port: ${world.port}',
            style: const TextStyle(fontSize: 12, color: Colors.white38)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34D399),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('JOIN WORLD'),
              onPressed: () => showJoinInfo(context),
            ),
          ),
        ]),
      ),
    );
  }

  void showJoinInfo(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1F2E),
      title: const Text('Cara Join', style: TextStyle(fontSize: 18)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('1. Buka Minecraft Bedrock', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        const Text('2. Tab Play → Servers → Add Server', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        SelectableText('Server: $RELAY_IP', style: const TextStyle(fontSize: 14, color: Colors.greenAccent)),
        SelectableText('Port: ${world.port}', style: const TextStyle(fontSize: 14, color: Colors.greenAccent)),
        const SizedBox(height: 10),
        const Text('(Fitur auto-inject LAN segera hadir)', style: TextStyle(fontSize: 11, color: Colors.white24)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ));
  }
}
