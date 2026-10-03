import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:client/models/ArticlesModel.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/article_card.dart';
import 'package:client/widgets/credibility_card.dart';
import 'package:client/widgets/summary_card.dart';
import 'package:client/widgets/theme.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Article article;
  const ArticleDetailScreen({super.key, required this.article});

  Future<void> _openOriginal(BuildContext context) async {
    final uri = Uri.tryParse(article.url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) showMessage(context, "Couldn't open the article link.", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: article.urlToImage.isEmpty ? null : 260,
            actions: [LikeButton(article: article), const SizedBox(width: Space.xs)],
            flexibleSpace: article.urlToImage.isEmpty
                ? null
                : FlexibleSpaceBar(background: NewsImage(article.urlToImage)),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: Space.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Chip(
                          label: Text(article.sourceName),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        if (article.timeAgo.isNotEmpty) Text(article.timeAgo, style: context.text.labelMedium),
                      ]),
                      const SizedBox(height: Space.md),
                      Text(article.title, style: context.text.headlineSmall),
                      if (article.author.isNotEmpty) ...[
                        const SizedBox(height: Space.sm),
                        Text('By ${article.author}', style: context.text.labelMedium),
                      ],
                      if (article.description.isNotEmpty) ...[
                        const SizedBox(height: Space.md),
                        Text(article.description, style: context.text.bodyLarge),
                      ],
                      const SizedBox(height: Space.lg),
                      SummaryPanel(load: () => Api.summarize(article: article)),
                      const SizedBox(height: Space.md),
                      CredibilityPanel(load: () => Api.verify(article: article)),
                      const SizedBox(height: Space.lg),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _openOriginal(context),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Read full article'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
