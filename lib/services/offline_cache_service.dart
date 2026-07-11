import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as enc;

class DownloadedTrack {
  final String filename;
  final String title;
  final int trackNumber;
  final String albumId;
  final String albumTitle;
  final String coverUrl;

  DownloadedTrack({
    required this.filename,
    required this.title,
    required this.trackNumber,
    required this.albumId,
    required this.albumTitle,
    required this.coverUrl,
  });

  factory DownloadedTrack.fromJson(String filename, Map<String, dynamic> json) {
    return DownloadedTrack(
      filename: filename,
      title: json['title'] ?? 'Unknown Title',
      trackNumber: json['track_number'] ?? 1,
      albumId: json['album_id'] ?? '',
      albumTitle: json['album_title'] ?? 'Unknown Album',
      coverUrl: json['cover_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'track_number': trackNumber,
        'album_id': albumId,
        'album_title': albumTitle,
        'cover_url': coverUrl,
      };
}

/// Handles offline downloads. Every track is AES-encrypted before it's
/// ever written to disk, and only decrypted straight into memory the
/// moment it's played — the readable audio never exists as a file.
class OfflineCacheService {
  static const _storage = FlutterSecureStorage();
  static const _keyStorageKey = 'offline_aes_key';

  Future<Directory> _privateDir() async {
    final dir = await getApplicationSupportDirectory();
    final offlineDir = Directory('${dir.path}/offline_tracks');
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }
    return offlineDir;
  }

  Future<File> _manifestFile() async {
    final dir = await _privateDir();
    return File('${dir.path}/manifest.json');
  }

  Future<File> _encryptedFile(String filename) async {
    final dir = await _privateDir();
    return File('${dir.path}/$filename.enc');
  }

  Future<enc.Key> _getOrCreateKey() async {
    final existing = await _storage.read(key: _keyStorageKey);
    if (existing != null) {
      return enc.Key.fromBase64(existing);
    }
    final newKey = enc.Key.fromSecureRandom(32);
    await _storage.write(key: _keyStorageKey, value: newKey.base64);
    return newKey;
  }

  Future<Map<String, dynamic>> _readManifest() async {
    final file = await _manifestFile();
    if (!await file.exists()) return {};
    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) return {};
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeManifest(Map<String, dynamic> manifest) async {
    final file = await _manifestFile();
    await file.writeAsString(jsonEncode(manifest));
  }

  Future<bool> isDownloaded(String filename) async {
    final file = await _encryptedFile(filename);
    return file.exists();
  }

  /// Encrypts and saves a track. [plainBytes] only ever lives in memory —
  /// what's written to disk is ciphertext, not the playable MP3.
  Future<void> downloadTrack({
    required String filename,
    required Uint8List plainBytes,
    required String title,
    required int trackNumber,
    required String albumId,
    required String albumTitle,
    required String coverUrl,
  }) async {
    final key = await _getOrCreateKey();
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    // Store IV + ciphertext together. The IV isn't secret, just unique per file.
    final combined = Uint8List.fromList(iv.bytes + encrypted.bytes);
    final file = await _encryptedFile(filename);
    await file.writeAsBytes(combined);

    final manifest = await _readManifest();
    manifest[filename] = DownloadedTrack(
      filename: filename,
      title: title,
      trackNumber: trackNumber,
      albumId: albumId,
      albumTitle: albumTitle,
      coverUrl: coverUrl,
    ).toJson();
    await _writeManifest(manifest);
  }

  /// Decrypts a downloaded track fully into memory for playback.
  /// Nothing plaintext is ever written back to disk.
  Future<Uint8List> getDecryptedBytes(String filename) async {
    final key = await _getOrCreateKey();
    final file = await _encryptedFile(filename);
    final combined = await file.readAsBytes();

    final iv = enc.IV(combined.sublist(0, 16));
    final cipherBytes = combined.sublist(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  Future<void> deleteDownload(String filename) async {
    final file = await _encryptedFile(filename);
    if (await file.exists()) await file.delete();

    final manifest = await _readManifest();
    manifest.remove(filename);
    await _writeManifest(manifest);
  }

  Future<List<DownloadedTrack>> listDownloads() async {
    final manifest = await _readManifest();
    return manifest.entries
        .map((e) => DownloadedTrack.fromJson(e.key, e.value as Map<String, dynamic>))
        .toList();
  }
}
