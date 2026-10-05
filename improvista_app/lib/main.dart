// lib/main.dart
import 'package:flutter/material.dart';
import 'views/home_page.dart'; // Import our new UI file

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Improvista',
      theme: ThemeData.dark(), // Using a dark theme
      home: const HomePage(),
    );
  }
}