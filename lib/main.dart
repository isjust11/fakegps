import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const FakeGpsApp());
}

class FakeGpsApp extends StatelessWidget {
  const FakeGpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fake GPS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

