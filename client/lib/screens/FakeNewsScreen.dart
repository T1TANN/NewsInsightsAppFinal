import 'package:flutter/material.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/credibility_card.dart';
import 'package:client/widgets/theme.dart';

/// Dedicated Machine Learning Fake News Detector Screen.
/// Powered by PassiveAggressiveClassifier & TF-IDF vectorizer trained on the 200,000 Indian News Dataset.
class FakeNewsScreen extends StatefulWidget {
  const FakeNewsScreen({super.key});

  @override
  State<FakeNewsScreen> createState() => _FakeNewsScreenState();
}

class _FakeNewsScreenState extends State<FakeNewsScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _activeText;
  int _runCounter = 0;

  static const List<Map<String, String>> _samples = [
    {
      'title': '🚨 Viral RBI Hoax',
      'type': 'fake',
      'text':
          'Breaking: RBI to replace all currency notes with digital-only coins by tonight. A shocking viral post circulating across multiple social media networks claims that cash will be banned by midnight. Local residents are advised to share this before it gets deleted!',
    },
    {
      'title': '🚨 Cancer Cure Hoax',
      'type': 'fake',
      'text':
          'BREAKING!!! Government CONFIRMS that drinking hot water with lemon every morning CURES cancer in 3 days. Doctors are SHOCKED and big pharma is trying to hide this. Share this with everyone before it gets deleted immediately!!!',
    },
    {
      'title': '🛡️ ISRO Satellite (Real)',
      'type': 'real',
      'text':
          'ISRO successfully launches new earth observation satellite from Sriharikota according to official reports published today by the space agency. Senior officials verified that telemetry and solar panel deployment were achieved according to schedule.',
    },
    {
      'title': '🛡️ BCCI Domestic (Real)',
      'type': 'real',
      'text':
          'BCCI announces updated schedule for domestic cricket matches across Bengaluru and Mumbai, according to official circulars published by state cricket associations and tournament organizers.',
    },
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerVerify(String text) {
    final clean = text.trim();
    if (clean.split(RegExp(r'\s+')).length < 5) {
      showMessage(context, 'Please enter at least a complete headline or sentence.', error: true);
      return;
    }
    setState(() {
      _activeText = clean;
      _runCounter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final words = _controller.text.trim().isEmpty ? 0 : _controller.text.trim().split(RegExp(r'\s+')).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.fact_check_rounded, color: context.colors.primary, size: 20),
            ),
            const SizedBox(width: Space.sm),
            const Text('Fake News Detector'),
            const SizedBox(width: Space.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
              ),
              child: const Text('ML Model', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
        children: [
          _buildInputCard(words),
          const SizedBox(height: Space.lg),
          _buildResultView(),
        ],
      ),
    );
  }

  Widget _buildInputCard(int words) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Check Credibility & Authenticity', style: context.text.titleMedium),
                      const SizedBox(height: Space.xs),
                      Text(
                        'Classifies whether a news headline, WhatsApp message, or article is real or fake using Machine Learning.',
                        style: context.text.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Container(
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.memory_rounded, size: 16, color: context.colors.primary),
                  const SizedBox(width: Space.xs),
                  Expanded(
                    child: Text(
                      'Trained on 200,000 Indian News records (Passive-Aggressive + TF-IDF)',
                      style: context.text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            // Sample test buttons
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Test Samples:', style: context.text.labelSmall),
                for (final s in _samples)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: s['type'] == 'fake'
                        ? Colors.red.withValues(alpha: 0.08)
                        : Colors.green.withValues(alpha: 0.08),
                    side: BorderSide(
                      color: s['type'] == 'fake'
                          ? Colors.red.withValues(alpha: 0.3)
                          : Colors.green.withValues(alpha: 0.3),
                    ),
                    label: Text(s['title']!, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      _controller.text = s['text']!;
                      setState(() {});
                      _triggerVerify(s['text']!);
                    },
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _controller,
              minLines: 8,
              maxLines: 15,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Paste any news headline, forward, social post, or article here to analyze...',
                alignLabelWithHint: true,
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() {
                          _controller.clear();
                          _activeText = null;
                        }),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: Space.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  words < 5 ? '$words words · at least 5 needed' : '$words words',
                  style: context.text.labelSmall?.copyWith(
                    color: words >= 5 ? context.colors.primary : null,
                  ),
                ),
                FilledButton.icon(
                  onPressed: words < 5 ? null : () => _triggerVerify(_controller.text),
                  icon: const Icon(Icons.fact_check_rounded, size: 18),
                  label: const Text('Classify News Credibility'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    if (_activeText == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(Space.lg),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.gpp_maybe_rounded, size: 48, color: context.colors.primary),
              ),
              const SizedBox(height: Space.md),
              Text('Instant Machine Learning Verification', style: context.text.titleMedium),
              const SizedBox(height: Space.sm),
              Text(
                'Paste text on the left or click a test sample above to analyze authenticity. The pre-trained model evaluates n-gram vocabulary features, linguistic patterns, and cross-checks the 200k news database.',
                style: context.text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CredibilityPanel(
          key: ValueKey('verify-$_runCounter'),
          load: () => Api.verify(text: _activeText!),
        ),
      ],
    );
  }
}
