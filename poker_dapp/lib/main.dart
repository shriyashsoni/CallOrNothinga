import 'package:flutter/material.dart';
import 'game_screen.dart';

void main() {
  runApp(PokerApp());
}

class PokerApp extends StatelessWidget {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poker DApp',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: GameScreen(),
    );
  }
}
