import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/posted_entities_store.dart';
import '../state/providers.dart';
import '../state/translation_provider.dart';
import '../widgets/tr_text.dart';
import 'place_detail_screen.dart';

final myPostedItemsRefreshProvider = StateProvider<int>((ref) => 0);

final myPostedItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(myPostedItemsRefreshProvider);
  final api = ref.watch(entitiesApiProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final store = PostedEntitiesStore(prefs);
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    final localIds = store.readUserEntityIds(user.uid);
    try {
      final remoteItems = await api.fetchOwnedEntities(ownerId: user.uid);
      final remoteIds = remoteItems
          .map((item) => (item['id'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toList();
      if (remoteIds.isNotEmpty) {
        await store.mergeUserEntityIds(userId: user.uid, entityIds: remoteIds);
      }
      if (remoteItems.isNotEmpty || localIds.isEmpty) {
        return remoteItems;
      }
    } catch (_) {
      // If owner lookup is unavailable, fall back to locally stored IDs.
    }
    if (localIds.isEmpty) return const <Map<String, dynamic>>[];
    return api.fetchEntitiesByIds(ids: localIds);
  }

  final guestIds = store.readGuestEntityIds();
  final localIds = store.readAllLocalEntityIds();
  final allIds = <String>[];
  final seen = <String>{};
  for (final id in [...guestIds, ...localIds]) {
    final clean = id.trim();
    if (clean.isEmpty || seen.contains(clean)) continue;
    seen.add(clean);
    allIds.add(clean);
  }
  if (allIds.isEmpty) return const <Map<String, dynamic>>[];
  return api.fetchEntitiesByIds(ids: allIds);
});

class MyPostedItemsScreen extends ConsumerWidget {
  const MyPostedItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(myPostedItemsProvider);
    final user = FirebaseAuth.instance.currentUser;
    final subtitle = user == null
        ? 'Guest mode (saved on this device)'
        : 'Signed in as ${user.email ?? user.displayName ?? user.uid}';

    return Scaffold(
      appBar: AppBar(
        title: const TrText('My posted items'),
        actions: [
          IconButton(
            onPressed: () {
              ref.read(myPostedItemsRefreshProvider.notifier).state++;
              ref.invalidate(myPostedItemsProvider);
            },
            icon: const Icon(Icons.refresh),
            tooltip: ref.read(translationControllerProvider).tr('Refresh'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrText(
              subtitle,
              translate: false,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TrText('Error:'),
                      const SizedBox(height: 4),
                      Text(err.toString()),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          ref
                              .read(myPostedItemsRefreshProvider.notifier)
                              .state++;
                          ref.invalidate(myPostedItemsProvider);
                        },
                        child: const TrText('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: TrText(
                        user == null
                            ? 'No guest posted items found on this device yet.'
                            : 'No posted items found for this account yet.',
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final name = (item['name'] ?? '').toString().trim();
                      final address =
                          (item['address'] ?? item['formatted_address'] ?? '')
                              .toString()
                              .trim();
                      final createdAt =
                          (item['createdAt'] ?? '').toString().trim();

                      return ListTile(
                        title: TrText(name.isEmpty ? '(no name)' : name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (address.isNotEmpty)
                              TrText(address, translate: false),
                            if (createdAt.isNotEmpty)
                              TrText('Created: $createdAt', translate: false),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlaceDetailScreen(entity: item),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
