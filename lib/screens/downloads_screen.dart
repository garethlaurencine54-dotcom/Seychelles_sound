import 'package:flutter/material.dart';
import '../services/offline_cache_service.dart';
import '../services/music_service.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final OfflineCacheService _offlineCache = OfflineCacheService();
  late Future<List<DownloadedTrack>> _futureDownloads;

  @override
  void initState() {
    super.initState();
    _futureDownloads = _offlineCache.listDownloads();
  }

  void _refresh() {
    setState(() {
      _futureDownloads = _offlineCache.listDownloads();
    });
  }

  Future<void> _delete(DownloadedTrack track) async {
    await _offlineCache.deleteDownload(track.filename);
    _refresh();
  }

  // Builds a playable album+tracklist purely from what's downloaded for
  // that album, so tapping a song in this tab works fully offline —
  // it never needs to contact the server to know the track order.
  void _openTrack(List<DownloadedTrack> albumDownloads, int index) {
    final tracks = albumDownloads
        .map((d) => Track(
              id: d.filename,
              title: d.title,
              trackNumber: d.trackNumber,
              filename: d.filename,
              durationSecs: 0,
            ))
        .toList();

    final album = Album(
      id: albumDownloads.first.albumId,
      title: albumDownloads.first.albumTitle,
      coverUrl: albumDownloads.first.coverUrl,
      artistEmail: '',
      tracks: tracks,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(album: album, tracks: tracks, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Downloads', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[900],
        elevation: 0,
      ),
      body: FutureBuilder<List<DownloadedTrack>>(
        future: _futureDownloads,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }
          final downloads = snapshot.data ?? [];
          if (downloads.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'No downloaded songs yet.\nTap the download icon on any track to save it offline.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final Map<String, List<DownloadedTrack>> byAlbum = {};
          for (final t in downloads) {
            byAlbum.putIfAbsent(t.albumTitle, () => []).add(t);
          }
          // Keep each album's downloaded songs in track order.
          for (final list in byAlbum.values) {
            list.sort((a, b) => a.trackNumber.compareTo(b.trackNumber));
          }

          return ListView(
            children: byAlbum.entries.map((entry) {
              final albumDownloads = entry.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(entry.key,
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  ...List.generate(albumDownloads.length, (index) {
                    final track = albumDownloads[index];
                    return ListTile(
                      leading: const Icon(Icons.music_note, color: Colors.white54),
                      title: Text(track.title, style: const TextStyle(color: Colors.white)),
                      subtitle: const Text('Downloaded — available offline',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      onTap: () => _openTrack(albumDownloads, index),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _delete(track),
                        tooltip: 'Remove download',
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
