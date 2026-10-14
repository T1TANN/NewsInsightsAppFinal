import 'package:flutter/material.dart';
import 'package:client/models/ArticlesModel.dart';
import 'package:client/models/Category_model.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/article_card.dart';
import 'package:client/widgets/theme.dart';

/// Search across all sources, or browse by topic.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  CategoryScreenState createState() => CategoryScreenState();
}

class CategoryScreenState extends State<CategoryScreen> {
  final List<Category> categories = [
    Category(id: "1", image: "assets/image/index1.jpg", name: 'National'),
    Category(id: "2", image: "assets/image/index2.jpg", name: 'Politics'),
    Category(id: "3", image: "assets/image/index3.jpg", name: 'Business'),
    Category(id: "4", image: "assets/image/index4.jpg", name: 'Technology'),
    Category(id: "5", image: "assets/image/index5.jpg", name: 'Sports'),
    Category(id: "6", image: "assets/image/index6.jpg", name: 'Entertainment'),
  ];

  final _search = TextEditingController();
  String? _query; // null = show topic grid
  List<Article> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _run(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    try {
      final results = await Api.news(query: query);
      if (!mounted) return;
      setState(() => _results = results);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    _search.clear();
    setState(() {
      _query = null;
      _results = [];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _run,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search 200,000 Indian News articles...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty && _query == null
                    ? null
                    : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded), onPressed: _clear),
              ),
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _query == null ? _topicGrid() : _resultsView(),
      ),
    );
  }

  Widget _topicGrid() {
    return GridView.builder(
      key: const ValueKey('grid'),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: Space.md,
        crossAxisSpacing: Space.md,
        childAspectRatio: 1.25,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat = categories[i];
        return Semantics(
          button: true,
          label: 'Browse ${cat.name} news',
          child: Material(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                _search.text = cat.name;
                _run(cat.name);
              },
              child: Stack(fit: StackFit.expand, children: [
                Image.asset(cat.image, fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC000000)],
                      stops: [0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: Space.md,
                  bottom: Space.md,
                  right: Space.md,
                  child: Text(cat.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _resultsView() {
    if (_loading) return const ArticleListSkeleton(key: ValueKey('loading'));
    if (_error != null) {
      return StateMessage(
        key: const ValueKey('error'),
        icon: Icons.cloud_off_rounded,
        title: 'Search failed',
        message: _error,
        actionLabel: 'Try again',
        onAction: () => _run(_query!),
      );
    }
    if (_results.isEmpty) {
      return StateMessage(
        key: const ValueKey('empty'),
        icon: Icons.search_off_rounded,
        title: 'No results for "$_query"',
        message: 'Try a broader or different search term.',
      );
    }
    return ArticleFeed(
      key: ValueKey('results-$_query'),
      articles: _results,
      onRefresh: () => _run(_query!),
      header: Text('${_results.length} results for "$_query"', style: context.text.labelMedium),
    );
  }
}
