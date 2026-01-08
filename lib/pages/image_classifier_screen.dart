import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:plant_guardian/pages/plant_info_screen.dart';
import '../TFLiteHelper.dart';
import 'package:plant_guardian/widgets/garden_model.dart';

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

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late Future<void> _plantsFuture;

  @override
  void initState() {
    super.initState();
    _plantsFuture = fetchAndCacheAvailablePlants(_firestore);
  }

  Future<(String, double)> _classifyImage(File image) async {
    try {
      return await TFLiteHelper.classifyImage(image);
    } catch (e) {
      throw Exception("Classification failed: $e");
    }
  }

  Future<void> _processImage(XFile pickedFile) async {
    setState(() {
      _image = File(pickedFile.path);
      _isLoading = true;
      _result = '';
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
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) await _processImage(pickedFile);
  }

  Future<void> _takePicture() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile != null) await _processImage(pickedFile);
  }

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

  void _navigateToDetails(String plantName) {
    final plant = getPlantByName(plantName);
    if (plant != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PlantInfoScreen(plantDbId: plant.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Plant details not found in database.")),
      );
    }
  }

  // 🪴 Logic to add the identified plant to the user's first garden
  void _confirmAddToGarden(String plantName) async {
    final plantDb = getPlantByName(plantName);

    if (plantDb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cannot add: Plant not in our database.")),
      );
      return;
    }

    // showDialog(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     title: const Text("Add to Garden?"),
    //     content: Text("Add this $plantName to your digital garden layout?"),
    //     actions: [
    //       TextButton(
    //         onPressed: () => Navigator.pop(context),
    //         child: const Text("CANCEL"),
    //       ),
    //       ElevatedButton(
    //         onPressed: () async {
    //           Navigator.pop(context); // Close dialog
    //           await _executeAddToGarden(plantDb);
    //         },
    //         child: const Text("ADD NOW"),
    //       ),
    //     ],
    //   ),
    // );
    await _executeAddToGarden(plantDb);
  }

  Future<void> _executeAddToGarden(PlantDB plantDb) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final query = gardensStream(user.uid, _firestore);

      setState(() => _isLoading = false);

      final List<Garden> userGardens = await query.first;

      if (userGardens.isEmpty) {
        _showNoGardenDialog();
        return;
      }

      // 2. Let the user select a garden
      final Garden? selectedGarden = await showDialog<Garden>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Select a Garden"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: userGardens.length,
              itemBuilder: (context, index) {
                final garden = userGardens[index];
                return ListTile(
                  leading: const Icon(Icons.yard_outlined, color: Colors.green),
                  title: Text(garden.name),
                  subtitle: Text("${garden.plants.length} plants"),
                  onTap: () => Navigator.pop(context, garden),
                );
              },
            ),
          ),
        ),
      );

      // 3. If a garden was selected, add the plant
      if (selectedGarden != null) {
        setState(() => _isLoading = true);

        final newInstance = PlantInstance(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          plantDbId: plantDb.id,
          position: Offset(
            100 + Random().nextDouble() * 50,
            100 + Random().nextDouble() * 50,
          ),
          scale: 1.5,
        );

        selectedGarden.plants.add(newInstance);

        // 4. Use your defined saveGarden function
        // Note: saveGarden already handles the Firestore path and Navigator.pop(context)
        await saveGarden(user, selectedGarden, _firestore, context);

        openGardenEditor(context, selectedGarden);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

  // Helper for when no gardens exist
  void _showNoGardenDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("No Garden Found"),
        content: const Text(
          "You need to create a garden layout before you can add plants to it.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _plantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Stack(
            children: [
              Column(
                children: [
                  // Header Section with Thumbnail
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImageThumbnail(),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Identify a Plant",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Take a photo or select from your gallery.",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: LinearProgressIndicator(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),

                  // Main Result Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildResultContent(),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showImageSourceDialog(context),
        backgroundColor: Colors.green[800],
        label: const Text(
          'Identify New Plant',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        icon: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // 🖼️ Smaller Thumbnail UI
  Widget _buildImageThumbnail() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _image != null
            ? Image.file(_image!, fit: BoxFit.cover)
            : Icon(Icons.image_search, size: 40, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildResultContent() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: const Center(
          child: Text(
            "Processing image...",
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    if (_score == null) {
      return _buildEmptyState();
    }

    final double percentage = _score! * 100;
    Color statusColor = _getStatusColor(percentage);

    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statusColor.withOpacity(0.2), width: 2),
          ),
          child: Column(
            children: [
              // Confidence Circle
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _score,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  Text(
                    "${percentage.toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Plant Name with "Info" Trigger
              InkWell(
                onTap: () => _navigateToDetails(_result),
                child: Column(
                  children: [
                    Text(
                      _result.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          "View Plant Details",
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.grey[200]),
              const SizedBox(height: 10),
              Text(
                _getMessage(percentage),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        if (percentage >= 50)
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: () => _confirmAddToGarden(_result),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text(
                "Add to a Garden",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
      ],
    );
  }

  // --- Helper Methods ---

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Icon(Icons.psychology_outlined, size: 100, color: Colors.grey[300]),
        const SizedBox(height: 20),
        Text(
          "Ready to scan!",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
          ),
        ),
        Text(
          "Take a photo of a leaf or your full plant to begin identification.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400]),
        ),
      ],
    );
  }

  Color _getStatusColor(double percentage) {
    if (percentage >= 90) return Colors.green[700]!;
    if (percentage >= 70) return Colors.orange[800]!;
    if (percentage >= 50) return Colors.red[400]!;
    return Colors.grey[700]!;
  }

  String _getMessage(double percentage) {
    if (percentage >= 90) {
      return "High match! I am confident about this species.";
    }
    if (percentage >= 70) {
      return "Likely a match. Check the details to confirm.";
    }
    if (percentage >= 50) {
      return "Low confidence. Ensure the photo is clear and well-lit.";
    }
    return "Are you sure this is a plant?";
  }
}
