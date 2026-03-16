import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelUpdateHelper {
  final String manifestUrl;

  ModelUpdateHelper({required this.manifestUrl});

  Future<Map<String, dynamic>> updateAllModels() async {
    final prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    Map<String, dynamic> results = {};

    try {
      // 1. Fetch the single Manifest JSON
      final response = await http.get(Uri.parse(manifestUrl));
      if (response.statusCode != 200)
        throw Exception("Failed to load manifest");

      final Map<String, dynamic> manifest = json.decode(response.body);

      // 2. Process each model type defined in the JSON (species and disease)
      for (String type in manifest.keys) {
        final modelData = manifest[type];
        int remoteVersion = modelData['version'];
        int localVersion = prefs.getInt('${type}_version') ?? 0;

        File localModel = File('${dir.path}/${type}_model.tflite');
        File localLabel = File('${dir.path}/${type}_labels.txt');

        // 3. Update if version is newer or files are missing
        if (remoteVersion > localVersion ||
            !localModel.existsSync() ||
            !localLabel.existsSync()) {
          print("Updating $type model to version $remoteVersion...");

          final modelRes = await http.get(Uri.parse(modelData['model_url']));
          final labelRes = await http.get(Uri.parse(modelData['label_url']));

          if (modelRes.statusCode == 200 && labelRes.statusCode == 200) {
            await localModel.writeAsBytes(modelRes.bodyBytes);
            await localLabel.writeAsBytes(labelRes.bodyBytes);
            await prefs.setInt('${type}_version', remoteVersion);
          }
        }

        // Add the path to the results map
        results[type] = {
          'version': remoteVersion,
          'modelPath': localModel.path,
          'labelPath': localLabel.path,
          'isDownloaded': true,
        };
      }
    } catch (e) {
      print("Update error: $e. Falling back to assets.");
    }

    return results;
  }
}
