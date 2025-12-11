import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Assuming TFLiteHelper is correctly defined and imported
import '../TFLiteHelper.dart';

class ImageClassifierScreen extends StatefulWidget {
  const ImageClassifierScreen({super.key});

  @override
  _ImageClassifierScreenState createState() => _ImageClassifierScreenState();
}

class _ImageClassifierScreenState extends State<ImageClassifierScreen> {
  File? _image;
  String _result = '';
  double? _score;
  bool _isLoading = false;

  // Helper function to handle image classification logic
  Future<(String, double)> _classifyImage(File image) async {
    try {
      // Replace with your actual TFLite classification logic
      return await TFLiteHelper.classifyImage(image);
    } catch (e) {
      throw Exception("Classification failed: $e");
    }
  }

  // Common function to process a picked image
  Future<void> _processImage(XFile pickedFile) async {
    if (pickedFile == null) return;

    setState(() {
      _image = File(pickedFile.path);
      _isLoading = true;
      _result = ''; // Clear previous result
      _score = null;
    });

    try {
      final (result, score) = await _classifyImage(_image!);
      setState(() {
        _result = result;
        _score = score;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = "Classification Error";
        _score = null;
        _isLoading = false;
        // Optionally show a detailed error message in console or a dialog
        print("Detailed Error: $e");
      });
    }
  }

  // Function to pick image from Gallery
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      await _processImage(pickedFile);
    }
  }

  // Function to take a picture with the Camera
  Future<void> _takePicture() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile != null) {
      await _processImage(pickedFile);
    }
  }

  // Show a dialog to let the user select the source
  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Gallery'),
                onTap: () {
                  _pickImage();
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  _takePicture();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get the bottom padding provided by the system (e.g., safe area on modern phones)
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    // 2. Estimate the height of the FloatingActionButton.extended and its default margin
    // A standard FAB extended height is around 48.0, and centerFloat adds a margin of about 16.0.
    const double fabHeight = 56.0; // A safe estimate for FAB + padding/margin

    // 3. Calculate the total required bottom space to prevent overlap
    final double requiredBottomSpace =
        fabHeight + 20.0 + bottomPadding; // 20.0 for extra visual padding

    return Scaffold(
      body: Column(
        children: [
          // 1. Image Display Area
          Expanded(
            child: Container(
              alignment: Alignment.topCenter,
              child: _image != null
                  ? Image.file(
                      _image!,
                      fit: BoxFit.contain, // Show the whole image nicely
                      height: MediaQuery.of(context).size.height * 0.5,
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image, size: 80, color: Colors.grey[600]),
                        const SizedBox(height: 10),
                        const Text(
                          'Select an image to classify',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
            ),
          ),

          // 2. Loading Indicator
          if (_isLoading) const LinearProgressIndicator(),

          // 3. Result Display Area
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Classification Result:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _score != null
                      ? '$_result (${(_score! * 100).toStringAsFixed(2)}%)'
                      : (_isLoading
                            ? 'Classifying...'
                            : 'Awaiting image selection...'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: _score != null ? Colors.green[700] : Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // 🛑 This is the crucial fix: Add required spacing before the FAB
          SizedBox(height: requiredBottomSpace),
        ],
      ),

      // 4. Floating Action Button for selection
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showImageSourceDialog(context),
        label: const Text('Select Image'),
        icon: const Icon(Icons.photo_camera),
        tooltip: 'Select Image Source (Gallery or Camera)',
      ),
      // To center the FAB on the bottom
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
