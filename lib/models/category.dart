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
}
