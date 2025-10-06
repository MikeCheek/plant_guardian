import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../TFLiteHelper.dart';

class ImageClassifierLiveScreen extends StatefulWidget {
  const ImageClassifierLiveScreen({super.key});

  @override
  _ImageClassifierLiveScreenState createState() =>
      _ImageClassifierLiveScreenState();
}

class _ImageClassifierLiveScreenState extends State<ImageClassifierLiveScreen> {
  CameraController? _cameraController;
  List<String> _predictions = [];
  bool _isProcessing = false;
  List<CameraDescription>? cameras;
  bool _isPaused = true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    cameras = await availableCameras();
    _cameraController = CameraController(
      cameras!.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    _cameraController!.startImageStream(_processCameraImage);
    setState(() {});
  }

  int _frameCount = 0;

  Future<void> _processCameraImage(CameraImage image) async {
    _frameCount++;
    if (_isPaused || _frameCount % 25 != 0 || _isProcessing)
      return; // Only every 25th frame
    _isProcessing = true;
    try {
      final result = await TFLiteHelper.classifyCameraImage(image);
      setState(() {
        _predictions.insert(0, result);
        if (_predictions.length > 10) {
          _predictions = _predictions.sublist(0, 10);
        }
      });
    } catch (e) {
      setState(() {
        _predictions.insert(0, "Error: $e");
        if (_predictions.length > 10) {
          _predictions = _predictions.sublist(0, 10);
        }
      });
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
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        if (_cameraController != null &&
            _cameraController!.value.isStreamingImages) {
          _cameraController!.stopImageStream();
        }
      } else {
        if (_cameraController != null &&
            !_cameraController!.value.isStreamingImages) {
          _cameraController!.startImageStream(_processCameraImage);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Live Image Classifier')),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                _cameraController != null &&
                        _cameraController!.value.isInitialized
                    ? CameraPreview(_cameraController!)
                    : Center(child: CircularProgressIndicator()),
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: FloatingActionButton(
                    onPressed: _togglePause,
                    child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                    tooltip: _isPaused
                        ? 'Resume Predictions'
                        : 'Pause Predictions',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: _predictions.length,
                itemBuilder: (context, index) {
                  // Top prediction is largest, older ones get smaller
                  final baseFontSize = 22.0;
                  final fontSize = (baseFontSize - index).clamp(
                    12.0,
                    baseFontSize,
                  );
                  final opacity = 1.0 - (index * 0.05);
                  return Opacity(
                    opacity: opacity.clamp(0.3, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        _predictions[index],
                        style: TextStyle(fontSize: fontSize),
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
