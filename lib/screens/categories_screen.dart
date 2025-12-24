import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/category_providers.dart';
import '../state/providers.dart';
import 'entities_screen.dart';

import 'package:agerelige_flutter_client/screens/add_listing_screen.dart';
import 'package:agerelige_flutter_client/widgets/add_listing_card.dart';
import 'package:agerelige_flutter_client/widgets/promote_home_tile.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final entityIdAsync = ref.watch(currentEntityIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Habesha'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: cats.length + 2,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            // Row after categories: Add Listing card
            if (i == cats.length) {
              return AddListingCard(
                onTap: () => Navigator.of(context).pushNamed(
                  AddListingScreen.routeName,
                ),
                subtitle: 'Add your business listing, then promote it.',
              );
            }

            // Last row: Promote tile
            if (i == cats.length + 1) {
              return entityIdAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Could not load device id: $e'),
                ),
                data: (entityId) => PromoteHomeTile(
                  entityId: entityId,
                  apiBaseUrl: apiBaseUrl,
                ),
              );
            }

            // Normal category rows
            final c = cats[i];
            return ListTile(
              leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
              title: Text(c.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ref.read(selectedCategoryProvider.notifier).state = c;

                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EntitiesScreen()),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
