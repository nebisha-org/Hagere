import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agerelige_flutter_client/screens/categories_screen.dart';
import 'package:agerelige_flutter_client/screens/entities_screen.dart';

import 'package:agerelige_flutter_client/screens/add_listing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AgereLigeApp()));
}

class AgereLigeApp extends StatelessWidget {
  const AgereLigeApp({super.key});

  @override
  Widget build(BuildContext context) {
    // return MaterialApp(
    //   title: 'AgereLige',
    //   theme: ThemeData(useMaterial3: true),
    //   //home: const EntitiesScreen(),
    //   home: CategoriesScreen(),
    // );
    return MaterialApp(
      title: 'AgereLige',
      theme: ThemeData(useMaterial3: true),
      home: const CategoriesScreen(),
      routes: {
        AddListingScreen.routeName: (_) => const AddListingScreen(),
      },
    );
  }
}
