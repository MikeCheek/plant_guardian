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
  final String modelFile;
  final String labelFile;

  late List<String> _labels;
  late Float32List _inputBuffer;
  late Float32List _outputBuffer;

  // Constructor to pass specific model configurations
  TFLiteHelper({
    required this.modelFile,
    required this.labelFile,
    this.imageSize = 256,
  });

  Future<void> init() async {
    try {
      print("🔹 Loading TFLite model: $modelFile");
      _interpreter = await Interpreter.fromAsset(modelFile);
      _labels = (await rootBundle.loadString(labelFile)).trim().split('\n');

      numClasses = _labels.length;

      // Initialize buffers specific to this instance's size/classes
      _inputBuffer = Float32List(imageSize * imageSize * 3);
      _outputBuffer = Float32List(numClasses);

      _isInitialized = true;
      print("✅ Model $modelFile loaded successfully!");
    } catch (e, stack) {
      print("❌ Failed to load model: $e");
      print(stack);
    }
  }

  bool get isInitialized => _isInitialized;

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
        _inputBuffer[o++] = pixel.r.toDouble(); // (pixel.r - 127.5) / 127.5;
        _inputBuffer[o++] = pixel.g.toDouble(); // (pixel.g - 127.5) / 127.5;
        _inputBuffer[o++] = pixel.b.toDouble(); // (pixel.b - 127.5) / 127.5;
      }
    }
  }

  Future<(String, double)> classifyImage(File imageFile) async {
    if (!_isInitialized) throw Exception("Model not initialized");

    preprocessImage(imageFile);

    // Reshape input for model: [1, 224, 224, 3]
    final input = _inputBuffer.reshape([1, imageSize, imageSize, 3]);
    final output = _outputBuffer.reshape([1, numClasses]);

    _interpreter.run(input, output);

    double maxScore = output[0][0];
    int maxIndex = 0;
    for (int i = 0; i < output[0].length; i++) {
      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        maxIndex = i;
      }
    }

    return (_labels[maxIndex], maxScore);
  }

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
        _inputBuffer[o++] = r.toDouble(); // (r - 127.5) / 127.5;
        _inputBuffer[o++] = g.toDouble(); // (g - 127.5) / 127.5;
        _inputBuffer[o++] = b.toDouble(); // (b - 127.5) / 127.5;
      }
    }
  }

  Future<(String, double)> classifyCameraImage(CameraImage image) async {
    if (!_isInitialized) throw Exception("Model not initialized");

    preprocessCameraImage(image);

    final input = _inputBuffer.reshape([1, imageSize, imageSize, 3]);
    final output = _outputBuffer.reshape([1, numClasses]);
    _interpreter.run(input, output);

    double maxScore = output[0][0];
    int maxIndex = 0;
    for (int i = 0; i < output[0].length; i++) {
      if (output[0][i] > maxScore) {
        maxScore = output[0][i];
        maxIndex = i;
      }
    }

    return (_labels[maxIndex], maxScore);
  }
}
