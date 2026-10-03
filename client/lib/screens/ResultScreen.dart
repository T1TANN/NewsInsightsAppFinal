import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/credibility_card.dart';
import 'package:client/widgets/summary_card.dart';
import 'package:client/widgets/theme.dart';

/// Shows scanned or pasted text, summarizes it with AI straight away and offers a fake news check.
class ResultScreen extends StatelessWidget {
  final String scanText;

  const ResultScreen({super.key, required this.scanText});

  @override
  Widget build(BuildContext context) {
    final text = scanText.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: [
          IconButton(
            tooltip: 'Copy original text',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              showMessage(context, 'Original text copied');
            },
          ),
          const SizedBox(width: Space.xs),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
            children: [
              if (text.isEmpty)
                Text('No text was detected. Try again with better lighting.', style: context.text.bodyMedium)
              else ...[
                SummaryPanel(autoStart: true, load: () => Api.summarize(text: text)),
                const SizedBox(height: Space.md),
                CredibilityPanel(load: () => Api.verify(text: text)),
                const SizedBox(height: Space.lg),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Card(
                    child: ExpansionTile(
                      title: Text('Original text', style: context.text.titleSmall),
                      subtitle: Text('${text.split(RegExp(r'\s+')).length} words', style: context.text.labelSmall),
                      childrenPadding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
                      children: [SelectableText(text, style: context.text.bodyLarge)],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
