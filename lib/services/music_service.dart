import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'link_auth_service.dart';

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
  final String backendUrl = "https://seyinfo.seychellesxstream.com";
  final LinkAuthService _linkAuth = LinkAuthService();

  /// Fetches everything the signed-in Link ID owns.
  Future<List<Album>> fetchUserLibrary() async {
    try {
      final token = await _linkAuth.getSavedToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse("$backendUrl/api/v1/link/user-library"),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
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

  /// Streaming URL for live playback — used both for online play and
  /// as the one-time source for a download.
  String getStreamUrl(String filename) => "$backendUrl/api/v1/link/stream/$filename";

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await _linkAuth.getSavedToken();
    return {'Authorization': 'Bearer ${token ?? ''}'};
  }

  /// Fetches the raw bytes of a track once, so they can be encrypted
  /// and saved for offline playback. Returns null on failure.
  Future<Uint8List?> fetchTrackBytes(String filename) async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(Uri.parse(getStreamUrl(filename)), headers: headers);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      debugPrint("Download failed with status: ${response.statusCode}");
      return null;
    } catch (e) {
      debugPrint("Error fetching track bytes: $e");
      return null;
    }
  }
}
