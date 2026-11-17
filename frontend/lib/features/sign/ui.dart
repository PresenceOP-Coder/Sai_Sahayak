import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

class SignToSpeechScreen extends StatefulWidget {
  const SignToSpeechScreen({super.key});

  @override
  State<SignToSpeechScreen> createState() => _SignToSpeechScreenState();
}

class _SignToSpeechScreenState extends State<SignToSpeechScreen> {
  final FlutterTts _tts = FlutterTts();
  final ValueNotifier<String> _phraseNotifier = ValueNotifier("Waiting for sign...");
  final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);

  String? _lastSpoken;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  Future<void> _initScreen() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    // Do not block the UI thread while speaking
    await _tts.awaitSpeakCompletion(false);

    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
      });
    }
  }

  void _handleSignFromJS(String phrase, bool shouldSpeak, double progress) {
    if (!mounted) return;

    _phraseNotifier.value = phrase.isEmpty ? "Waiting for sign..." : phrase;
    _progressNotifier.value = progress;

    if (shouldSpeak && phrase.isNotEmpty && phrase != _lastSpoken) {
      _lastSpoken = phrase;
      _tts.speak(phrase);
    } else if (phrase.isEmpty) {
      _lastSpoken = null;
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _phraseNotifier.dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Sign to Speech"),
        backgroundColor: const Color(0xFF1E293B),
      ),
      body: !_hasPermission
          ? Center(
        child: ElevatedButton(
          onPressed: _initScreen,
          child: const Text("Grant Camera Permission"),
        ),
      )
          : Column(
        children: [
          // 1. Camera + MediaPipe Skeleton Viewport (Never rebuilt by ValueNotifiers)
          SizedBox(
            height: 380,
            width: double.infinity,
            child: InAppWebView(
              initialFile: "assets/index.html",
              initialSettings: InAppWebViewSettings(
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                useHybridComposition: true,
              ),
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT,
                );
              },
              onWebViewCreated: (controller) {
                controller.addJavaScriptHandler(
                  handlerName: 'onSignDetected',
                  callback: (args) {
                    final String phrase = args.isNotEmpty ? args[0].toString() : "";
                    final bool triggerSpeak = args.length > 1 ? (args[1] == true) : false;
                    final double progress = args.length > 2 ? (args[2] as num).toDouble() : 0.0;
                    _handleSignFromJS(phrase, triggerSpeak, progress);
                  },
                );
              },
            ),
          ),

          // 2. Hold Progress Indicator (Rebuilds independently)
          ValueListenableBuilder<double>(
            valueListenable: _progressNotifier,
            builder: (context, progress, _) {
              return LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
              );
            },
          ),

          // 3. Native Flutter Output & Controls (Rebuilds independently)
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: const Color(0xFF1E293B),
              child: ValueListenableBuilder<String>(
                valueListenable: _phraseNotifier,
                builder: (context, currentPhrase, _) {
                  final isWaiting = currentPhrase == "Waiting for sign...";
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "RECOGNIZED PHRASE",
                        style: TextStyle(
                          color: Colors.grey,
                          letterSpacing: 1.5,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentPhrase,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isWaiting ? Colors.white54 : const Color(0xFF4ADE80),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: isWaiting ? null : () => _tts.speak(currentPhrase),
                        icon: const Icon(Icons.volume_up),
                        label: const Text("Speak Again"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}