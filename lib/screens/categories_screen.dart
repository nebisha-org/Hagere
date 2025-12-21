import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/category_providers.dart';
import '../state/providers.dart';
import 'entities_screen.dart';

// ✅ ADD
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
          // ✅ +1 for the home promo tile
          itemCount: cats.length + 1,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            // ✅ last row = $4.99 tile
            if (i == cats.length) {
              return entityIdAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Could not load device id: $e'),
                ),
                data: (entityId) => PromoteHomeTile(
                  entityId: entityId,
                  apiBaseUrl: apiBaseUrl, // from providers.dart
                ),
              );
            }

            // ✅ normal category rows (your existing behavior)
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

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../state/category_providers.dart';
// import 'entities_screen.dart';

// class CategoriesScreen extends ConsumerWidget {
//   const CategoriesScreen({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final cats = ref.watch(categoriesProvider);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('All Habesha'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: ListView.separated(
//           itemCount: cats.length,
//           separatorBuilder: (_, __) => const Divider(height: 1),
//           itemBuilder: (_, i) {
//             final c = cats[i];
//             return ListTile(
//               leading: Text(c.emoji, style: const TextStyle(fontSize: 22)),
//               title: Text(c.title),
//               trailing: const Icon(Icons.chevron_right),
//               onTap: () {
//                 ref.read(selectedCategoryProvider.notifier).state = c;

//                 Navigator.of(context).push(
//                   MaterialPageRoute(
//                     builder: (_) => const EntitiesScreen(),
//                   ),
//                 );
//               },
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
