import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:client/screens/ResultScreen.dart';
import 'package:client/widgets/theme.dart';

/// Scan printed text with the camera (Android/iOS), or paste text (any platform),
/// then summarize it and check whether it's fake news with AI.
class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  // ML Kit has no web implementation, so only create the recognizer on mobile.
  final TextRecognizer? _recognizer = kIsWeb ? null : TextRecognizer();
  final ImagePicker _picker = ImagePicker();
  final _paste = TextEditingController();
  bool _scanning = false;

  @override
  void dispose() {
    _recognizer?.close();
    _paste.dispose();
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
      _openResult(result.text);
    } catch (e) {
      if (mounted) showMessage(context, 'Could not scan the image. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _openResult(String text) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(scanText: text)));
  }

  @override
  Widget build(BuildContext context) {
    final words = _paste.text.trim().isEmpty ? 0 : _paste.text.trim().split(RegExp(r'\s+')).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan & Verify')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.xl),
            children: [
              if (!kIsWeb) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.lg),
                    child: Column(children: [
                      Icon(Icons.document_scanner_outlined, size: 48, color: context.colors.primary),
                      const SizedBox(height: Space.md),
                      Text('Scan a newspaper or document', style: context.text.titleMedium, textAlign: TextAlign.center),
                      const SizedBox(height: Space.xs),
                      Text('Point your camera at printed text. AI summarizes it and checks if it is real.',
                          style: context.text.bodyMedium, textAlign: TextAlign.center),
                      const SizedBox(height: Space.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _scanning ? null : _scan,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(_scanning ? 'Reading text...' : 'Open camera'),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: Space.lg),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.md),
                    child: Text('or paste text', style: context.text.labelMedium),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: Space.lg),
              ] else ...[
                Text('Paste any article, forward or social media post to summarize it and check if it is fake.', style: context.text.bodyMedium),
                const SizedBox(height: Space.xs),
                Text('Camera scanning is available in the Android and iOS apps.', style: context.text.labelSmall),
                const SizedBox(height: Space.md),
              ],
              TextField(
                controller: _paste,
                minLines: 8,
                maxLines: 16,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Text to check',
                  alignLabelWithHint: true,
                  hintText: 'Paste a news article, WhatsApp forward or post here...',
                ),
              ),
              const SizedBox(height: Space.sm),
              Text(words < 25 ? '$words words · at least 25 needed' : '$words words',
                  style: context.text.labelSmall),
              const SizedBox(height: Space.md),
              FilledButton.icon(
                onPressed: words < 25 ? null : () => _openResult(_paste.text.trim()),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Summarize & check'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
