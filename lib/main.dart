import 'package:flutter/material.dart';
import 'screens/user_list_screen.dart';

void main() {
  runApp(const AgereLigeApp());
}

class AgereLigeApp extends StatelessWidget {
  const AgereLigeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgereLige',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const UserListScreen(),
    );
  }
}
