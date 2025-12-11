import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:plant_guardian/widgets/image_helper.dart';

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

  // 🚨 NEW STATE: Controls view vs. edit mode
  bool _isEditing = false;

  // Storage for original data for cancellation (read during onEdit mode)
  String _originalDisplayName = '';
  String _originalBio = '';
  String _originalFavPlant = '';

  bool _saving = false;
  File? _newImageFile;

  // 📝 Helper to check if a string is Base64 data (a simplified check)
  bool _isBase64(String? data) {
    if (data == null || data.length < 10) return false;
    return data.startsWith('data:image');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _favPlantController.dispose();
    super.dispose();
  }

  // --- Core Logic Functions ---

  /// Toggles the editing mode and saves current data for cancellation.
  void _toggleEditMode(Map<String, dynamic> currentData) {
    if (!_isEditing) {
      // Entering edit mode: Save current field values
      _originalDisplayName = _displayNameController.text;
      _originalBio = _bioController.text;
      _originalFavPlant = _favPlantController.text;
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  /// Cancels edits and reverts to original values.
  void _cancelEdit() {
    // Revert text controllers to saved original values
    _displayNameController.text = _originalDisplayName;
    _bioController.text = _originalBio;
    _favPlantController.text = _originalFavPlant;

    // Clear any newly selected image
    _newImageFile = null;

    setState(() {
      _isEditing = false;
    });
  }

  /// Shows the image in a full-screen modal when tapped.
  void _showImageModal(ImageProvider imageProvider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Profile Photo')),
          body: Center(
            child: Image(image: imageProvider, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  // --- Image Handling and Save (Modified) ---

  /// PICK IMAGE FROM GALLERY (only callable in edit mode)
  Future<void> _pickNewImage() async {
    if (!_isEditing) return; // Only allow picking if in edit mode

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      final File pickedFile = File(picked.path);

      final CroppedFile? croppedFile = await cropImage(context, pickedFile);

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
        base64Data = await convertAndCompressImage(_newImageFile, 256);
      }

      await _firestore.collection("users").doc(uid).set({
        "displayName": _displayNameController.text,
        "bio": _bioController.text,
        "favPlant": _favPlantController.text,
        // Only update photoUrl if a new image was selected
        if (_newImageFile != null) "photoUrl": base64Data,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _auth.currentUser!.updateDisplayName(_displayNameController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );

      // Successfully saved: Exit edit mode and clear local image reference
      setState(() {
        _newImageFile = null;
        _isEditing = false;
      });
    } catch (e) {
      print("❌ Error saving profile: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
    }

    setState(() => _saving = false);
  }

  // --- Build Method ---

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

          // Initial data loading for controllers if not in edit mode
          if (!_isEditing) {
            _displayNameController.text =
                (data["displayName"] ?? user.displayName ?? "");
            _bioController.text = (data["bio"] ?? "");
            _favPlantController.text = (data["favPlant"] ?? "");
          }

          final String? photoData = data["photoUrl"];
          ImageProvider imageProvider;

          if (_newImageFile != null) {
            imageProvider = FileImage(_newImageFile!);
          } else if (photoData != null && _isBase64(photoData)) {
            final base64String = photoData.split(',').last;
            final bytes = base64Decode(base64String);
            imageProvider = MemoryImage(bytes);
          } else {
            imageProvider = const AssetImage(
              "assets/images/user-placeholder.jpg",
            );
          }

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    /// --------------------------
                    /// PROFILE IMAGE
                    /// --------------------------
                    GestureDetector(
                      // 🚨 CHANGE: Tap handler for either modal or picker
                      onTap: _isEditing
                          ? _pickNewImage
                          : () => _showImageModal(imageProvider),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundImage: imageProvider,
                          ),
                          if (_isEditing)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// --------------------------
                    /// DISPLAY NAME FIELD
                    /// --------------------------
                    _buildTextField(
                      controller: _displayNameController,
                      label: "Display Name",
                      readOnly: !_isEditing,
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 16),

                    /// --------------------------
                    /// EMAIL FIELD (always read-only)
                    /// --------------------------
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

                    /// --------------------------
                    /// BIO FIELD
                    /// --------------------------
                    _buildTextField(
                      controller: _bioController,
                      label: "About You",
                      readOnly: !_isEditing,
                      maxLines: 3,
                      icon: Icons.info_outline,
                    ),
                    const SizedBox(height: 16),

                    /// --------------------------
                    /// FAVORITE PLANT FIELD
                    /// --------------------------
                    _buildTextField(
                      controller: _favPlantController,
                      label: "Favorite Plant",
                      readOnly: !_isEditing,
                      icon: Icons.local_florist,
                    ),

                    // Add space at the bottom to avoid FAB overlap
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              /// --------------------------
              /// FLOATING ACTION BUTTONS
              /// --------------------------
              if (_isEditing) ...[
                // Cancel Button (Bottom Left)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: FloatingActionButton(
                    heroTag: "cancelBtn",
                    onPressed: _saving ? null : _cancelEdit,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.cancel, color: Colors.white),
                  ),
                ),
                // Confirm/Save Button (Bottom Right)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: "saveBtn",
                    onPressed: _saving ? null : () => _saveProfile(user.uid),
                    backgroundColor: Colors.green,
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.check, color: Colors.white),
                  ),
                ),
              ] else
                // Edit Toggle Button (Bottom Right - View Mode)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: "editToggleBtn",
                    onPressed: () => _toggleEditMode(data),
                    child: const Icon(Icons.edit),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // --- Helper Widget for Fields ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool readOnly,
    IconData? icon,
    int maxLines = 1,
  }) {
    // If not readOnly, the controller will manage the value.
    // If readOnly, we use a simple Text or TextFormField for displaying.
    if (readOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$label:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              controller.text.isEmpty ? 'N/A' : controller.text,
              style: TextStyle(fontSize: 16),
            ),
            Divider(),
          ],
        ),
      );
    } else {
      return TextField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: const OutlineInputBorder(),
        ),
      );
    }
  }
}
