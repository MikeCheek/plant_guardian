import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class UserScreen extends StatefulWidget {
  const UserScreen({super.key});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _favPlantController = TextEditingController();

  bool _saving = false;
  File? _newImageFile;

  // 📝 Helper to check if a string is Base64 data (a simplified check)
  bool _isBase64(String? data) {
    if (data == null || data.length < 10) return false;
    // Check for the common prefix used when saving Base64 image data
    return data.startsWith('data:image');
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("You are not logged in.")),
      );
    }

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection("users").doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          _displayNameController.text = _displayNameController.text.isEmpty
              ? (data["displayName"] ?? user.displayName ?? "")
              : _displayNameController.text;

          _bioController.text = _bioController.text.isEmpty
              ? (data["bio"] ?? "")
              : _bioController.text;

          _favPlantController.text = _favPlantController.text.isEmpty
              ? (data["favPlant"] ?? "")
              : _favPlantController.text;

          final String? photoData = data["photoUrl"];
          ImageProvider imageProvider;

          if (_newImageFile != null) {
            // New image selected, use FileImage
            imageProvider = FileImage(_newImageFile!);
          } else if (photoData != null) {
            if (_isBase64(photoData)) {
              // 🚨 NEW LOGIC: Decode Base64 string from Firestore
              final base64String = photoData.split(',').last;
              final bytes = base64Decode(base64String);
              imageProvider = MemoryImage(bytes);
            } else {
              // Legacy URL (if any, or default to asset if it's null/empty)
              imageProvider = const AssetImage(
                "assets/images/default_user.png",
              );
            }
          } else {
            // Default asset image
            imageProvider = const AssetImage(
              "assets/images/user-placeholder.jpg",
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                /// --------------------------
                /// PROFILE IMAGE
                /// --------------------------
                GestureDetector(
                  onTap: _pickNewImage,
                  child: CircleAvatar(
                    radius: 60,
                    // 🚨 CHANGED: Use the determined ImageProvider
                    backgroundImage: imageProvider,
                  ),
                ),
                const SizedBox(height: 20),

                /// ... (Display Name, Email, Bio, Favorite Plant fields remain the same) ...
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: "Display Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  initialValue: user.email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: "About You",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _favPlantController,
                  decoration: const InputDecoration(
                    labelText: "Favorite Plant",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),

                /// --------------------------
                /// SAVE BUTTON
                /// --------------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _saveProfile(user.uid),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Save Changes"),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// PICK IMAGE FROM GALLERY
  Future<void> _pickNewImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      // 1. Get the picked file path
      final File pickedFile = File(picked.path);

      // 2. Call the cropper function
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        // Define the aspect ratio to ensure a squared image
        aspectRatio: const CropAspectRatio(ratioX: 1.0, ratioY: 1.0),
        // Define the cropping UI style
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Picture',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Profile Picture',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );

      // 3. Update the state with the cropped image
      if (croppedFile != null) {
        setState(() => _newImageFile = File(croppedFile.path));
      }
    }
  }

  Future<void> _saveProfile(String uid) async {
    setState(() => _saving = true);

    String? base64Data;

    try {
      if (_newImageFile != null) {
        // 1. Read the image file into a list of bytes
        final List<int> imageBytes = await _newImageFile!.readAsBytes();
        // 2. Decode the bytes into an Image object using the 'image' package
        final img.Image? originalImage = img.decodeImage(
          Uint8List.fromList(imageBytes),
        );

        if (originalImage != null) {
          // 3. Resize the image to 512x512
          final img.Image resizedImage = img.copyResize(
            originalImage,
            width: 256,
            height: 256,
            interpolation: img.Interpolation.average,
          );

          // 4. Encode the resized image back to JPEG bytes
          final List<int> resizedBytes = img.encodeJpg(
            resizedImage,
            quality: 80,
          );

          // 5. Encode the resized bytes to Base64 string
          final String base64String = base64Encode(resizedBytes);

          // Include MIME type for easier decoding later
          base64Data = 'data:image/jpeg;base64,$base64String';
        }
      }

      // Update Firestore
      await _firestore.collection("users").doc(uid).set({
        "displayName": _displayNameController.text,
        "bio": _bioController.text,
        "favPlant": _favPlantController.text,
        "photoUrl": base64Data, // Save the resized Base64 string
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update Firebase Auth displayName
      await _auth.currentUser!.updateDisplayName(_displayNameController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );

      // Clear the local file reference after successful save/update
      setState(() {
        _newImageFile = null;
      });
    } catch (e) {
      print("❌ Error saving profile: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
    }

    setState(() => _saving = false);
  }
}
