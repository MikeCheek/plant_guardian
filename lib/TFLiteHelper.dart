import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

class TFLiteHelper {
  late Interpreter _interpreter;
  bool _isInitialized = false;

  final int imageSize;
  late int numClasses;
  final String modelFile; // This can now be an asset path or a full file path
  final String labelFile; // This can now be an asset path or a full file path
  final bool isAsset; // NEW: Tells the helper where to look
  int version = 0;

  late List<String> _labels;
  late Float32List _inputBuffer;
  late Float32List _outputBuffer;

  TFLiteHelper({
    required this.modelFile,
    required this.labelFile,
    this.imageSize = 256,
    this.isAsset = true, // Default to true for backward compatibility
  });

  Future<void> init({int version = 0}) async {
    this.version = version;
    try {
      if (isAsset) {
        print("🔹 Loading TFLite model from ASSETS: $modelFile");
        _interpreter = await Interpreter.fromAsset(modelFile);
        _labels = (await rootBundle.loadString(labelFile)).trim().split('\n');
      } else {
        print("📂 Loading TFLite model from STORAGE: $modelFile");
        // Load the model from a physical file path
        _interpreter = Interpreter.fromFile(File(modelFile));

        // Load the labels from a physical file path
        final labelData = await File(labelFile).readAsString();
        _labels = labelData.trim().split('\n');
      }

      numClasses = _labels.length;

      // Initialize buffers
      _inputBuffer = Float32List(imageSize * imageSize * 3);
      _outputBuffer = Float32List(numClasses);

      _isInitialized = true;
      print("✅ Model loaded successfully!");
    } catch (e, stack) {
      print("❌ Failed to load model: $e");
      print(stack);
    }
  }

  bool get isInitialized => _isInitialized;

  // --- Preprocessing remains the same ---
  void preprocessImage(File imageFile) {
    final image = img.decodeImage(imageFile.readAsBytesSync())!;
    final resizedImage = img.copyResize(
      image,
      width: imageSize,
      height: imageSize,
    );

    int o = 0;
    for (int y = 0; y < imageSize; y++) {
      for (int x = 0; x < imageSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        // Ensure normalization matches your training (0-255 or -1 to 1)
        _inputBuffer[o++] = pixel.r.toDouble();
        _inputBuffer[o++] = pixel.g.toDouble();
        _inputBuffer[o++] = pixel.b.toDouble();
      }
    }
  }

  Future<(String, double)> classifyImage(File imageFile) async {
    if (!_isInitialized) throw Exception("Model not initialized");

    preprocessImage(imageFile);

    final input = _inputBuffer.reshape([1, imageSize, imageSize, 3]);
    final output = _outputBuffer.reshape([1, numClasses]);

    _interpreter.run(input, output);

    double maxScore = -1.0;
    int maxIndex = 0;
    for (int i = 0; i < output[0].length; i++) {
      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        maxIndex = i;
      }
    }

    return (_labels[maxIndex], maxScore);
  }

  // --- Camera Preprocessing remains the same ---
  void preprocessCameraImage(CameraImage image) {
    final yPlane = image.planes[0],
        uPlane = image.planes[1],
        vPlane = image.planes[2];
    final yRowStride = yPlane.bytesPerRow, uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel!;
    int o = 0;
    for (int y = 0; y < imageSize; y++) {
      final sy = (y * image.height / imageSize).floor();
      final yBase = sy * yRowStride;
      final uvRow = (sy >> 1) * uvRowStride;
      for (int x = 0; x < imageSize; x++) {
        final sx = (x * image.width / imageSize).floor();
        final yIndex = yBase + sx;
        final uvCol = (sx >> 1) * uvPixelStride;
        final u = uPlane.bytes[uvRow + uvCol];
        final v = vPlane.bytes[uvRow + uvCol];
        final Y = yPlane.bytes[yIndex];
        double yf = Y.toDouble();
        double uf = u.toDouble() - 128.0;
        double vf = v.toDouble() - 128.0;
        double r = (yf + 1.402 * vf).clamp(0, 255);
        double g = (yf - 0.344136 * uf - 0.714136 * vf).clamp(0, 255);
        double b = (yf + 1.772 * uf).clamp(0, 255);
        _inputBuffer[o++] = r;
        _inputBuffer[o++] = g;
        _inputBuffer[o++] = b;
      }
    }
  }

  Future<(String, double)> classifyCameraImage(CameraImage image) async {
    if (!_isInitialized) throw Exception("Model not initialized");
    preprocessCameraImage(image);
    final input = _inputBuffer.reshape([1, imageSize, imageSize, 3]);
    final output = _outputBuffer.reshape([1, numClasses]);
    _interpreter.run(input, output);

    double maxScore = -1.0;
    int maxIndex = 0;
    for (int i = 0; i < output[0].length; i++) {
      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        maxIndex = i;
      }
    }
    return (_labels[maxIndex], maxScore);
  }

  void close() {
    _interpreter.close();
  }
}
