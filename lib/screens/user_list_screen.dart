import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../api/api_client.dart';
import '../models/user.dart';
import '../state/translation_provider.dart';
import '../widgets/tr_text.dart';

class UserListScreen extends HookConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = useMemoized(() => ApiClient());
    final future = useMemoized(() => api.listUsers(), [api]);
    final snapshot = useFuture(future);
    final translator = ref.watch(translationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const TrText('Users'),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                final id = await api.createUser(
                  name: 'Guest ${DateTime.now().millisecondsSinceEpoch}',
                  bio: 'Created from Flutter client',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content:
                          Text('${translator.tr('Created user')} $id'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${translator.tr('Create failed:')} ${e.toString()}',
                      ),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.add),
            tooltip: translator.tr('Create test user'),
          ),
        ],
      ),
      body: switch (snapshot.connectionState) {
        ConnectionState.waiting => const Center(
          child: CircularProgressIndicator(),
        ),
        _ =>
          snapshot.hasError
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TrText('Error:'),
                      const SizedBox(height: 4),
                      Text(snapshot.error.toString()),
                    ],
                  ),
                )
              : _UsersList(users: snapshot.data ?? const []),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            // Get presigned upload URL and object key.
            final (url, key) = await api.createImageUploadUrl();

            // 1x1 white JPEG bytes.
            final bytes = Uint8List.fromList([
              0xFF,
              0xD8,
              0xFF,
              0xDB,
              0x00,
              0x43,
              0x00,
              ...List<int>.filled(0x40, 0x08),
              0xFF,
              0xC0,
              0x00,
              0x11,
              0x08,
              0x00,
              0x01,
              0x00,
              0x01,
              0x01,
              0x01,
              0x11,
              0x00,
              0xFF,
              0xC4,
              0x00,
              0x14,
              0x00,
              0x01,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0xFF,
              0xDA,
              0x00,
              0x08,
              0x01,
              0x01,
              0x00,
              0x00,
              0x3F,
              0x00,
              0xD2,
              0xCF,
              0xFF,
              0xD9,
            ]);

            await api.uploadJpegToPresignedUrl(url, bytes);

            final id = await api.createUser(name: 'WithImage', imageUrl: key);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '${translator.tr('Uploaded & created user:')} $id'),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content: Text(
                    '${translator.tr('Upload failed:')} ${e.toString()}',
                  ),
                ),
              );
            }
          }
        },
        label: const TrText('Demo Upload'),
        icon: const Icon(Icons.cloud_upload),
      ),
    );
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList({required this.users});
  final List<User> users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(
        child: TrText('No users found. Tap + to create a test user.'),
      );
    }
    return ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final u = users[index];
        return ListTile(
          leading: CircleAvatar(
            child: TrText(
              u.name.isNotEmpty ? u.name[0] : '?',
              translate: false,
            ),
          ),
          title: TrText(u.name.isNotEmpty ? u.name : u.userID),
          subtitle: TrText(
            [u.city, u.state].where((e) => e.isNotEmpty).join(', '),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final api = ApiClient();
            final detail = await api.getUserById(u.userID);
            if (!context.mounted) return;
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: TrText(detail?.name ?? 'User'),
                content: Text(
                  '${translator.tr('Gender:')} ${detail?.gender}\n'
                  '${translator.tr('Bio:')} ${detail?.bio}\n'
                  '${translator.tr('Image:')} ${detail?.imageUrl}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
