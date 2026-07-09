import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Track {
  final String id;
  final String title;
  final int trackNumber;
  final String filename;
  final int durationSecs;

  Track({
    required this.id,
    required this.title,
    required this.trackNumber,
    required this.filename,
    required this.durationSecs,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'].toString(),
      title: json['title'] ?? 'Unknown Title',
      trackNumber: json['track_number'] ?? 1,
      filename: json['filename'] ?? '',
      durationSecs: json['duration_secs'] ?? 0,
    );
  }
}

class Album {
  final String id;
  final String title;
  final String coverUrl;
  final String artistEmail;
  final List<Track> tracks;

  Album({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.artistEmail,
    required this.tracks,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    var list = json['tracks'] as List? ?? [];
    List<Track> trackList = list.map((i) => Track.fromJson(i)).toList();

    return Album(
      id: json['id'].toString(),
      title: json['title'] ?? 'Unknown Album',
      coverUrl: json['cover_url'] ?? '',
      artistEmail: json['artist_email'] ?? '',
      tracks: trackList,
    );
  }
}

class MusicService {
  // Replace with your live DigitalOcean IP or your custom domain!
  final String backendUrl = "http://YOUR_DIGITALOCEAN_IP:5000";

  // Fetches all albums and tracks the user owns using their secure Firebase ID token
  Future<List<Album>> fetchUserLibrary(String firebaseIdToken) async {
    try {
      final response = await http.get(
        Uri.parse("$backendUrl/api/v1/user-library"),
        headers: {
          'Authorization': 'Bearer $firebaseIdToken',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        List<dynamic> libraryData = data['library'] ?? [];
        return libraryData.map((item) => Album.fromJson(item)).toList();
      } else {
        debugPrint("Server error pulling library: ${response.body}");
        return [];
      }
    } catch (e) {
      debugPrint("Network error connecting to library API: $e");
      return [];
    }
  }

  // Gets the exact stream URL for a track file
  String getStreamUrl(String filename) {
    return "$backendUrl/api/v1/download/$filename";
  }
}

