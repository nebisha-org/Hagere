class CarouselItem {
  CarouselItem({
    required this.itemId,
    required this.entityId,
    required this.title,
    required this.subtitle,
    required this.details,
    required this.imageUrl,
    required this.imageUrls,
    required this.videoUrl,
    required this.videoUrls,
    required this.ctaLabel,
    required this.ctaUrl,
    required this.phone,
    required this.email,
    required this.websiteUrl,
    required this.instagramUrl,
    required this.facebookUrl,
    required this.tiktokUrl,
    required this.youtubeUrl,
    required this.xUrl,
    required this.aiImageHasText,
    required this.aiImageTextDensity,
    required this.aiImageTextExcerpt,
    required this.aiLayoutMode,
    required this.aiLayoutReason,
    required this.priority,
    required this.active,
  });

  final String itemId;
  final String entityId;
  final String title;
  final String subtitle;
  final String details;
  final String imageUrl;
  final List<String> imageUrls;
  final String videoUrl;
  final List<String> videoUrls;
  final String ctaLabel;
  final String ctaUrl;
  final String phone;
  final String email;
  final String websiteUrl;
  final String instagramUrl;
  final String facebookUrl;
  final String tiktokUrl;
  final String youtubeUrl;
  final String xUrl;
  final bool aiImageHasText;
  final String aiImageTextDensity;
  final String aiImageTextExcerpt;
  final String aiLayoutMode;
  final String aiLayoutReason;
  final int priority;
  final bool active;

  static String _readString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static List<String> _readStringList(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    final out = <String>[];
    final seen = <String>{};

    void addValue(String raw) {
      final value = raw.trim();
      if (value.isEmpty) return;
      final normalized = value.toLowerCase();
      if (seen.add(normalized)) {
        out.add(value);
      }
    }

    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      if (value is List) {
        for (final entry in value) {
          addValue(entry.toString());
        }
      } else {
        final raw = value.toString();
        for (final entry in raw.split(',')) {
          addValue(entry);
        }
      }
      if (out.isNotEmpty) break;
    }

    return out;
  }

  factory CarouselItem.fromJson(Map<String, dynamic> json) {
    return CarouselItem(
      itemId: json['item_id']?.toString() ??
          json['itemId']?.toString() ??
          json['id']?.toString() ??
          '',
      entityId:
          json['entity_id']?.toString() ?? json['entityId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      details: _readString(
        json,
        const ['details', 'description', 'body', 'full_text', 'fullText'],
      ),
      imageUrl: _readString(
        json,
        const ['image_url', 'imageUrl', 'image', 'poster_url', 'posterUrl'],
      ),
      imageUrls: _readStringList(
        json,
        const ['image_urls', 'imageUrls', 'images', 'gallery_images'],
      ),
      videoUrl: _readString(
        json,
        const ['video_url', 'videoUrl', 'trailer_url', 'trailerUrl'],
      ),
      videoUrls:
          _readStringList(json, const ['video_urls', 'videoUrls', 'videos']),
      ctaLabel: _readString(json, const ['cta_label', 'ctaLabel']),
      ctaUrl: _readString(json, const ['cta_url', 'ctaUrl']),
      phone: _readString(
        json,
        const ['phone', 'phone_number', 'phoneNumber', 'contact_phone'],
      ),
      email: _readString(
        json,
        const ['email', 'contact_email', 'contactEmail'],
      ),
      websiteUrl: _readString(
        json,
        const ['website_url', 'websiteUrl', 'website', 'site_url', 'siteUrl'],
      ),
      instagramUrl: _readString(
        json,
        const ['instagram_url', 'instagramUrl', 'instagram'],
      ),
      facebookUrl:
          _readString(json, const ['facebook_url', 'facebookUrl', 'facebook']),
      tiktokUrl: _readString(
        json,
        const ['tiktok_url', 'tiktokUrl', 'tiktok'],
      ),
      youtubeUrl: _readString(
        json,
        const ['youtube_url', 'youtubeUrl', 'youtube'],
      ),
      xUrl: _readString(json, const ['x_url', 'xUrl', 'twitter_url']),
      aiImageHasText:
          json['ai_image_has_text'] == true || json['aiImageHasText'] == true,
      aiImageTextDensity: _readString(
        json,
        const ['ai_image_text_density', 'aiImageTextDensity'],
      ),
      aiImageTextExcerpt: _readString(
        json,
        const ['ai_image_text_excerpt', 'aiImageTextExcerpt'],
      ),
      aiLayoutMode: _readString(
        json,
        const ['ai_layout_mode', 'aiLayoutMode', 'layout_mode', 'layoutMode'],
      ),
      aiLayoutReason: _readString(
        json,
        const ['ai_layout_reason', 'aiLayoutReason'],
      ),
      priority: int.tryParse(json['priority']?.toString() ?? '') ?? 0,
      active: json['active'] == true,
    );
  }
}
