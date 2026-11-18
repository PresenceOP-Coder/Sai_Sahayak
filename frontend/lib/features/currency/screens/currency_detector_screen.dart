import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/currency_detection.dart';
import '../services/currency_detector_service.dart';
import '../widgets/currency_bounding_box_painter.dart';

class CurrencyDetectorScreen extends StatefulWidget {
  const CurrencyDetectorScreen({super.key});

  @override
  State<CurrencyDetectorScreen> createState() => _CurrencyDetectorScreenState();
}

class _CurrencyDetectorScreenState extends State<CurrencyDetectorScreen> {
  final CurrencyDetectorService _detectorService = CurrencyDetectorService();
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _tts = FlutterTts();

  Uint8List? _imageBytes;
  CurrencyDetection? _detection;
  bool _isLoading = false;
  bool _isModelReady = false;
  bool _autoSpeak = true;
  CameraDevice _cameraDevice = CameraDevice.rear;
  String _statusMessage = 'Initializing ONNX Runtime...';

  // Theme constants matching Sahayak design
  static const Color primaryColor = Color(0xFF1E2158);
  static const Color accentColor = Color(0xFF4B6CF7);
  static const Color pageBg = Color(0xFFF5F7FF);

  @override
  void initState() {
    super.initState();
    _initTts();
    _initModel();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('en-IN');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5);
    } catch (e) {
      debugPrint('[TTS] Init error: $e');
    }
  }

  Future<void> _initModel() async {
    setState(() {
      _statusMessage = 'Loading ONNX model...';
    });

    try {
      await _detectorService.initialize();
      if (mounted) {
        setState(() {
          _isModelReady = true;
          _statusMessage = 'Ready to scan notes';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Model load error: $e';
        });
      }
    }
  }

  Future<void> _speakResult(CurrencyDetection result) async {
    if (!_autoSpeak) return;
    try {
      await _tts.stop();
      await _tts.speak(result.speechAnnouncement);
    } catch (e) {
      debugPrint('[TTS] Speak error: $e');
    }
  }

  Future<void> _pickAndDetect(ImageSource source) async {
    if (!_isModelReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, ONNX model is still loading...')),
      );
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        preferredCamera: _cameraDevice,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      setState(() {
        _imageBytes = bytes;
        _isLoading = true;
        _detection = null;
        _statusMessage = 'Processing image...';
      });

      final result = await _detectorService.detectFromBytes(bytes);

      if (mounted) {
        setState(() {
          _detection = result;
          _isLoading = false;
          _statusMessage = result?.label ?? 'Detection completed';
        });

        if (result != null && result.rawClass != 'none') {
          _speakResult(result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error during detection: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Currency Detector',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            tooltip: _cameraDevice == CameraDevice.rear
                ? 'Switch to front camera'
                : 'Switch to back camera',
            onPressed: () {
              setState(() {
                _cameraDevice = _cameraDevice == CameraDevice.rear
                    ? CameraDevice.front
                    : CameraDevice.rear;
              });
            },
          ),
          IconButton(
            icon: Icon(_autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            tooltip: _autoSpeak ? 'Mute Speech' : 'Enable Speech',
            onPressed: () {
              setState(() => _autoSpeak = !_autoSpeak);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isModelReady
                      ? const Color(0xFF00E676).withValues(alpha: 0.2)
                      : Colors.orangeAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isModelReady ? const Color(0xFF00E676) : Colors.orangeAccent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isModelReady ? const Color(0xFF00E676) : Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isModelReady ? 'ONNX Ready' : 'Loading',
                      style: TextStyle(
                        color: _isModelReady ? const Color(0xFF00E676) : Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Viewport Canvas
            _buildViewportCard(),
            const SizedBox(height: 16),

            // Results Card
            if (_detection != null) _buildResultCard(),

            // Action Buttons
            const SizedBox(height: 16),
            _buildActionButtons(),

            // Diagnostics & Debug section
            const SizedBox(height: 20),
            _buildDiagnosticsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewportCard() {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_imageBytes != null) ...[
            Image.memory(
              _imageBytes!,
              fit: BoxFit.cover,
            ),
            if (_detection != null && _detection!.normalizedBoundingBox != null)
              CustomPaint(
                painter: CurrencyBoundingBoxPainter(
                  normalizedRect: _detection!.normalizedBoundingBox,
                  label: _detection!.label,
                  confidence: _detection!.confidence,
                ),
              ),
          ] else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.document_scanner_rounded, size: 36, color: accentColor),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Place Currency Note Flat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap "Scan Note" to capture and identify',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),

          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF00E676)),
                    SizedBox(height: 14),
                    Text(
                      'Running ONNX Inference...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final isDetected = _detection!.rawClass != 'none';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDetected ? const Color(0xFF0C2417) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDetected ? const Color(0xFF00E676) : Colors.redAccent.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDetected ? 'DETECTED NOTE' : 'RESULT',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: isDetected ? Colors.white60 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _detection!.label,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: isDetected ? const Color(0xFF00E676) : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (isDetected)
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676).withValues(alpha: 0.2),
                    foregroundColor: const Color(0xFF00E676),
                  ),
                  onPressed: () => _speakResult(_detection!),
                  icon: const Icon(Icons.volume_up_rounded, size: 26),
                  tooltip: 'Read Out Loud',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Confidence: ${(_detection!.confidence * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDetected ? Colors.white70 : Colors.black54,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDetected
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '⚡ ${_detection!.inferenceTimeMs} ms',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDetected ? const Color(0xFF00E676) : primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            onPressed: _isLoading ? null : () => _pickAndDetect(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text(
              'Scan Note',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: primaryColor,
              side: const BorderSide(color: primaryColor, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isLoading ? null : () => _pickAndDetect(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(Icons.terminal_rounded, color: primaryColor),
        title: const Text(
          'Model Diagnostics & Tensors',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
        ),
        subtitle: Text(
          _statusMessage,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1D28),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                'Model Asset: assets/models/best.onnx\n'
                'Target Input: [1, 3, 640, 640] (RGB Planar)\n'
                'Status: $_statusMessage\n'
                '${_detection?.debugInfo ?? "No inference pass recorded yet."}',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFF00E676),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
