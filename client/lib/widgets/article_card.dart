import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:client/models/ArticlesModel.dart';
import 'package:client/providers/likedArticleProvider.dart';
import 'package:client/screens/ArticleDetailScreen.dart';
import 'package:client/widgets/theme.dart';

void openArticle(BuildContext context, Article article) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)));
}

/// Network image with a neutral placeholder. Falls back to an <img> element on web
/// when the image host doesn't send CORS headers.
class NewsImage extends StatelessWidget {
  final String url;
  final double? height;
  final double? width;
  final BorderRadius radius;

  const NewsImage(this.url, {super.key, this.height, this.width, this.radius = BorderRadius.zero});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: height,
      width: width,
      color: context.colors.outlineVariant.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: context.muted, size: 28),
    );
    return ClipRRect(
      borderRadius: radius,
      child: url.isEmpty
          ? placeholder
          : Image.network(
              url,
              height: height,
              width: width,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              semanticLabel: 'Article image',
              errorBuilder: (_, __, ___) => placeholder,
              frameBuilder: (context, child, frame, sync) => sync || frame != null
                  ? child
                  : SizedBox(height: height, width: width, child: placeholder),
            ),
    );
  }
}

class LikeButton extends StatelessWidget {
  final Article article;
  const LikeButton({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final liked = context.select<LikedArticlesProvider, bool>((p) => p.isLiked(article.title));
    return IconButton(
      tooltip: liked ? 'Unlike' : 'Like',
      onPressed: () async {
        final error = await context.read<LikedArticlesProvider>().toggle(article);
        if (error != null && context.mounted) showMessage(context, error, error: true);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(liked),
          color: liked ? AppColors.like : context.muted,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final Article article;
  const _Meta(this.article);

  @override
  Widget build(BuildContext context) {
    return Text(
      [article.sourceName, if (article.timeAgo.isNotEmpty) article.timeAgo].join('  ·  '),
      style: context.text.labelSmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Large card for the top story.
class LeadArticleCard extends StatelessWidget {
  final Article article;
  const LeadArticleCard({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openArticle(context, article),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: NewsImage(article.urlToImage)),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.sm, Space.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.reason != null) ...[
                    _ReasonTag(article.reason!),
                    const SizedBox(height: Space.sm),
                  ],
                  Text(article.title, style: context.text.titleLarge, maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (article.description.isNotEmpty) ...[
                    const SizedBox(height: Space.sm),
                    Text(article.description, style: context.text.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  Row(children: [Expanded(child: _Meta(article)), LikeButton(article: article)]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact row: text on the left, thumbnail on the right.
class ArticleTile extends StatelessWidget {
  final Article article;
  const ArticleTile({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openArticle(context, article),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.reason != null) ...[
                _ReasonTag(article.reason!),
                const SizedBox(height: Space.sm),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(article.title,
                        style: context.text.titleSmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: Space.md),
                  NewsImage(article.urlToImage, width: 92, height: 92, radius: BorderRadius.circular(10)),
                ],
              ),
              Row(children: [Expanded(child: _Meta(article)), LikeButton(article: article)]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonTag extends StatelessWidget {
  final String reason;
  const _ReasonTag(this.reason);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.auto_awesome_rounded, size: 14, color: context.aiColor),
      const SizedBox(width: Space.xs),
      Expanded(
        child: Text(reason,
            style: context.text.labelSmall?.copyWith(color: context.aiColor, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

/// Skeleton placeholders shown while a list loads.
class ArticleListSkeleton extends StatelessWidget {
  final int count;
  const ArticleListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    final base = context.colors.outlineVariant;
    Widget bar(double w, double h) => Container(
          width: w, height: h,
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
        );
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: context.colors.surface,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Space.md),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: Space.md),
        itemBuilder: (_, i) => i == 0
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AspectRatio(aspectRatio: 16 / 9, child: bar(double.infinity, 0)),
                const SizedBox(height: Space.md),
                bar(double.infinity, 18),
                const SizedBox(height: Space.sm),
                bar(220, 18),
              ])
            : Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    bar(double.infinity, 14), const SizedBox(height: Space.sm),
                    bar(double.infinity, 14), const SizedBox(height: Space.sm),
                    bar(120, 12),
                  ]),
                ),
                const SizedBox(width: Space.md),
                bar(92, 92),
              ]),
      ),
    );
  }
}

/// Empty / error state with an optional action.
class StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(color: context.colors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: context.colors.primary),
          ),
          const SizedBox(height: Space.md),
          Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: Space.sm),
            Text(message!, style: context.text.bodyMedium, textAlign: TextAlign.center),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.lg),
            FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ]),
      ),
    );
  }
}

/// Lead card followed by compact tiles, with pull-to-refresh.
class ArticleFeed extends StatelessWidget {
  final List<Article> articles;
  final Future<void> Function() onRefresh;
  final Widget? header;

  const ArticleFeed({super.key, required this.articles, required this.onRefresh, this.header});

  @override
  Widget build(BuildContext context) {
    final offset = header == null ? 0 : 1;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
        itemCount: articles.length + offset,
        separatorBuilder: (_, __) => const SizedBox(height: Space.md),
        itemBuilder: (_, i) {
          if (header != null && i == 0) return header!;
          final a = articles[i - offset];
          return i - offset == 0 ? LeadArticleCard(article: a) : ArticleTile(article: a);
        },
      ),
    );
  }
}
