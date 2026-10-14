import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:client/providers/likedArticleProvider.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/theme.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  Map<String, dynamic>? _user;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<LikedArticlesProvider>();
    await provider.ensureInitialized();
    final email = provider.userEmail;
    if (email == null) return;
    try {
      final user = await Api.userDetails(email);
      if (!mounted) return;
      setState(() {
        _user = user;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign back in any time. Your likes are saved to your account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<LikedArticlesProvider>().endSession();
    if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('login/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LikedArticlesProvider>();
    final name = (_user?['username'] ?? '').toString();
    final email = (_user?['email'] ?? provider.userEmail ?? '').toString();
    final liked = provider.liked.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_load(), provider.refreshLikes()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.md),
                child: Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: context.colors.primary,
                    child: Text(
                      (name.isNotEmpty ? name : email).characters.firstOrNull?.toUpperCase() ?? '?',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.colors.onPrimary),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name.isNotEmpty ? name : (_error == null ? 'Loading...' : 'Reader'),
                          style: context.text.titleLarge, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(email, style: context.text.bodyMedium, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: Space.md),
            Card(
              child: Column(children: [
                _infoTile(Icons.phone_outlined, 'Phone', (_user?['phone'] ?? '—').toString()),
                const Divider(indent: 56),
                _infoTile(Icons.favorite_outline_rounded, 'Liked articles', '${provider.likedCount}'),
              ]),
            ),
            if (_error != null) ...[
              const SizedBox(height: Space.sm),
              Text(_error!, style: TextStyle(color: context.colors.error)),
            ],
            const SizedBox(height: Space.lg),
            Text('Your likes', style: context.text.titleMedium),
            const SizedBox(height: Space.xs),
            Text('These shape your For You picks.', style: context.text.bodyMedium),
            const SizedBox(height: Space.sm),
            if (liked.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Text('No likes yet. Tap the heart on any story.', style: context.text.bodyMedium),
                ),
              )
            else
              Card(
                child: Column(children: [
                  for (var i = 0; i < liked.length; i++) ...[
                    if (i > 0) const Divider(indent: Space.md),
                    ListTile(
                      title: Text(liked[i].title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                      subtitle: Text(liked[i].category, style: context.text.labelSmall),
                      trailing: IconButton(
                        tooltip: 'Remove like',
                        icon: const Icon(Icons.favorite_rounded, color: AppColors.like),
                        onPressed: () async {
                          final err = await provider.unlikeTitle(liked[i].title);
                          if (err != null && context.mounted) showMessage(context, err, error: true);
                        },
                      ),
                    ),
                  ],
                ]),
              ),
            const SizedBox(height: Space.lg),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: context.colors.error),
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) => ListTile(
        leading: Icon(icon, color: context.colors.primary),
        title: Text(label, style: context.text.labelMedium),
        subtitle: Text(value, style: context.text.titleSmall),
      );
}
