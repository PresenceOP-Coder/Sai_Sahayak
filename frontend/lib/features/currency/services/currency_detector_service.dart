import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import '../models/currency_detection.dart';

class CurrencyDetectorService {
  static final CurrencyDetectorService _instance =
      CurrencyDetectorService._internal();
  factory CurrencyDetectorService() => _instance;
  CurrencyDetectorService._internal();

  static const String modelAssetPath = 'assets/models/best.onnx';
  static const int inputWidth = 640;
  static const int inputHeight = 640;

  // The 7 Indian Rupee classes from the trained YOLOv10 model
  static const Map<int, String> classMap = {
    0: '100IndianRupees',
    1: '10IndianRupees',
    2: '200IndianRupees',
    3: '20IndianRupees',
    4: '500IndianRupees',
    5: '50IndianRupees',
    6: '5IndianRupees',
  };

  OrtSession? _session;
  String? _inputName;
  String? _outputName;
  bool _isInitializing = false;
  bool get isModelLoaded => _session != null;

  /// Loads the ONNX model into memory once. Safe for repeated calls across Web and Native.
  Future<void> initialize() async {
    if (_session != null || _isInitializing) return;
    _isInitializing = true;

    try {
      final ort = OnnxRuntime();
      try {
        _session = await ort.createSessionFromAsset(modelAssetPath);
      } catch (e) {
        if (kIsWeb) {
          // On Web, static asset paths can occasionally be nested under assets/
          try {
            _session = await ort.createSession('assets/$modelAssetPath');
          } catch (_) {
            rethrow;
          }
        } else {
          rethrow;
        }
      }
      _inputName = _session!.inputNames.first;
      _outputName = _session!.outputNames.first;
      debugPrint('[CurrencyDetector] Model loaded: input=$_inputName, output=$_outputName');
    } catch (e) {
      debugPrint('[CurrencyDetector] Error loading model: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Run currency detection from in-memory bytes (cross-platform: Web, Android, iOS, Desktop).
  Future<CurrencyDetection?> detectFromBytes(Uint8List bytes, {double minConfidence = 0.30}) async {
    final image = img.decodeImage(bytes);
    if (image == null) throw Exception('Unable to decode image bytes.');
    return detectFromImage(image, minConfidence: minConfidence);
  }

  /// Run currency detection on a file from Camera or Gallery.
  Future<CurrencyDetection?> detectFromFile(File file, {double minConfidence = 0.30}) async {
    final bytes = await file.readAsBytes();
    return detectFromBytes(bytes, minConfidence: minConfidence);
  }

  /// Run currency detection on an existing decoded Image (e.g. from camera frame).
  Future<CurrencyDetection?> detectFromImage(img.Image image, {double minConfidence = 0.30}) async {
    if (_session == null) {
      await initialize();
    }

    OrtValue? inputTensor;
    Map<String, OrtValue>? outputs;

    try {
      // 1. Resize to model input shape [640, 640]
      final resized = img.copyResize(image, width: inputWidth, height: inputHeight);

      // 2. Convert to Planar Float32 tensor [1, 3, 640, 640] (NCHW)
      final floatList = Float32List(1 * 3 * inputWidth * inputHeight);
      final area = inputWidth * inputHeight;

      for (int y = 0; y < inputHeight; y++) {
        for (int x = 0; x < inputWidth; x++) {
          final pixel = resized.getPixel(x, y);
          final index = y * inputWidth + x;
          floatList[index] = pixel.r / 255.0;            // R
          floatList[area + index] = pixel.g / 255.0;     // G
          floatList[2 * area + index] = pixel.b / 255.0; // B
        }
      }

      inputTensor = await OrtValue.fromList(
        floatList,
        [1, 3, inputWidth, inputHeight],
      );

      // 3. Execute inference with timer
      final stopwatch = Stopwatch()..start();
      outputs = await _session!.run({_inputName!: inputTensor});
      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      // 4. Parse output
      final output = outputs[_outputName]!;
      final outputData = (await output.asFlattenedList())
          .map((value) => (value as num).toDouble())
          .toList();
      final shape = output.shape;

      return _parseDetectionOutput(outputData, shape, elapsedMs, minConfidence);
    } finally {
      await inputTensor?.dispose();
      if (outputs != null) {
        for (final out in outputs.values) {
          await out.dispose();
        }
      }
    }
  }

  CurrencyDetection? _parseDetectionOutput(
    List<double> data,
    List<int> shape,
    int elapsedMs,
    double minConfidence,
  ) {
    if (data.isEmpty) return null;

    int bestClassIdx = -1;
    double bestScore = 0.0;
    Rect? bestRect;

    // Pattern A: YOLOv10 detection output: [1, 11, 8400]
    if (shape.length == 3 && shape[1] == 11 && shape[2] == 8400) {
      const int numAnchors = 8400;
      const int numClasses = 7;

      for (int i = 0; i < numAnchors; i++) {
        for (int c = 0; c < numClasses; c++) {
          final score = data[(4 + c) * numAnchors + i];
          if (score > bestScore) {
            bestScore = score;
            bestClassIdx = c;

            final cx = data[0 * numAnchors + i];
            final cy = data[1 * numAnchors + i];
            final w = data[2 * numAnchors + i];
            final h = data[3 * numAnchors + i];

            final left = (cx - w / 2) / inputWidth;
            final top = (cy - h / 2) / inputHeight;
            final right = (cx + w / 2) / inputWidth;
            final bottom = (cy + h / 2) / inputHeight;

            bestRect = Rect.fromLTRB(
              left.clamp(0.0, 1.0),
              top.clamp(0.0, 1.0),
              right.clamp(0.0, 1.0),
              bottom.clamp(0.0, 1.0),
            );
          }
        }
      }
    }
    // Pattern B: Transposed YOLO format: [1, 8400, 11]
    else if (shape.length == 3 && shape[1] == 8400 && shape[2] == 11) {
      const int numAnchors = 8400;
      const int numClasses = 7;

      for (int i = 0; i < numAnchors; i++) {
        final rowOffset = i * 11;
        for (int c = 0; c < numClasses; c++) {
          final score = data[rowOffset + 4 + c];
          if (score > bestScore) {
            bestScore = score;
            bestClassIdx = c;

            final cx = data[rowOffset + 0];
            final cy = data[rowOffset + 1];
            final w = data[rowOffset + 2];
            final h = data[rowOffset + 3];

            final left = (cx - w / 2) / inputWidth;
            final top = (cy - h / 2) / inputHeight;
            final right = (cx + w / 2) / inputWidth;
            final bottom = (cy + h / 2) / inputHeight;

            bestRect = Rect.fromLTRB(
              left.clamp(0.0, 1.0),
              top.clamp(0.0, 1.0),
              right.clamp(0.0, 1.0),
              bottom.clamp(0.0, 1.0),
            );
          }
        }
      }
    }
    // Pattern C: Standard classification logits: [1, 7]
    else if (data.length == classMap.length) {
      final maxVal = data.reduce(math.max);
      final expList = data.map((x) => math.exp(x - maxVal)).toList();
      final sumExp = expList.reduce((a, b) => a + b);
      final probs = expList.map((e) => e / sumExp).toList();

      for (int c = 0; c < probs.length; c++) {
        if (probs[c] > bestScore) {
          bestScore = probs[c];
          bestClassIdx = c;
        }
      }
    }
    // Pattern D: Generic fallback scanner
    else {
      for (int i = 0; i < data.length; i++) {
        final val = data[i];
        if (val > bestScore && val <= 1.0) {
          bestScore = val;
          bestClassIdx = i % classMap.length;
        }
      }
    }

    if (bestClassIdx < 0 || bestScore < minConfidence) {
      return CurrencyDetection(
        label: 'No note detected',
        rawClass: 'none',
        confidence: bestScore,
        inferenceTimeMs: elapsedMs,
        debugInfo: 'Shape: $shape | Best score below threshold: ${(bestScore * 100).toStringAsFixed(1)}%',
      );
    }

    final rawName = classMap[bestClassIdx] ?? 'UnknownNote';
    final formattedLabel = CurrencyDetection.formatDenomination(rawName);

    return CurrencyDetection(
      label: formattedLabel,
      rawClass: rawName,
      confidence: bestScore,
      normalizedBoundingBox: bestRect,
      inferenceTimeMs: elapsedMs,
      debugInfo: 'Shape: $shape\n'
          'Latency: ${elapsedMs}ms\n'
          'Class Index: $bestClassIdx ($rawName)\n'
          'Confidence: ${(bestScore * 100).toStringAsFixed(2)}%',
    );
  }

  void dispose() {
    _session?.close();
    _session = null;
  }
}
