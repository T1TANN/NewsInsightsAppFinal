import 'package:flutter/material.dart';
import 'package:client/widgets/theme.dart';

class CommonLogo extends StatelessWidget {
  final double size;
  const CommonLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.colors.primary,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(Icons.article_rounded, size: size * 0.55, color: context.colors.onPrimary),
      ),
      const SizedBox(width: Space.md),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('NewsInsights', style: context.text.headlineSmall, overflow: TextOverflow.ellipsis),
          Text('News, summarized and personalized', style: context.text.labelMedium, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }
}

/// Centered, width-capped layout shared by the sign-in and sign-up screens.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.centerLeft, child: CommonLogo()),
                    const SizedBox(height: Space.xl),
                    Text(title, style: context.text.headlineMedium),
                    const SizedBox(height: Space.xs),
                    Text(subtitle, style: context.text.bodyMedium),
                    const SizedBox(height: Space.lg),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoadingButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback onPressed;

  const LoadingButton({super.key, required this.loading, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: context.colors.onSurfaceVariant),
            )
          : Text(label),
    );
  }
}
