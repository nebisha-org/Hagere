import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';

final categoriesProvider = Provider<List<AppCategory>>((ref) {
  return const [
    AppCategory(
      id: 'restaurants',
      title: 'Restaurants',
      emoji: '🍽️',
      tags: ['restaurant', 'ethiopian', 'eritrean', 'habesha', 'injera'],
    ),
    AppCategory(
      id: 'markets',
      title: 'Markets',
      emoji: '🛒',
      tags: ['market', 'grocery', 'ethiopian', 'eritrean', 'habesha'],
    ),
    AppCategory(
      id: 'events',
      title: 'Events',
      emoji: '🎤',
      tags: ['event', 'concert', 'party', 'cultural', 'ethiopian', 'eritrean'],
    ),
    AppCategory(
      id: 'jobs',
      title: 'Jobs',
      emoji: '💼',
      tags: ['jobs', 'hiring', 'career', 'ethiopian', 'eritrean', 'habesha'],
    ),
    AppCategory(
      id: 'rentals',
      title: 'Rentals',
      emoji: '🏠',
      tags: [
        'rentals',
        'apartment',
        'room',
        'housing',
        'ethiopian',
        'eritrean'
      ],
    ),
    AppCategory(
      id: 'services',
      title: 'Services',
      emoji: '🧾',
      tags: ['tax', 'lawyer', 'notary', 'travel', 'shipping', 'community'],
    ),
  ];
});

final selectedCategoryProvider = StateProvider<AppCategory?>((ref) => null);
