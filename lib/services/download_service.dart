import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DownloadService {
  final String backendUrl = "https://seyinfo.seychellesxstream.com";

  // Gets the absolute hidden system path where the app is allowed to store files securely
  Future<String> _getLocalPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Generates a local file reference based on the track's unique filename
  Future<File> _getLocalFile(String filename) async {
    final path = await _getLocalPath();
    return File('$path/$filename');
  }

  // Checks if a track has already been downloaded to the device
  Future<bool> isTrackDownloaded(String filename) async {
    try {
      final file = await _getLocalFile(filename);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  // Downloads the track from your DigitalOcean API and saves it into the hidden sandbox
  Future<bool> downloadTrack(String filename, String firebaseIdToken) async {
    try {
      final url = Uri.parse("$backendUrl/api/v1/download/$filename");
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $firebaseIdToken',
        },
      );

      if (response.statusCode == 200) {
        final file = await _getLocalFile(filename);
        // Write the raw bytes directly to hidden disk storage
        await file.writeAsBytes(response.bodyBytes);
        return true;
      } else {
        debugPrint("Failed to download track file: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      debugPrint("Error downloading track: $e");
      return false;
    }
  }

  // Gets the correct execution source (returns local file path if offline, server URL if online)
  Future<String> getPlaybackSource(String filename) async {
    final file = await _getLocalFile(filename);
    if (await file.exists()) {
      return file.path; // Local file path for offline playback
    }
    return "$backendUrl/api/v1/download/$filename"; // Fallback to live stream URL
  }
}

