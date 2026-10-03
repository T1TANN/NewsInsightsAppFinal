import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/theme.dart';

/// "Summarize with AI" panel: idle button -> loading skeleton -> summary with key points.
class SummaryPanel extends StatefulWidget {
  final Future<Summary> Function() load;
  final bool autoStart;

  const SummaryPanel({super.key, required this.load, this.autoStart = false});

  @override
  State<SummaryPanel> createState() => _SummaryPanelState();
}

class _SummaryPanelState extends State<SummaryPanel> {
  Summary? _summary;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) _run();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await widget.load();
      if (!mounted) return;
      setState(() => _summary = s);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.aiColor;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ai.withValues(alpha: context.isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ai.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(Space.md),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome_rounded, color: ai, size: 20),
              const SizedBox(width: Space.sm),
              Expanded(child: Text('AI Summary', style: context.text.titleSmall?.copyWith(color: ai))),
              if (_summary != null)
                IconButton(
                  tooltip: 'Copy summary',
                  icon: Icon(Icons.copy_rounded, size: 20, color: context.muted),
                  onPressed: () {
                    final s = _summary!;
                    Clipboard.setData(ClipboardData(text: '${s.text}\n\n${s.keyPoints.map((p) => '• $p').join('\n')}'));
                    showMessage(context, 'Summary copied');
                  },
                ),
            ]),
            const SizedBox(height: Space.sm),
            if (_loading) _skeleton(context)
            else if (_summary != null) _result(context, _summary!)
            else ...[
              Text(
                _error ?? 'Get the key facts in seconds. The summary sticks to what the article says.',
                style: context.text.bodyMedium?.copyWith(color: _error != null ? context.colors.error : null),
              ),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: ai, foregroundColor: context.isDark ? Colors.black : Colors.white),
                onPressed: _run,
                icon: Icon(_error != null ? Icons.refresh_rounded : Icons.auto_awesome_rounded),
                label: Text(_error != null ? 'Try again' : 'Summarize with AI'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    final base = context.aiColor.withValues(alpha: 0.18);
    Widget bar(double? w) => Container(
          margin: const EdgeInsets.only(bottom: Space.sm),
          width: w, height: 14,
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(6)),
        );
    return Semantics(
      label: 'Generating summary',
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: context.colors.surface,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          bar(double.infinity), bar(double.infinity), bar(240), const SizedBox(height: Space.sm), bar(200), bar(260),
        ]),
      ),
    );
  }

  Widget _result(BuildContext context, Summary s) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.text, style: context.text.bodyLarge),
      if (s.keyPoints.isNotEmpty) ...[
        const SizedBox(height: Space.md),
        Text('Key points', style: context.text.labelMedium),
        const SizedBox(height: Space.sm),
        ...s.keyPoints.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(width: 6, height: 6, decoration: BoxDecoration(color: context.aiColor, shape: BoxShape.circle)),
                ),
                const SizedBox(width: Space.sm + 2),
                Expanded(child: Text(p, style: context.text.bodyLarge?.copyWith(height: 1.5))),
              ]),
            )),
      ],
      if (s.source == 'snippet') ...[
        const SizedBox(height: Space.xs),
        Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: context.muted),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Text('The full article could not be loaded, so this is based on the preview only.',
                style: context.text.labelSmall),
          ),
        ]),
      ],
    ]);
  }
}
