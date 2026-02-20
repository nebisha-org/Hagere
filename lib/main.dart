import 'config/env.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

import 'package:agerelige_flutter_client/screens/categories_screen.dart';
import 'package:agerelige_flutter_client/screens/add_listing_screen.dart';
import 'package:agerelige_flutter_client/screens/feedback_screen.dart';
import 'package:agerelige_flutter_client/cache/entities_cache.dart';
import 'package:agerelige_flutter_client/state/providers.dart';
import 'package:agerelige_flutter_client/state/translation_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('API_BASE_URL=$apiBaseUrl');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  await Hive.initFlutter();
  await EntitiesCache.open();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AgereLigeApp(),
    ),
  );
}

class AgereLigeApp extends ConsumerWidget {
  const AgereLigeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(entitiesSyncDriverProvider);

    return MaterialApp(
      // Always hide the Flutter debug banner. Reviewers flagged debug banners in
      // App Store screenshots (Guideline 2.3.10).
      debugShowCheckedModeBanner: false,
      title: 'AllHabesha',
      theme: ThemeData(useMaterial3: true),
      home: const CategoriesScreen(),
      routes: {
        AddListingScreen.routeName: (_) => const AddListingScreen(),
        FeedbackScreen.routeName: (_) => const FeedbackScreen(),
      },
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
    );
  }
}
