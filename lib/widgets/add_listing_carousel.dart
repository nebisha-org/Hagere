import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/carousel_item.dart';
import 'tr_text.dart';
import 'qc_editable_text.dart';
import 'qc_editable_image.dart';

class PromoTileData {
  PromoTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.tileKey,
    this.imageUrl,
    this.ctaLabel,
    this.ctaUrl,
    this.onTap,
    this.entityType,
    this.entityId,
    this.item,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final Key? tileKey;
  final String? imageUrl;
  final String? ctaLabel;
  final String? ctaUrl;
  final VoidCallback? onTap;
  final String? entityType;
  final String? entityId;
  final CarouselItem? item;
}

class AddListingCarousel extends StatefulWidget {
  const AddListingCarousel({
    super.key,
    required this.onAddTap,
    this.items = const [],
    this.height,
    this.onEntityTap,
  });

  final VoidCallback onAddTap;
  final List<CarouselItem> items;
  final double? height;
  final void Function(CarouselItem item)? onEntityTap;

  @override
  State<AddListingCarousel> createState() => _AddListingCarouselState();
}

class _AddListingCarouselState extends State<AddListingCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _basePage = 0;
  List<PromoTileData> _tiles = [];
  static const bool _disableAutoscroll =
      bool.fromEnvironment('DISABLE_CAROUSEL_AUTOSCROLL', defaultValue: false);

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
        tileKey: const Key('add_listing_tile'),
        onTap: widget.onAddTap,
        ctaLabel: 'Get started',
      ),
    ];

    if (widget.items.isNotEmpty) {
      final remoteTiles = <PromoTileData>[];
      for (var i = 0; i < widget.items.length; i++) {
        final item = widget.items[i];
        final gradient = _palette[i % _palette.length];
        final hasEntityTap =
            widget.onEntityTap != null && item.entityId.isNotEmpty;
        remoteTiles.add(
          PromoTileData(
            title: item.title.isEmpty ? 'Community Highlight' : item.title,
            subtitle:
                item.subtitle.isEmpty ? 'Tap to learn more.' : item.subtitle,
            icon: Icons.campaign,
            gradient: gradient,
            imageUrl: item.imageUrl.isEmpty ? null : item.imageUrl,
            ctaLabel: item.ctaLabel.isEmpty ? 'Learn more' : item.ctaLabel,
            ctaUrl: hasEntityTap
                ? null
                : (item.ctaUrl.isEmpty ? null : item.ctaUrl),
            onTap: hasEntityTap ? () => widget.onEntityTap!(item) : null,
            entityType: 'carousel',
            entityId: item.itemId,
            item: item,
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

  void _goToNextSlide() {
    if (!_controller.hasClients) return;
    final current = (_controller.page ?? _basePage).round();
    _controller.animateToPage(
      current + 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  void _goToPreviousSlide() {
    if (!_controller.hasClients) return;
    final current = (_controller.page ?? _basePage).round();
    _controller.animateToPage(
      current - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _syncTiles();
    _controller =
        PageController(viewportFraction: 0.86, initialPage: _basePage);
    if (!_disableAutoscroll) {
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
          return _PromoTile(
            data: tile,
            onPrevSlide: _goToPreviousSlide,
            onNextSlide: _goToNextSlide,
          );
        },
      ),
    );
  }
}

class _PromoTile extends StatelessWidget {
  const _PromoTile({
    required this.data,
    this.onPrevSlide,
    this.onNextSlide,
  });

  final PromoTileData data;
  final VoidCallback? onPrevSlide;
  final VoidCallback? onNextSlide;
  static const bool _disableRemoteImages =
      bool.fromEnvironment('DISABLE_REMOTE_IMAGES', defaultValue: false);

  @override
  Widget build(BuildContext context) {
    final hasImage = data.imageUrl != null && data.imageUrl!.isNotEmpty;
    final canEdit = data.entityType != null && data.entityId != null;
    final isAddListingTile = data.tileKey == const Key('add_listing_tile');
    final aiHasImageText = data.item?.aiImageHasText == true;
    final aiLayoutMode = (data.item?.aiLayoutMode ?? '').trim().toLowerCase();
    final preferReadableOverlay =
        aiHasImageText || aiLayoutMode == 'separate_media';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: data.tileKey,
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Keep the "Add your listing" tile as a 1-tap action.
            if (isAddListingTile) {
              if (data.onTap != null) {
                data.onTap!();
                return;
              }
              final rawUrl = data.ctaUrl;
              if (rawUrl == null || rawUrl.isEmpty) return;
              final uri = Uri.tryParse(rawUrl);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return;
            }

            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _PromoDetailSheet(data: data),
            );
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
                  if (hasImage && !_disableRemoteImages)
                    Positioned.fill(
                      child: canEdit
                          ? QcEditableImage(
                              entityType: data.entityType!,
                              entityId: data.entityId!,
                              fieldKey: 'image_url',
                              imageUrl: data.imageUrl!,
                              child: Image.network(
                                data.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            )
                          : Image.network(
                              data.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                    ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: data.gradient
                              .map((c) => hasImage
                                  ? c.withOpacity(
                                      preferReadableOverlay ? 0.84 : 0.6)
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
                        IconButton(
                          onPressed: onPrevSlide,
                          tooltip: 'Previous',
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white70,
                          ),
                          splashRadius: 18,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
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
                              canEdit
                                  ? QcEditableText(
                                      data.title,
                                      entityType: data.entityType!,
                                      entityId: data.entityId!,
                                      fieldKey: 'title',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    )
                                  : TrText(
                                      data.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                              const SizedBox(height: 4),
                              canEdit
                                  ? QcEditableText(
                                      data.subtitle,
                                      entityType: data.entityType!,
                                      entityId: data.entityId!,
                                      fieldKey: 'subtitle',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    )
                                  : TrText(
                                      data.subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                              if (data.ctaLabel != null &&
                                  data.ctaLabel!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: canEdit
                                        ? QcEditableText(
                                            data.ctaLabel!,
                                            entityType: data.entityType!,
                                            entityId: data.entityId!,
                                            fieldKey: 'cta_label',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                            ),
                                          )
                                        : TrText(
                                            data.ctaLabel!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                        IconButton(
                          onPressed: onNextSlide,
                          tooltip: 'Next',
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white70,
                          ),
                          splashRadius: 18,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
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

class _LinkAction {
  const _LinkAction({
    required this.label,
    required this.url,
    required this.icon,
  });

  final String label;
  final String url;
  final IconData icon;
}

class _PromoDetailSheet extends StatelessWidget {
  const _PromoDetailSheet({required this.data});

  final PromoTileData data;
  static const bool _disableRemoteImages =
      bool.fromEnvironment('DISABLE_REMOTE_IMAGES', defaultValue: false);

  List<String> _uniqueNonEmpty(Iterable<String> values) {
    final out = <String>[];
    final seen = <String>{};
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final normalized = value.toLowerCase();
      if (seen.add(normalized)) {
        out.add(value);
      }
    }
    return out;
  }

  Future<void> _launchExternal(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _runPrimaryAction(BuildContext context) async {
    final onTap = data.onTap;
    final rawUrl = (data.ctaUrl ?? '').trim();

    Navigator.of(context).pop();

    if (onTap != null) {
      Future.microtask(onTap);
      return;
    }

    if (rawUrl.isEmpty) return;
    await _launchExternal(rawUrl);
  }

  Future<void> _openImagePreview(BuildContext context, String imageUrl) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return GestureDetector(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Dialog(
            insetPadding: const EdgeInsets.all(16),
            backgroundColor: Colors.transparent,
            child: InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
      child: child,
    );
  }

  Widget _actionWrap(List<_LinkAction> actions) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions
          .map(
            (action) => OutlinedButton.icon(
              onPressed: () => _launchExternal(action.url),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.35)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              icon: Icon(action.icon, size: 16),
              label: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = data.item;
    final details = (item?.details ?? '').trim();
    final phone = (item?.phone ?? '').trim();
    final email = (item?.email ?? '').trim();
    final websiteUrl = (item?.websiteUrl ?? '').trim();
    final instagramUrl = (item?.instagramUrl ?? '').trim();
    final facebookUrl = (item?.facebookUrl ?? '').trim();
    final tiktokUrl = (item?.tiktokUrl ?? '').trim();
    final youtubeUrl = (item?.youtubeUrl ?? '').trim();
    final xUrl = (item?.xUrl ?? '').trim();
    final aiHasImageText = item?.aiImageHasText == true;
    final aiDensity = (item?.aiImageTextDensity ?? '').trim();
    final aiExcerpt = (item?.aiImageTextExcerpt ?? '').trim();
    final aiLayoutMode = (item?.aiLayoutMode ?? '').trim().toLowerCase();
    final aiLayoutReason = (item?.aiLayoutReason ?? '').trim();

    final imageUrls = _uniqueNonEmpty([
      (data.imageUrl ?? '').trim(),
      ...?item?.imageUrls,
    ]);
    final videoUrls = _uniqueNonEmpty([
      (item?.videoUrl ?? '').trim(),
      ...?item?.videoUrls,
    ]);

    final hasImage = imageUrls.isNotEmpty && !_disableRemoteImages;
    final preferSeparateMedia =
        aiLayoutMode == 'separate_media' || aiHasImageText;
    final showHeroBackground = hasImage && !preferSeparateMedia;
    final hasPrimary =
        data.onTap != null || (data.ctaUrl ?? '').trim().isNotEmpty;
    final primaryLabel = (data.ctaLabel ?? '').trim().isNotEmpty
        ? data.ctaLabel!.trim()
        : (data.onTap != null ? 'View details' : 'Open');

    final dialPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final contactActions = <_LinkAction>[
      if (dialPhone.isNotEmpty)
        _LinkAction(label: 'Call', url: 'tel:$dialPhone', icon: Icons.call),
      if (email.isNotEmpty)
        _LinkAction(
          label: 'Email',
          url: 'mailto:$email',
          icon: Icons.email_outlined,
        ),
      if (websiteUrl.isNotEmpty)
        _LinkAction(
          label: 'Website',
          url: websiteUrl,
          icon: Icons.public_outlined,
        ),
    ];
    final socialActions = <_LinkAction>[
      if (instagramUrl.isNotEmpty)
        _LinkAction(
          label: 'Instagram',
          url: instagramUrl,
          icon: Icons.camera_alt_outlined,
        ),
      if (facebookUrl.isNotEmpty)
        _LinkAction(
          label: 'Facebook',
          url: facebookUrl,
          icon: Icons.facebook_outlined,
        ),
      if (tiktokUrl.isNotEmpty)
        _LinkAction(label: 'TikTok', url: tiktokUrl, icon: Icons.music_note),
      if (youtubeUrl.isNotEmpty)
        _LinkAction(
          label: 'YouTube',
          url: youtubeUrl,
          icon: Icons.play_circle_outline,
        ),
      if (xUrl.isNotEmpty)
        _LinkAction(label: 'X', url: xUrl, icon: Icons.alternate_email),
    ];
    final videoActions = <_LinkAction>[
      for (final videoUrl in videoUrls)
        _LinkAction(
          label: 'Watch video',
          url: videoUrl,
          icon: Icons.ondemand_video_outlined,
        ),
    ];

    final gradient = LinearGradient(
      colors: data.gradient,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: gradient),
                child: Stack(
                  children: [
                    if (showHeroBackground)
                      Positioned.fill(
                        child: Image.network(
                          imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black
                              .withOpacity(showHeroBackground ? 0.35 : 0.15),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                          child: Row(
                            children: [
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close),
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              if (hasImage && preferSeparateMedia) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.network(
                                      imageUrls.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Text(
                                data.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                data.subtitle,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _glassCard(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.event_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        data.subtitle,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (details.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _sectionTitle('About this event'),
                                _glassCard(
                                  child: Text(
                                    details,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                              if (aiHasImageText ||
                                  aiExcerpt.isNotEmpty ||
                                  aiLayoutReason.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _sectionTitle('Smart readability'),
                                _glassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        preferSeparateMedia
                                            ? 'Image separated from text for clearer reading.'
                                            : 'Overlay readability verified by AI.',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (aiDensity.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            'Detected text density: $aiDensity',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      if (aiExcerpt.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            'Detected text: "$aiExcerpt"',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      if (aiLayoutReason.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            aiLayoutReason,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              if (imageUrls.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _sectionTitle('Photos'),
                                SizedBox(
                                  height: 96,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: imageUrls.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      final imageUrl = imageUrls[index];
                                      return InkWell(
                                        onTap: () => _openImagePreview(
                                            context, imageUrl),
                                        borderRadius: BorderRadius.circular(12),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.network(
                                            imageUrl,
                                            width: 130,
                                            height: 96,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox(
                                              width: 130,
                                              height: 96,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                              if (contactActions.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _sectionTitle('Contact'),
                                _actionWrap(contactActions),
                              ],
                              if (socialActions.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _sectionTitle('Social'),
                                _actionWrap(socialActions),
                              ],
                              if (videoActions.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _sectionTitle('Videos'),
                                _actionWrap(videoActions),
                              ],
                              if ((data.ctaUrl ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _glassCard(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.link,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          (data.ctaUrl ?? '').trim(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: hasPrimary
                                      ? () => _runPrimaryAction(context)
                                      : null,
                                  icon: const Icon(Icons.arrow_forward),
                                  label: TrText(primaryLabel, translate: false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.35),
                                  ),
                                ),
                                child: const TrText('Close', translate: false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
