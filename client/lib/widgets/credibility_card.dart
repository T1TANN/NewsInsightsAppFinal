import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/theme.dart';

/// Visual style for each verdict. Every verdict pairs colour with an icon and a
/// text label, so meaning never relies on colour alone.
class _VerdictStyle {
  final Color color;
  final IconData icon;
  const _VerdictStyle(this.color, this.icon);

  static _VerdictStyle of(BuildContext context, String verdict) {
    final dark = context.isDark;
    switch (verdict) {
      case 'likely_real':
        return _VerdictStyle(dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D), Icons.verified_rounded);
      case 'misleading':
        return _VerdictStyle(dark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C), Icons.warning_amber_rounded);
      case 'likely_fake':
        return _VerdictStyle(dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C), Icons.gpp_bad_rounded);
      default:
        return _VerdictStyle(dark ? const Color(0xFFFCD34D) : const Color(0xFFA16207), Icons.help_outline_rounded);
    }
  }
}

/// "Is this real?" panel: idle button -> loading -> verdict with evidence.
class CredibilityPanel extends StatefulWidget {
  final Future<Verification> Function() load;
  const CredibilityPanel({super.key, required this.load});

  @override
  State<CredibilityPanel> createState() => _CredibilityPanelState();
}

class _CredibilityPanelState extends State<CredibilityPanel> {
  Verification? _result;
  String? _error;
  bool _loading = false;

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.load();
      if (mounted) setState(() => _result = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final accent = r == null ? context.colors.primary : _VerdictStyle.of(context, r.verdict).color;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: r == null ? context.colors.outlineVariant : accent.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(Space.md),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.fact_check_outlined, color: context.colors.primary, size: 20),
            const SizedBox(width: Space.sm),
            Expanded(child: Text('Fake news check', style: context.text.titleSmall?.copyWith(color: context.colors.primary))),
            if (r != null)
              IconButton(tooltip: 'Check again', onPressed: _loading ? null : _run, icon: Icon(Icons.refresh_rounded, color: context.muted)),
          ]),
          const SizedBox(height: Space.sm),
          if (_loading)
            _skeleton(context)
          else if (r != null)
            _resultView(context, r)
          else ...[
            Text(
              _error ??
                  'AI predicts whether this story is real, misleading or fake by checking its claims, '
                      'its language and how other outlets cover it.',
              style: context.text.bodyMedium?.copyWith(color: _error != null ? context.colors.error : null),
            ),
            const SizedBox(height: Space.md),
            OutlinedButton.icon(
              onPressed: _run,
              icon: Icon(_error != null ? Icons.refresh_rounded : Icons.fact_check_outlined),
              label: Text(_error != null ? 'Try again' : 'Check if this is real'),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    final base = context.colors.outlineVariant;
    Widget bar(double? w, double h) => Container(
          margin: const EdgeInsets.only(bottom: Space.sm),
          width: w, height: h,
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
        );
    return Semantics(
      label: 'Checking credibility',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Extracting claims and searching other outlets...', style: context.text.labelMedium),
        const SizedBox(height: Space.md),
        Shimmer.fromColors(
          baseColor: base,
          highlightColor: context.colors.surface,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [bar(64, 64), const SizedBox(width: Space.md), Expanded(child: bar(null, 20))]),
            bar(double.infinity, 14), bar(double.infinity, 14), bar(220, 14),
          ]),
        ),
      ]),
    );
  }

  Widget _resultView(BuildContext context, Verification r) {
    final style = _VerdictStyle.of(context, r.verdict);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _ScoreGauge(score: r.score, color: style.color),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(style.icon, color: style.color, size: 22),
              const SizedBox(width: Space.xs),
              Flexible(child: Text(r.label, style: context.text.titleLarge?.copyWith(color: style.color))),
            ]),
            const SizedBox(height: 2),
            Text('Credibility ${r.score}/100  ·  ${r.confidence} confidence', style: context.text.labelMedium),
          ]),
        ),
      ]),
      const SizedBox(height: Space.md),
      Text(r.summary, style: context.text.bodyLarge),
      if (r.signals.isNotEmpty) ...[
        const SizedBox(height: Space.md),
        Text('What we looked at', style: context.text.labelMedium),
        const SizedBox(height: Space.sm),
        ...r.signals.map((s) => _SignalRow(s)),
      ],
      if (r.claims.isNotEmpty) ...[
        const SizedBox(height: Space.sm),
        Text('Key claims', style: context.text.labelMedium),
        const SizedBox(height: Space.sm),
        ...r.claims.map((c) => _ClaimRow(c)),
      ],
      if (r.coverage.isNotEmpty) ...[
        const SizedBox(height: Space.sm),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: Text('Coverage by other outlets', style: context.text.labelMedium),
            subtitle: Text(
              '${r.coverage.where((c) => c.supports).length} of ${r.coverage.length} report the same story',
              style: context.text.labelSmall,
            ),
            children: r.coverage.map((c) => _CoverageRow(c)).toList(),
          ),
        ),
      ],
      const SizedBox(height: Space.sm),
      Text(
        'AI prediction, not a definitive fact-check. Verify important claims with trusted sources.',
        style: context.text.labelSmall,
      ),
    ]);
  }
}

