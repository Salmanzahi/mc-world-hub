import 'package:flutter/material.dart';
import 'worlds_page.dart';

void main() {
  runApp(const McHubApp());
}

class McHubApp extends StatelessWidget {
  const McHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MC World Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0F14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF34D399),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const WorldsPage(),
    );
  }
}
