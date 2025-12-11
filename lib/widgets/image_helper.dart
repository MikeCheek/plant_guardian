import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import 'package:image_cropper/image_cropper.dart';

Future<String> convertAndCompressImage(File? file, int size) async {
  final List<int> imageBytes = await file!.readAsBytes();
  final img.Image? originalImage = img.decodeImage(
    Uint8List.fromList(imageBytes),
  );

  if (originalImage != null) {
    final img.Image resizedImage = img.copyResize(
      originalImage,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );
    final List<int> resizedBytes = img.encodeJpg(resizedImage, quality: 80);
    final String base64String = base64Encode(resizedBytes);
    String base64Data = 'data:image/jpeg;base64,$base64String';
    return base64Data;
  }
  return '';
}

Future<CroppedFile?> cropImage(BuildContext context, File file) async {
  return await ImageCropper().cropImage(
    sourcePath: file.path,
    aspectRatio: const CropAspectRatio(ratioX: 1.0, ratioY: 1.0),
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
}
