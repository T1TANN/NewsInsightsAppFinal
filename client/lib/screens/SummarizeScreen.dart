import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:client/services/api_client.dart';
import 'package:client/widgets/summary_card.dart';
import 'package:client/widgets/theme.dart';

/// Dedicated AI News Summarizer Screen.
/// Provides instant executive summaries, bullet takeaways, and reading time metrics.
class SummarizeScreen extends StatefulWidget {
  const SummarizeScreen({super.key});

  @override
  State<SummarizeScreen> createState() => _SummarizeScreenState();
}

class _SummarizeScreenState extends State<SummarizeScreen> {
  final TextRecognizer? _recognizer = kIsWeb ? null : TextRecognizer();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _controller = TextEditingController();
  bool _scanning = false;
  String? _activeText;
  int _runCounter = 0;

  static const List<Map<String, String>> _samples = [
    {
      'title': 'ISRO Mission',
      'text':
          'The Indian Space Research Organisation has successfully placed another high-power communications satellite into geostationary transfer orbit today from Sriharikota. The mission achieved all primary objectives, deploying solar panels and establishing bidirectional telemetry. Officials confirmed the satellite will expand national broadband coverage across remote districts and upgrade maritime defence communications.',
    },
    {
      'title': 'Renewable Energy',
      'text':
          'India announced a landmark milestone in renewable energy capacity today, surpassing 180 gigawatts of non-fossil power generation ahead of the scheduled target. Solar park expansions in Rajasthan and Gujarat led the quarterly surge, supported by modern battery storage installations that stabilize grid distribution during peak commercial demand hours.',
    },
    {
      'title': 'Digital Economy',
      'text':
          'The Reserve Bank of India and partner commercial institutions reported a new record in monthly digital retail transactions, exceeding 15 billion payments. The report highlighted rapid penetration across tier-2 and tier-3 cities, crediting simplified QR infrastructure and sound-box terminals for accelerating financial inclusion among small merchants.',
    },
  ];

  @override
  void dispose() {
    _recognizer?.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      showMessage(context, 'Camera permission is needed to scan text.', error: true);
      if (status.isPermanentlyDenied) await openAppSettings();
      return;
    }
    setState(() => _scanning = true);
    try {
      final image = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear);
      if (image == null) return;
      final result = await _recognizer!.processImage(InputImage.fromFilePath(image.path));
      if (!mounted) return;
      _controller.text = result.text;
      _triggerSummarize(result.text);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not scan the image. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _triggerSummarize(String text) {
    final clean = text.trim();
    if (clean.split(RegExp(r'\s+')).length < 25) {
      showMessage(context, 'Please enter at least 25 words to summarize.', error: true);
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
                color: context.aiColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: context.aiColor, size: 20),
            ),
            const SizedBox(width: Space.sm),
            const Text('AI News Summarizer'),
          ],
        ),
        actions: [
          if (!kIsWeb)
            IconButton(
              tooltip: 'Scan text with camera',
              icon: Icon(_scanning ? Icons.hourglass_top_rounded : Icons.camera_alt_outlined),
              onPressed: _scanning ? null : _scan,
            ),
          const SizedBox(width: Space.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
        children: [
          _buildInputCard(words),
          const SizedBox(height: Space.lg),
          _buildResultView(words),
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
            Text('Input News Article or Text', style: context.text.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              'Paste any news article, editorial, or transcript to get an instant executive summary.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: Space.md),
            // Sample buttons
            Wrap(
              spacing: Space.xs,
              runSpacing: Space.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Sample Stories:', style: context.text.labelSmall),
                for (final s in _samples)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(s['title']!, style: const TextStyle(fontSize: 12)),
                    onPressed: () {
                      _controller.text = s['text']!;
                      setState(() {});
                      _triggerSummarize(s['text']!);
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
                hintText: 'Paste news text here (minimum 25 words)...',
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
                  words < 25 ? '$words words · at least 25 needed' : '$words words',
                  style: context.text.labelSmall?.copyWith(
                    color: words >= 25 ? context.colors.primary : null,
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.aiColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: words < 25 ? null : () => _triggerSummarize(_controller.text),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Summarize with AI'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(int words) {
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
                  color: context.aiColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.short_text_rounded, size: 48, color: context.aiColor),
              ),
              const SizedBox(height: Space.md),
              Text('Instant Executive Summaries', style: context.text.titleMedium),
              const SizedBox(height: Space.sm),
              Text(
                'Enter an article on the left or click a sample story above to generate concise summaries, bullet key takeaways, and reading time metrics.',
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
        SummaryPanel(
          key: ValueKey('summary-$_runCounter'),
          autoStart: true,
          load: () => Api.summarize(text: _activeText!),
        ),
      ],
    );
  }
}