class _ScoreGauge extends StatelessWidget {
  final int score;
  final Color color;
  const _ScoreGauge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Credibility score $score out of 100',
      child: SizedBox(
        width: 64,
        height: 64,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: score / 100),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
            Text('${(v * 100).round()}', style: context.text.titleMedium?.copyWith(color: color)),
          ]),
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final Signal s;
  const _SignalRow(this.s);

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String word) = switch (s.impact) {
      'positive' => (Icons.add_circle_outline_rounded, _VerdictStyle.of(context, 'likely_real').color, 'Raises credibility'),
      'negative' => (Icons.remove_circle_outline_rounded, _VerdictStyle.of(context, 'likely_fake').color, 'Lowers credibility'),
      _ => (Icons.radio_button_unchecked_rounded, context.muted, 'Neutral'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Tooltip(message: word, child: Icon(icon, size: 20, color: color, semanticLabel: word)),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(
                text: '${s.label.isEmpty ? '' : s.label[0].toUpperCase() + s.label.substring(1)}. ',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: s.detail),
          ]), style: context.text.bodyMedium?.copyWith(color: context.colors.onSurface)),
        ),
      ]),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  final CheckedClaim c;
  const _ClaimRow(this.c);

  @override
  Widget build(BuildContext context) {
    final (String label, String verdict) = switch (c.status) {
      'supported' => ('Supported', 'likely_real'),
      'contradicted' => ('Contradicted', 'likely_fake'),
      'unsupported' => ('Unsupported', 'misleading'),
      _ => ('Unverifiable', 'unverified'),
    };
    final color = _VerdictStyle.of(context, verdict).color;
    return Container(
      margin: const EdgeInsets.only(bottom: Space.sm),
      padding: const EdgeInsets.all(Space.sm + 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: context.text.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: Space.xs + 2),
        Text(c.claim, style: context.text.titleSmall),
        if (c.note.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(c.note, style: context.text.bodyMedium),
        ],
      ]),
    );
  }
}

class _CoverageRow extends StatelessWidget {
  final Coverage c;
  const _CoverageRow(this.c);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        c.supports ? Icons.check_circle_outline_rounded : Icons.article_outlined,
        color: c.supports ? _VerdictStyle.of(context, 'likely_real').color : context.muted,
        semanticLabel: c.supports ? 'Reports the same story' : 'Related report',
      ),
      title: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurface)),
      subtitle: Text(c.source, style: context.text.labelSmall),
      trailing: Icon(Icons.open_in_new_rounded, size: 18, color: context.muted),
      onTap: () {
        final uri = Uri.tryParse(c.url);
        if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }
}
