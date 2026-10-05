// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'views/home_page.dart'; // Import our new UI file

void main() {
  // Shows up in showLicensePage alongside package licenses.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Fluid R3 GM SoundFont'], await rootBundle.loadString('assets/LICENSE-FluidR3.txt'));
  });
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