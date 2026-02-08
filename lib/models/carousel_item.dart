class CarouselItem {
  CarouselItem({
    required this.itemId,
    required this.entityId,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.ctaLabel,
    required this.ctaUrl,
    required this.priority,
    required this.active,
  });

  final String itemId;
  final String entityId;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String ctaLabel;
  final String ctaUrl;
  final int priority;
  final bool active;

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
      imageUrl: json['image_url']?.toString() ??
          json['imageUrl']?.toString() ??
          '',
      ctaLabel:
          json['cta_label']?.toString() ?? json['ctaLabel']?.toString() ?? '',
      ctaUrl: json['cta_url']?.toString() ?? json['ctaUrl']?.toString() ?? '',
      priority: int.tryParse(json['priority']?.toString() ?? '') ?? 0,
      active: json['active'] == true,
    );
  }
}
