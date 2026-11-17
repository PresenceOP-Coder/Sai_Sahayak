import 'package:flutter/material.dart';

/// Represents the result of an ONNX currency inference pass.
class CurrencyDetection {
  final String label;
  final String rawClass;
  final double confidence;
  final Rect? normalizedBoundingBox;
  final int inferenceTimeMs;
  final String debugInfo;

  const CurrencyDetection({
    required this.label,
    required this.rawClass,
    required this.confidence,
    this.normalizedBoundingBox,
    required this.inferenceTimeMs,
    this.debugInfo = '',
  });

  /// Human-friendly denomination formatting
  static String formatDenomination(String rawName) {
    switch (rawName) {
      case '100IndianRupees':
        return '₹100';
      case '10IndianRupees':
        return '₹10';
      case '200IndianRupees':
        return '₹200';
      case '20IndianRupees':
        return '₹20';
      case '500IndianRupees':
        return '₹500';
      case '50IndianRupees':
        return '₹50';
      case '5IndianRupees':
        return '₹5';
      default:
        // Fallback for custom or unexpected class names
        final cleaned = rawName.replaceAll(RegExp(r'[^0-9]'), '');
        return cleaned.isNotEmpty ? '₹$cleaned' : rawName;
    }
  }

  /// Detailed note description for speech/accessibility
  String get speechAnnouncement {
    final clean = label.replaceAll('₹', '').trim();
    final percent = (confidence * 100).toInt();
    return '$clean Rupees detected with $percent percent confidence';
  }
}
