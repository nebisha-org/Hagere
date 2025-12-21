import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';

final categoriesProvider = Provider<List<AppCategory>>((ref) {
  return const [
    AppCategory(
      id: 'restaurants',
      title: 'Restaurants',
      emoji: '🍽️',
      tags: [
        'restaurant',
        'diner',
        'cafe',
        'carry-out',
        'injera',
        'tibs',
        'kitfo',
        'shiro',
      ],
    ),
    AppCategory(
      id: 'markets',
      title: 'Markets',
      emoji: '🛒',
      tags: [
        'market',
        'grocery',
        'supermarket',
        'store',
        'butcher',
        'bakery',
        'injera',
        'spices',
      ],
    ),
    AppCategory(
      id: 'events',
      title: 'Events',
      emoji: '🎤',
      tags: [
        'event',
        'concert',
        'festival',
        'party',
        'show',
        'night',
        'tickets',
        'club',
        'lounge',
      ],
    ),
    AppCategory(
      id: 'jobs',
      title: 'Jobs',
      emoji: '💼',
      tags: [
        'job',
        'jobs',
        'hiring',
        'career',
        'position',
        'apply',
        'recruiting',
        'opening',
      ],
    ),
    AppCategory(
      id: 'rentals',
      title: 'Rentals',
      emoji: '🏠',
      tags: [
        'rental',
        'rent',
        'apartment',
        'room',
        'housing',
        'lease',
        'sublet',
        'studio',
        'basement',
      ],
    ),
    AppCategory(
      id: 'services',
      title: 'Services',
      emoji: '🧾',
      tags: [
        'tax',
        'accounting',
        'cpa',
        'law',
        'lawyer',
        'attorney',
        'notary',
        'travel',
        'shipping',
        'cargo',
        'remittance',
        'money transfer',
        'insurance',
        'dmv',
        'translation',
      ],
    ),
  ];
});

final selectedCategoryProvider = StateProvider<AppCategory?>((ref) => null);
