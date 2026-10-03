class Article {
  final String sourceName;
  final String author;
  final String title;
  final String description;
  final String url;
  final String urlToImage;
  final DateTime? publishedAt;
  final String content;
  final String category;

  /// Set on personalised recommendations: the interest it matched and why it was picked.
  final String? interest;
  final String? reason;

  const Article({
    required this.title,
    required this.description,
    required this.url,
    required this.author,
    required this.publishedAt,
    required this.sourceName,
    required this.urlToImage,
    required this.content,
    this.category = 'general',
    this.interest,
    this.reason,
  });

  factory Article.fromJson(Map<String, dynamic> json, {String? category}) {
    final source = json['source'];
    return Article(
      title: (json['title'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      url: (json['url'] ?? '').toString(),
      author: (json['author'] ?? '').toString(),
      publishedAt: DateTime.tryParse((json['publishedAt'] ?? '').toString())?.toLocal(),
      sourceName: (source is Map ? source['name'] : source)?.toString() ?? 'Unknown',
      urlToImage: (json['urlToImage'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      category: category ?? (json['category'] ?? 'general').toString(),
      interest: json['interest']?.toString(),
      reason: json['reason']?.toString(),
    );
  }

  /// "5m ago", "3h ago", "2d ago" or a date.
  String get timeAgo {
    final t = publishedAt;
    if (t == null) return '';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${months[t.month - 1]} ${t.year}';
  }
}
