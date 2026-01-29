import 'config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:agerelige_flutter_client/screens/categories_screen.dart';
import 'package:agerelige_flutter_client/screens/add_listing_screen.dart';
import 'package:agerelige_flutter_client/cache/entities_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('API_BASE_URL=$apiBaseUrl');
  await Hive.initFlutter();
  await EntitiesCache.open();
  runApp(const ProviderScope(child: AgereLigeApp()));
}

class AgereLigeApp extends StatelessWidget {
  const AgereLigeApp({super.key});

  @override
  Widget build(BuildContext context) {
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
