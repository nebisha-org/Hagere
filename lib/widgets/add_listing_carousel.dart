import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/carousel_item.dart';

class PromoTileData {
  PromoTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.imageUrl,
    this.ctaLabel,
    this.ctaUrl,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String? imageUrl;
  final String? ctaLabel;
  final String? ctaUrl;
  final VoidCallback? onTap;
}

class AddListingCarousel extends StatefulWidget {
  const AddListingCarousel({
    super.key,
    required this.onAddTap,
    this.items = const [],
    this.height,
  });

  final VoidCallback onAddTap;
  final List<CarouselItem> items;
  final double? height;

  @override
  State<AddListingCarousel> createState() => _AddListingCarouselState();
}

class _AddListingCarouselState extends State<AddListingCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _basePage = 0;
  List<PromoTileData> _tiles = [];

  static const List<List<Color>> _palette = [
    [Color(0xFF0F766E), Color(0xFF14B8A6)],
    [Color(0xFF7C2D12), Color(0xFFF97316)],
    [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
    [Color(0xFF4C1D95), Color(0xFFA855F7)],
    [Color(0xFF0F172A), Color(0xFF334155)],
  ];

  List<PromoTileData> _buildTiles() {
    final tiles = <PromoTileData>[
      PromoTileData(
        title: 'Add your listing',
        subtitle: 'Create your business listing and get discovered.',
        icon: Icons.add_business,
        gradient: const [Color(0xFF1B1F3B), Color(0xFF3B3F68)],
        onTap: widget.onAddTap,
        ctaLabel: 'Get started',
      ),
    ];

    if (widget.items.isNotEmpty) {
      final remoteTiles = <PromoTileData>[];
      for (var i = 0; i < widget.items.length; i++) {
        final item = widget.items[i];
        final gradient = _palette[i % _palette.length];
        remoteTiles.add(
          PromoTileData(
            title: item.title.isEmpty ? 'Community Highlight' : item.title,
            subtitle: item.subtitle.isEmpty
                ? 'Tap to learn more.'
                : item.subtitle,
            icon: Icons.campaign,
            gradient: gradient,
            imageUrl: item.imageUrl.isEmpty ? null : item.imageUrl,
            ctaLabel: item.ctaLabel.isEmpty ? 'Learn more' : item.ctaLabel,
            ctaUrl: item.ctaUrl.isEmpty ? null : item.ctaUrl,
          ),
        );
      }
      tiles.addAll(remoteTiles);
    } else {
      tiles.addAll([
        PromoTileData(
          title: 'Featured Spot',
          subtitle: 'Be seen by more people this week.',
          icon: Icons.star,
          gradient: _palette[0],
        ),
        PromoTileData(
          title: 'Promote Deals',
          subtitle: 'Highlight your offers to nearby users.',
          icon: Icons.campaign,
          gradient: _palette[1],
        ),
        PromoTileData(
          title: 'Boost Visibility',
          subtitle: 'Move to the top of your category.',
          icon: Icons.trending_up,
          gradient: _palette[2],
        ),
        PromoTileData(
          title: 'Add Photos',
          subtitle: 'Great photos get more clicks.',
          icon: Icons.photo_camera,
          gradient: _palette[3],
        ),
      ]);
    }

    return tiles;
  }

  void _syncTiles({bool jump = false}) {
    _tiles = _buildTiles();
    _basePage = _tiles.length * 1000;
    if (jump && _controller.hasClients) {
      _controller.jumpToPage(_basePage);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncTiles();
    _controller = PageController(viewportFraction: 0.86, initialPage: _basePage);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      final current = (_controller.page ?? _basePage).round();
      final next = current + 1;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
      );
      if (next >= _basePage + (_tiles.length * 200)) {
        final normalized = _basePage + (next % _tiles.length);
        Future.delayed(const Duration(milliseconds: 950), () {
          if (_controller.hasClients) {
            _controller.jumpToPage(normalized);
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant AddListingCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _syncTiles(jump: true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height ?? 140,
      child: PageView.builder(
        controller: _controller,
        reverse: false,
        itemBuilder: (context, index) {
          final tile = _tiles[index % _tiles.length];
          return _PromoTile(data: tile);
        },
      ),
    );
  }
}

class _PromoTile extends StatelessWidget {
  const _PromoTile({required this.data});

  final PromoTileData data;

  @override
  Widget build(BuildContext context) {
    final hasImage = data.imageUrl != null && data.imageUrl!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (data.onTap != null) {
              data.onTap!();
              return;
            }
            final rawUrl = data.ctaUrl;
            if (rawUrl == null || rawUrl.isEmpty) return;
            final uri = Uri.tryParse(rawUrl);
            if (uri == null) return;
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  if (hasImage)
                    Positioned.fill(
                      child: Image.network(
                        data.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: data.gradient
                              .map((c) => hasImage
                                  ? c.withOpacity(0.6)
                                  : c)
                              .toList(),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Icon(data.icon, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                data.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                data.subtitle,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              if (data.ctaLabel != null &&
                                  data.ctaLabel!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      data.ctaLabel!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
