import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'lan_bridge.dart';

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
  World? broadcastingWorld;

  @override
  void initState() {
    super.initState();
    fetchWorlds();
    timer = Timer.periodic(const Duration(seconds: 10), (_) => fetchWorlds());
  }

  @override
  void dispose() {
    timer?.cancel();
    // stop broadcast saat app ditutup
    LanBridge.stopBroadcast();
    super.dispose();
  }

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

  Future<void> toggleJoin(World world) async {
    if (broadcastingWorld?.code == world.code) {
      // sudah join -> stop
      await LanBridge.stopBroadcast();
      setState(() => broadcastingWorld = null);
      _showSnack('Broadcast "${world.name}" dihentikan');
      return;
    }

    // ganti world: stop lama dulu
    if (broadcastingWorld != null) {
      await LanBridge.stopBroadcast();
    }

    final ok = await LanBridge.startBroadcast(
      name: world.name,
      ip: RELAY_IP,
      port: world.port,
      players: world.players,
    );

    if (ok) {
      setState(() => broadcastingWorld = world);
      _showJoinInstructions(world);
    } else {
      _showSnack('Gagal memulai broadcast. Coba lagi.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showJoinInstructions(World world) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1F2E),
      title: Row(children: [
        const Icon(Icons.check_circle, color: Colors.green),
        const SizedBox(width: 8),
        const Expanded(child: Text('World Muncul di LAN!', style: TextStyle(fontSize: 17))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('"${world.name}" sekarang tampil di tab LAN Minecraft kamu.', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        const Text('Cara masuk:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        const Text('1. Buka Minecraft Bedrock', style: TextStyle(fontSize: 13)),
        const Text('2. Tab Play → tunggu beberapa detik', style: TextStyle(fontSize: 13)),
        Text('3. World "${world.name}" muncul di bagian LAN', style: const TextStyle(fontSize: 13)),
        const Text('4. Tap & Join!', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(.1), borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 16, color: Colors.orange),
            SizedBox(width: 6),
            Expanded(child: Text('Biarkan app ini terbuka saat bermain.', style: TextStyle(fontSize: 11))),
          ]),
        ),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Mengerti'))],
    ));
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
                  itemBuilder: (_, i) {
                    final w = worlds[i];
                    final isActive = broadcastingWorld?.code == w.code;
                    return WorldCard(
                      world: w,
                      isJoined: isActive,
                      onJoin: () => toggleJoin(w),
                    );
                  },
                ),
      ),
    );
  }
}

class WorldCard extends StatelessWidget {
  final World world;
  final bool isJoined;
  final VoidCallback onJoin;

  const WorldCard({super.key, required this.world, required this.isJoined, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isJoined ? const Color(0xFF123326) : const Color(0xFF171B26),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isJoined ? BorderSide(color: Colors.green.withOpacity(.5)) : BorderSide.none,
      ),
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
            if (isJoined) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(.15), borderRadius: BorderRadius.circular(20)),
                child: const Text('LAN AKTIF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.lightBlueAccent)),
              ),
            ],
            const Spacer(),
            Text('${world.players} pemain', style: const TextStyle(fontSize: 12, color: Colors.white38)),
          ]),
          const SizedBox(height: 10),
          Text(world.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Kode: ${world.code} · Host: ${world.uptimeSec ~/ 60}m lalu',
            style: const TextStyle(fontSize: 12, color: Colors.white38)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isJoined ? Colors.redAccent : const Color(0xFF34D399),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(isJoined ? Icons.stop : Icons.play_arrow),
              label: Text(isJoined ? 'STOP LAN' : 'JOIN VIA LAN'),
              onPressed: onJoin,
            ),
          ),
        ]),
      ),
    );
  }
}
