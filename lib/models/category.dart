class AppCategory {
  final String id;
  final String title;
  final String emoji;
  final List<String> tags; // used for filtering + future discovery prompts

  const AppCategory({
    required this.id,
    required this.title,
    required this.emoji,
    required this.tags,
  });

  AppCategory copyWith({
    String? id,
    String? title,
    String? emoji,
    List<String>? tags,
  }) {
    return AppCategory(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      tags: tags ?? this.tags,
    );
  }
}
