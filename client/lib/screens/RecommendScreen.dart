import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/models/ArticlesModel.dart';
import 'package:client/providers/likedArticleProvider.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/article_card.dart';
import 'package:client/widgets/theme.dart';

/// Personalised picks. The backend asks the LLM to turn the user's likes into
/// interests, searches news for each, and ranks results against the likes.
class RecommendationScreen extends StatefulWidget {
  /// Whether this tab is currently visible; picks refresh when it becomes active
  /// and the user's likes have changed since the last load.
  final bool active;
  const RecommendationScreen({super.key, this.active = true});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  List<Article> _articles = [];
  List<String> _interests = [];
  bool _loading = false;
  String? _error;
  String? _loadedFor; // liked signature the current picks were built from

  @override
  void initState() {
    super.initState();
    if (widget.active) WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoad());
  }

  @override
  void didUpdateWidget(covariant RecommendationScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    final provider = context.read<LikedArticlesProvider>();
    await provider.ensureInitialized();
    if (mounted && provider.likedSignature != _loadedFor) _load();
  }

  Future<void> _load() async {
    final provider = context.read<LikedArticlesProvider>();
    await provider.ensureInitialized();
    final liked = provider.liked;
    final signature = provider.likedSignature;
    if (liked.isEmpty) {
      setState(() {
        _articles = [];
        _interests = [];
        _error = null;
        _loadedFor = signature;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Most recent likes carry the strongest signal.
      final recent = liked.reversed.take(10).toList();
      final recs = await Api.recommend(recent);
      if (!mounted) return;
      setState(() {
        _articles = recs.articles;
        _interests = recs.interests;
        _loadedFor = signature;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final likedCount = context.select<LikedArticlesProvider, int>((p) => p.likedCount);
    final stale = _loadedFor != null &&
        context.select<LikedArticlesProvider, String>((p) => p.likedSignature) != _loadedFor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('For You'),
        actions: [
          IconButton(
            tooltip: 'Refresh picks',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: _body(likedCount, stale),
    );
  }

  Widget _body(int likedCount, bool stale) {
    if (_loading) {
      return Column(children: [
        _banner(Icons.auto_awesome_rounded, 'Analyzing your likes and finding stories...'),
        const Expanded(child: ArticleListSkeleton()),
      ]);
    }
    if (_error != null) {
      return StateMessage(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load your picks",
        message: _error,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }
    if (likedCount == 0) {
      return const StateMessage(
        icon: Icons.favorite_border_rounded,
        title: 'Your picks start with a like',
        message: 'Tap the heart on stories you enjoy. We\'ll learn your interests and find more like them.',
      );
    }
    if (_articles.isEmpty) {
      return StateMessage(
        icon: Icons.travel_explore_rounded,
        title: 'No new stories found',
        message: 'Like a few more articles on different topics, then refresh.',
        actionLabel: 'Refresh',
        onAction: _load,
      );
    }
    return ArticleFeed(
      articles: _articles,
      onRefresh: _load,
      header: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (stale)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Material(
              color: context.colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.update_rounded, color: context.colors.primary),
                title: const Text('Your likes changed'),
                trailing: TextButton(onPressed: _load, child: const Text('Update')),
              ),
            ),
          ),
        Text('Based on your interests', style: context.text.labelMedium),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: _interests
              .map((i) => Chip(
                    avatar: Icon(Icons.auto_awesome_rounded, size: 16, color: context.aiColor),
                    label: Text(i),
                  ))
              .toList(),
        ),
      ]),
    );
  }

  Widget _banner(IconData icon, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
        child: Row(children: [
          Icon(icon, size: 18, color: context.aiColor),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: context.text.labelMedium?.copyWith(color: context.aiColor))),
        ]),
      );
}
