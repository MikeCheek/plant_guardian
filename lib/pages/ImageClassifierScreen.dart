import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../TFLiteHelper.dart';

class ImageClassifierScreen extends StatefulWidget {
  const ImageClassifierScreen({super.key});

  @override
  _ImageClassifierScreenState createState() => _ImageClassifierScreenState();
}

class _ImageClassifierScreenState extends State<ImageClassifierScreen> {
  File? _image;
  String _result = '';
  bool _isLoading = false;

  Future<String> _classifyImage(File image) async {
    try {
      return await TFLiteHelper.classifyImage(image);
    } catch (e) {
      throw Exception("Classification failed: $e");
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    setState(() {
      _image = File(pickedFile.path);
      _isLoading = true;
    });

    try {
      final result = await _classifyImage(_image!);
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = "Error: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Classifier')),
      body: Column(
        children: [
          Expanded(
            child: _image != null
                ? Image.file(_image!, fit: BoxFit.cover)
                : Center(child: Text('No image selected')),
          ),
          if (_isLoading) LinearProgressIndicator(),
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              _result,
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          ElevatedButton(onPressed: _pickImage, child: Text('Pick Image')),
        ],
      ),
    );
  }
}
