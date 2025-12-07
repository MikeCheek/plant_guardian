import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../TFLiteHelper.dart';

class ImageClassifierLiveScreen extends StatefulWidget {
  const ImageClassifierLiveScreen({super.key});

  @override
  State<ImageClassifierLiveScreen> createState() =>
      _ImageClassifierLiveScreenState();
}

class _ImageClassifierLiveScreenState extends State<ImageClassifierLiveScreen> {
  CameraController? _cameraController;
  List<String> _predictions = [];
  bool _isProcessing = false;
  bool _isPaused = true;

  /// NEW: disable UI until init finished
  bool _initializing = true;

  List<CameraDescription>? _cameras;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();

      final camera = _cameras!.first;

      /// IMPORTANT FIX: Use only Preview + ImageAnalysis
      _cameraController = CameraController(
        camera,
        ResolutionPreset.low, // Safe resolution
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // required for analysis
      );

      await _cameraController!.initialize();

      /// Only start the stream once initialized
      await _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint("Camera init failed: $e");
    }

    if (!mounted) return;

    setState(() => _initializing = false);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isPaused) return;

    _frameCount++;
    if (_frameCount % 25 != 0) return;

    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final (result, score) = await TFLiteHelper.classifyCameraImage(image);

      if (score < 0.5) {
        _isProcessing = false;
        return;
      }

      setState(() {
        _predictions.insert(
          0,
          "$result (${(score * 100).toStringAsFixed(1)}%)",
        );
        if (_predictions.length > 10) {
          _predictions = _predictions.sublist(0, 10);
        }
      });
    } catch (e) {
      debugPrint("Prediction error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
    _cameraController?.dispose();
    super.dispose();
  }

  void _togglePause() {
    if (_initializing) return; // NEW: disable button during init

    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _toggleFlash() {
    if (_initializing) return; // NEW: disable button

    if (_cameraController == null) return;

    final flashOn = _cameraController!.value.flashMode == FlashMode.torch;

    _cameraController!.setFlashMode(flashOn ? FlashMode.off : FlashMode.torch);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                if (_initializing || _cameraController == null)
                  const Center(child: CircularProgressIndicator())
                else if (!_cameraController!.value.isInitialized)
                  const Center(child: CircularProgressIndicator())
                else
                  CameraPreview(_cameraController!),

                /// Pause button
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton(
                    onPressed: _initializing ? null : _togglePause,
                    backgroundColor: _initializing ? Colors.grey : Colors.blue,
                    child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  ),
                ),

                /// Flash button
                Positioned(
                  bottom: 24,
                  left: 24,
                  child: FloatingActionButton(
                    onPressed: _initializing ? null : _toggleFlash,
                    backgroundColor: _initializing ? Colors.grey : Colors.blue,
                    child: Icon(
                      (_cameraController?.value.flashMode ?? FlashMode.off) ==
                              FlashMode.torch
                          ? Icons.flash_on
                          : Icons.flash_off,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// Predictions
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: _predictions.length,
                itemBuilder: (_, index) {
                  final size = (22 - index).clamp(12, 22).toDouble();
                  final opacity = (1 - index * 0.05).clamp(0.3, 1.0);

                  return Opacity(
                    opacity: opacity,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        _predictions[index],
                        style: TextStyle(fontSize: size),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
