
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

class BlindPathNavigatorScreen extends StatefulWidget {
  const BlindPathNavigatorScreen({super.key});

  @override
  State<BlindPathNavigatorScreen> createState() =>
      _BlindPathNavigatorScreenState();
}

class _BlindPathNavigatorScreenState
    extends State<BlindPathNavigatorScreen> {

  final FlutterTts _flutterTts = FlutterTts();
  InAppWebViewController? _navigatorWebViewController;
  bool _useFrontCamera = false;

  final InAppLocalhostServer _localhostServer =
  InAppLocalhostServer(
    documentRoot: 'assets',
  );

  bool isReady = false;
  bool isTtsReady = false;

  String status = 'Preparing navigator...';
  String? error;

  @override
  void initState() {
    super.initState();
    initializeScreen();
  }

  // ---------------- TTS INITIALIZATION ----------------

  Future<void> initializeTts() async {
    try {
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      isTtsReady = true;
      debugPrint('Flutter TTS initialized');
      if (mounted) setState(() {});
    } catch (e) {
      isTtsReady = false;
      debugPrint('TTS initialization error: $e');
    }
  }

  // ---------------- SPEAK DETECTIONS ----------------

  Future<void> speakDetection(String message) async {
    if (!isTtsReady || message.trim().isEmpty) {
      return;
    }

    try {
      // Prevent overlapping announcements.
      await _flutterTts.stop();

      await _flutterTts.speak(message);

      debugPrint('Flutter TTS speaking: $message');
    } catch (e) {
      debugPrint('TTS speech error: $e');
    }
  }

  Future<void> stopSpeech() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('TTS stop error: $e');
    }
  }

  // ---------------- SCREEN INITIALIZATION ----------------

  Future<void> initializeScreen() async {
    try {
      setState(() {
        status = 'Requesting camera permission...';
        error = null;
      });

      final permission = await Permission.camera.request();

      if (!permission.isGranted) {
        throw Exception('Camera permission denied');
      }

      setState(() {
        status = 'Initializing voice engine...';
      });

      await initializeTts();

      setState(() {
        status = 'Starting local server...';
      });

      if (!_localhostServer.isRunning()) {
        await _localhostServer.start();
      }

      if (!mounted) return;

      setState(() {
        isReady = true;
        status = 'Navigator ready';
      });

    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        status = 'Initialization failed';
      });
    }
  }

  // ---------------- JAVASCRIPT BRIDGE ----------------

  void setupJavascriptHandlers(
      InAppWebViewController controller) {

    // HTML sends detected object announcements here.
    controller.addJavaScriptHandler(
      handlerName: 'speakDetection',
      callback: (args) async {
        if (args.isNotEmpty) {
          final message = args[0].toString();
          await speakDetection(message);
        }

        return true;
      },
    );

    // HTML sends stop requests here.
    controller.addJavaScriptHandler(
      handlerName: 'stopSpeech',
      callback: (args) async {
        await stopSpeech();
        return true;
      },
    );
  }

  // ---------------- DISPOSE ----------------

  @override
  void dispose() {
    unawaited(stopSpeech());
    unawaited(_localhostServer.close());
    super.dispose();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),

      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2158),
        foregroundColor: Colors.white,

        title: const Text(
          'Sahayak Navigator',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip: _useFrontCamera ? 'Switch to back camera' : 'Switch to front camera',
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () async {
              setState(() => _useFrontCamera = !_useFrontCamera);
              await _navigatorWebViewController?.evaluateJavascript(
                source: 'switchCamera(${_useFrontCamera ? '"user"' : '"environment"'})',
              );
            },
          ),
          // Test Flutter TTS directly.
          IconButton(
            tooltip: 'Test voice',
            onPressed: isTtsReady
                ? () => speakDetection(
              'Blind Path Navigator is ready.',
            )
                : null,
            icon: Icon(
              Icons.volume_up,
              color: isTtsReady
                  ? Colors.green
                  : Colors.white38,
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 9,
                    color: isReady
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isReady ? 'READY' : 'LOADING',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      body: error != null
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                initializeScreen();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : !isReady
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              status,
              style: const TextStyle(
                color: Colors.white,
              ),
            ),
          ],
        ),
      )
          : InAppWebView(
        key: ValueKey(_useFrontCamera),
        initialUrlRequest: URLRequest(
          url: WebUri(
            'http://localhost:8080/index2.html',
          ),
        ),

        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          useHybridComposition: true,
          isInspectable: true,
        ),

        onWebViewCreated: (controller) {
          debugPrint('WebView created');
          _navigatorWebViewController = controller;
          setupJavascriptHandlers(controller);
        },

        onPermissionRequest:
            (controller, request) async {

          final cameraGranted =
          await Permission.camera.isGranted;

          if (!cameraGranted) {
            return PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.DENY,
            );
          }

          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },

        onLoadStart: (controller, url) {
          debugPrint('Loading HTML: $url');
        },

        onLoadStop: (controller, url) {
          debugPrint('HTML loaded: $url');
        },

        onReceivedError:
            (controller, request, webResourceError) {
          debugPrint(
            'WebView error: ${webResourceError.description}',
          );
        },

        onConsoleMessage: (controller, message) {
          debugPrint(
            'JS Console: ${message.message}',
          );
        },
      ),
    );
  }
}
