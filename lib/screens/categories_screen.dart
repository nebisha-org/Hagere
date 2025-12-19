import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/category_providers.dart';
import 'entities_screen.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.separated(
          itemCount: cats.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final c = cats[i];
            return ListTile(
              leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
              title: Text(c.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ref.read(selectedCategoryProvider.notifier).state = c;

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EntitiesScreen(),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
