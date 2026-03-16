import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plant_guardian/services/notification_service.dart';
import 'package:plant_guardian/widgets/garden_model.dart';
import 'package:plant_guardian/widgets/image_helper.dart';
import 'package:workmanager/workmanager.dart';

class UserScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const UserScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _favPlantController = TextEditingController();

  bool _dailyRemindersEnabled = false;
  bool _thirstyAlertsEnabled = false;

  bool _isEditing = false;

  String _originalDisplayName = '';
  String _originalBio = '';
  String _originalFavPlant = '';
  bool _originalDailyReminders = false;
  bool _originalThirstyAlerts = false;

  bool _saving = false;
  File? _newImageFile;

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

  void _toggleEditMode(Map<String, dynamic> currentData) {
    if (!_isEditing) {
      _originalDisplayName = _displayNameController.text;
      _originalBio = _bioController.text;
      _originalFavPlant = _favPlantController.text;
      _originalDailyReminders = _dailyRemindersEnabled;
      _originalThirstyAlerts = _thirstyAlertsEnabled;
    }
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _cancelEdit() {
    _displayNameController.text = _originalDisplayName;
    _bioController.text = _originalBio;
    _favPlantController.text = _originalFavPlant;
    _newImageFile = null;

    setState(() {
      _isEditing = false;
      _dailyRemindersEnabled = _originalDailyReminders;
      _thirstyAlertsEnabled = _originalThirstyAlerts;
    });
  }

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

  Future<void> _pickNewImage() async {
    if (!_isEditing) return;

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
        "dailyReminders": _dailyRemindersEnabled,
        "thirstyAlerts": _thirstyAlertsEnabled,
        if (_newImageFile != null) "photoUrl": base64Data,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _updateNotificationSchedules();
      await _auth.currentUser!.updateDisplayName(_displayNameController.text);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );

      setState(() {
        _newImageFile = null;
        _isEditing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error updating profile: $e")));
    }

    setState(() => _saving = false);
  }

  void _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/welcome');
  }

  Future<void> _updateNotificationSchedules() async {
    final service = NotificationService();
    final user = _auth.currentUser;

    if (user == null) return;

    if (_dailyRemindersEnabled) {
      await service.requestExactAlarmPermission();
      await service.scheduleDailyNotification(
        1,
        "Good Morning!",
        "Don't forget to check your plants today!",
        9,
        0,
      );
    } else {
      await service.notificationsPlugin.cancel(id: 1);
    }

    if (_thirstyAlertsEnabled) {
      await service.requestNotificationPermission();
      await checkWateringNeedsAndNotify(user.uid);
      await Workmanager().registerPeriodicTask(
        "watering-check-task",
        "checkWateringNeeds",
        frequency: const Duration(hours: 24),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } else {
      await Workmanager().cancelByUniqueName("watering-check-task");
      await service.notificationsPlugin.cancel(id: 100);
    }
  }

  Widget _buildProfileSection(
    Map<String, dynamic> data,
    ImageProvider imageProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Profile Information",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: _isEditing
                ? _pickNewImage
                : () => _showImageModal(imageProvider),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(radius: 60, backgroundImage: imageProvider),
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
        ),
        const SizedBox(height: 24),
        _buildTextField(
          controller: _displayNameController,
          label: "Display Name",
          readOnly: !_isEditing,
          icon: Icons.person,
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _auth.currentUser?.email,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: "Email",
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _bioController,
          label: "About You",
          readOnly: !_isEditing,
          maxLines: 3,
          icon: Icons.info_outline,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _favPlantController,
          label: "Favorite Plant",
          readOnly: !_isEditing,
          icon: Icons.local_florist,
        ),
      ],
    );
  }

  Widget _buildNotificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Notifications & Alerts",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text("Daily Care Reminders"),
                subtitle: const Text("Get a nudge at 9:00 AM every morning"),
                secondary: const Icon(Icons.alarm),
                value: _dailyRemindersEnabled,
                onChanged: _isEditing
                    ? (val) => setState(() => _dailyRemindersEnabled = val)
                    : null,
              ),
              const Divider(height: 0),
              SwitchListTile(
                title: const Text("Thirsty Plant Alerts"),
                subtitle: const Text("Notify when a plant needs watering"),
                secondary: const Icon(Icons.water_drop),
                value: _thirstyAlertsEnabled,
                onChanged: _isEditing
                    ? (val) => setState(() => _thirstyAlertsEnabled = val)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
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
      appBar: AppBar(
        title: const Text("User Profile"),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection("users").doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          if (!_isEditing) {
            _displayNameController.text =
                (data["displayName"] ?? user.displayName ?? "");
            _bioController.text = (data["bio"] ?? "");
            _favPlantController.text = (data["favPlant"] ?? "");
            _dailyRemindersEnabled = data["dailyReminders"] ?? false;
            _thirstyAlertsEnabled = data["thirstyAlerts"] ?? false;
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
                    _buildProfileSection(data, imageProvider),
                    const SizedBox(height: 32),
                    _buildNotificationSection(),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _signOut,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        "Sign Out",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              if (_isEditing) ...[
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required bool readOnly,
    IconData? icon,
    int maxLines = 1,
  }) {
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
              style: const TextStyle(fontSize: 16),
            ),
            const Divider(),
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
