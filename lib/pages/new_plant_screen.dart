import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:plant_guardian/widgets/image_helper.dart';

class NewPlantScreen extends StatefulWidget {
  const NewPlantScreen({super.key});

  @override
  State<NewPlantScreen> createState() => _NewPlantScreenState();
}

class _NewPlantScreenState extends State<NewPlantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  // State variables for form inputs
  String _name = '';
  String _description = '';
  String _waterFrequency = 'Weekly';
  String _soilType = 'General Purpose';
  String _idealPeriod = 'Spring';
  String _exposition = 'Full Sun';
  String _curiosity = '';

  // 🛑 CHANGED: Now storing the Base64 string directly
  String _base64ImageString = '';

  // Constants
  static const int TARGET_IMAGE_SIZE = 128;

  // Dropdown options
  final List<String> _waterOptions = [
    'Daily',
    'Weekly',
    'Bi-Weekly',
    'Monthly',
  ];
  final List<String> _soilOptions = [
    'General Purpose',
    'Sandy',
    'Clay',
    'Peat',
  ];
  final List<String> _periodOptions = [
    'Spring',
    'Summer',
    'Autumn',
    'Winter',
    'Year-Round',
  ];
  final List<String> _expositionOptions = [
    'Full Sun',
    'Partial Shade',
    'Full Shade',
  ];

  // --- Image Picking, Cropping, and Encoding Logic ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final File rawImageFile = File(pickedFile.path);

      // 1. Crop the image to a square aspect ratio
      final croppedFile = await cropImage(context, rawImageFile);

      if (croppedFile != null) {
        final File croppedImageFile = File(croppedFile.path);

        // 2. Convert, resize, and encode to Base64 string
        final String encodedString = await convertAndCompressImage(
          croppedImageFile,
          TARGET_IMAGE_SIZE,
        );

        setState(() {
          _base64ImageString = encodedString;
        });
      }
    }
  }

  // --- Data Saving Logic ---
  Future<void> _savePlantData() async {
    if (_formKey.currentState!.validate()) {
      if (_base64ImageString.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select and crop an image.')),
        );
        return;
      }

      _formKey.currentState!.save();

      try {
        await _firestore.collection('plants').add({
          'name': _name,
          'description': _description,
          // 🛑 CHANGED: Saving the Base64 string directly to Firestore
          'imageUrl': _base64ImageString,
          'waterFrequency': _waterFrequency,
          'soilType': _soilType,
          'idealPeriod': _idealPeriod,
          'exposition': _exposition,
          'curiosity': _curiosity,
          'createdAt': Timestamp.now(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plant added successfully!')),
          );
          Navigator.of(context).pop(); // Close the screen
        }
      } catch (e) {
        print("Error saving plant: $e");
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving plant: $e')));
        }
      }
    }
  }

  // Helper to display the Base64 image string
  Widget _buildBase64Image(String base64) {
    // Split the Base64 data to get just the raw string part (remove 'data:image/jpeg;base64,')
    final String rawBase64 = base64.split(',').last;

    try {
      return Image.memory(
        base64Decode(rawBase64),
        width: TARGET_IMAGE_SIZE.toDouble(),
        height: TARGET_IMAGE_SIZE.toDouble(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
      );
    } catch (e) {
      return const Text('Image load error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Plant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Image Picker ---
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_camera),
                label: Text(
                  _base64ImageString.isEmpty
                      ? 'Load Plant Image (Required)'
                      : 'Change Plant Image',
                ),
              ),
              if (_base64ImageString.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  // 🛑 CHANGED: Displaying the image from the Base64 string
                  child: _buildBase64Image(_base64ImageString),
                ),
              const SizedBox(height: 20),

              // ... (Other form fields remain the same)
              // (Water Frequency, Soil Type, Ideal Period, Exposition, Curiosity)

              // --- Name Field ---
              TextFormField(
                decoration: const InputDecoration(labelText: 'Plant Name *'),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value!.trim().isEmpty ? 'Please enter a name.' : null,
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 10),

              // --- Description Field ---
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                onSaved: (value) => _description = value!,
              ),
              const SizedBox(height: 20),

              // --- Water Frequency Dropdown ---
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Water Frequency *',
                ),
                value: _waterFrequency,
                items: _waterOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _waterFrequency = newValue!;
                  });
                },
                onSaved: (value) => _waterFrequency = value!,
              ),
              const SizedBox(height: 20),

              // --- Type of Soil Dropdown ---
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Type of Soil *'),
                value: _soilType,
                items: _soilOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _soilType = newValue!;
                  });
                },
                onSaved: (value) => _soilType = value!,
              ),
              const SizedBox(height: 20),

              // --- Ideal Period Dropdown ---
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Ideal Period (Planting/Care) *',
                ),
                value: _idealPeriod,
                items: _periodOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _idealPeriod = newValue!;
                  });
                },
                onSaved: (value) => _idealPeriod = value!,
              ),
              const SizedBox(height: 20),

              // --- Exposition to Sunlight Dropdown ---
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Exposition to Sunlight *',
                ),
                value: _exposition,
                items: _expositionOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _exposition = newValue!;
                  });
                },
                onSaved: (value) => _exposition = value!,
              ),
              const SizedBox(height: 20),

              // --- Curiosity Field ---
              TextFormField(
                decoration: const InputDecoration(labelText: 'Curiosity/Notes'),
                maxLines: 2,
                keyboardType: TextInputType.multiline,
                onSaved: (value) => _curiosity = value!,
              ),
              const SizedBox(height: 30),

              // --- Save Button ---
              ElevatedButton.icon(
                onPressed: _savePlantData,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text(
                  'Add Plant to Database',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
