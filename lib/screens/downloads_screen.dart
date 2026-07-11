import 'package:flutter/material.dart';
import '../services/offline_cache_service.dart';

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

          return ListView(
            children: byAlbum.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(entry.key,
                        style: const TextStyle(
                            color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  ...entry.value.map((track) => ListTile(
                        leading: const Icon(Icons.music_note, color: Colors.white54),
                        title: Text(track.title, style: const TextStyle(color: Colors.white)),
                        subtitle: const Text('Downloaded — available offline',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _delete(track),
                          tooltip: 'Remove download',
                        ),
                      )),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
