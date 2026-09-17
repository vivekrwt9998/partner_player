import 'package:flutter/material.dart';
import 'screens/main_shell.dart';

void main() {
  runApp(const PartnerGameApp());
}

class PartnerGameApp extends StatelessWidget {
  const PartnerGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Partner Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}
