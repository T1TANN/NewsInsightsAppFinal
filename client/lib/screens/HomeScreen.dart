import 'package:flutter/material.dart';
import 'package:client/models/ArticlesModel.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/article_card.dart';
import 'package:client/widgets/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  static const topics = ['Top', 'India', 'Business', 'Technology', 'Sports', 'Science', 'Health', 'Entertainment'];

  String _topic = topics.first;
  final Map<String, List<Article>> _cache = {};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final topic = _topic;
    if (!force && _cache.containsKey(topic)) return;
    setState(() {
      _loading = !_cache.containsKey(topic);
      _error = null;
    });
    try {
      final articles = await Api.news(category: topic == 'Top' ? null : topic.toLowerCase());
      if (!mounted) return;
      setState(() => _cache[topic] = articles);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _select(String topic) {
    if (topic == _topic) return;
    setState(() => _topic = topic);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final articles = _cache[_topic];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('NewsInsights', style: context.text.headlineSmall?.copyWith(color: context.colors.primary)),
          Text(_today(), style: context.text.labelSmall),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
              itemCount: topics.length,
              separatorBuilder: (_, __) => const SizedBox(width: Space.sm),
              itemBuilder: (_, i) => ChoiceChip(
                label: Text(topics[i]),
                selected: topics[i] == _topic,
                onSelected: (_) => _select(topics[i]),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const ArticleListSkeleton()
          : _error != null && articles == null
              ? StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: "Couldn't load the news",
                  message: _error,
                  actionLabel: 'Try again',
                  onAction: () => _load(force: true),
                )
              : (articles ?? []).isEmpty
                  ? StateMessage(
                      icon: Icons.newspaper_rounded,
                      title: 'No stories right now',
                      message: 'Pull down to refresh or pick another topic.',
                      actionLabel: 'Refresh',
                      onAction: () => _load(force: true),
                    )
                  : ArticleFeed(articles: articles!, onRefresh: () => _load(force: true)),
    );
  }

  static String _today() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'];
    final d = DateTime.now();
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}
