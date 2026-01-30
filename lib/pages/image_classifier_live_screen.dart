// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:camera_android_camerax/camera_android_camerax.dart';
// import 'package:flutter/services.dart';

// import '../TFLiteHelper.dart';

// class ImageClassifierLiveScreen extends StatefulWidget {
//   const ImageClassifierLiveScreen({super.key});

//   @override
//   State<ImageClassifierLiveScreen> createState() =>
//       _ImageClassifierLiveScreenState();
// }

// class _ImageClassifierLiveScreenState extends State<ImageClassifierLiveScreen> {
//   CameraController? _cameraController;
//   List<CameraDescription>? _cameras;

//   List<String> _predictions = [];
//   bool _isProcessing = false;
//   bool _isPaused = true;
//   bool _initializing = true;

//   int _frameCount = 0;

//   @override
//   void initState() {
//     super.initState();
//     const String speciesModelPath = 'assets/houseplant_classifier_model.tflite';
//     const String speciesLabelPath = 'assets/houseplant_classifier_labels.txt';
//     TFLiteHelper.loadModel(speciesModelPath, speciesLabelPath).then((_) {
//       if (!mounted) return;
//       setState(() {});
//     });
//     _initCamera();
//   }

//   Future<void> _initCamera() async {
//     try {
//       _cameras = await availableCameras();
//       final camera = _cameras!.first;

//       _cameraController = CameraController(
//         camera,
//         ResolutionPreset.medium,
//         enableAudio: false,
//         imageFormatGroup: ImageFormatGroup.yuv420,
//       );

//       await _cameraController!.initialize();
//     } catch (e) {
//       debugPrint("Camera init failed: $e");
//     }

//     if (!mounted) return;
//     setState(() => _initializing = false);
//   }

//   Future<void> _processCameraImage(CameraImage cameraImage) async {
//     if (_isPaused || _isProcessing) return;

//     _frameCount++;
//     if (_frameCount % 5 != 0) return;

//     _isProcessing = true;

//     try {
//       final (result, score) = await TFLiteHelper.classifyCameraImage(
//         cameraImage,
//       );

//       if (score < 0.5) {
//         _isProcessing = false;
//         return;
//       }

//       if (mounted) {
//         setState(() {
//           _predictions.insert(
//             0,
//             "$result (${(score * 100).toStringAsFixed(1)}%)",
//           );
//           if (_predictions.length > 10) {
//             _predictions = _predictions.sublist(0, 10);
//           }
//         });
//       }
//     } catch (e) {
//       debugPrint("Prediction error: $e");
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   void _togglePause() {
//     if (_initializing) return;
//     if (_isPaused) {
//       _cameraController?.startImageStream(_processCameraImage);
//     } else {
//       _cameraController?.stopImageStream();
//     }
//     setState(() {
//       _isPaused = !_isPaused;
//     });
//   }

//   void _toggleFlash() {
//     if (_initializing || _cameraController == null) return;

//     final flashMode = _cameraController!.value.flashMode;
//     final flashOn = flashMode == FlashMode.torch;

//     _cameraController!.setFlashMode(flashOn ? FlashMode.off : FlashMode.torch);

//     setState(() {});
//   }

//   @override
//   void dispose() {
//     _cameraController?.stopImageStream();
//     _cameraController?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Column(
//         children: [
//           Expanded(
//             flex: 2,
//             child: Stack(
//               children: [
//                 if (_initializing ||
//                     _cameraController == null ||
//                     !_cameraController!.value.isInitialized)
//                   const Center(child: CircularProgressIndicator())
//                 else
//                   CameraPreview(_cameraController!),

//                 Positioned(
//                   bottom: 24,
//                   right: 24,
//                   child: FloatingActionButton(
//                     onPressed: _initializing ? null : _togglePause,
//                     backgroundColor: _initializing ? Colors.grey : Colors.blue,
//                     child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
//                   ),
//                 ),

//                 Positioned(
//                   bottom: 24,
//                   left: 24,
//                   child: FloatingActionButton(
//                     onPressed: _initializing ? null : _toggleFlash,
//                     backgroundColor: _initializing ? Colors.grey : Colors.blue,
//                     child: Icon(
//                       (_cameraController?.value.flashMode ?? FlashMode.off) ==
//                               FlashMode.torch
//                           ? Icons.flash_on
//                           : Icons.flash_off,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           Expanded(
//             flex: 1,
//             child: Padding(
//               padding: const EdgeInsets.all(16),
//               child: ListView.builder(
//                 itemCount: _predictions.length,
//                 itemBuilder: (_, index) {
//                   final size = (22 - index).clamp(12, 22).toDouble();
//                   final opacity = (1 - index * 0.05).clamp(0.3, 1.0);

//                   return Opacity(
//                     opacity: opacity,
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 4),
//                       child: Text(
//                         _predictions[index],
//                         style: TextStyle(fontSize: size),
//                         textAlign: TextAlign.center,
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
