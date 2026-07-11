import 'package:flutter/material.dart';
import '../services/music_service.dart';
import '../services/offline_cache_service.dart';
import 'player_screen.dart';

class AlbumTracksScreen extends StatefulWidget {
  final Album album;
  const AlbumTracksScreen({super.key, required this.album});

  @override
  State<AlbumTracksScreen> createState() => _AlbumTracksScreenState();
}

class _AlbumTracksScreenState extends State<AlbumTracksScreen> {
  final MusicService _musicService = MusicService();
  final OfflineCacheService _offlineCache = OfflineCacheService();

  final Set<String> _downloadedFilenames = {};
  final Set<String> _downloadingFilenames = {};

  @override
  void initState() {
    super.initState();
    _checkDownloadedStatus();
  }

  Future<void> _checkDownloadedStatus() async {
    for (final track in widget.album.tracks) {
      final isDownloaded = await _offlineCache.isDownloaded(track.filename);
      if (isDownloaded && mounted) {
        setState(() => _downloadedFilenames.add(track.filename));
      }
    }
  }

  Future<void> _downloadTrack(Track track) async {
    if (_downloadedFilenames.contains(track.filename) ||
        _downloadingFilenames.contains(track.filename)) {
      return;
    }

    setState(() => _downloadingFilenames.add(track.filename));

    final bytes = await _musicService.fetchTrackBytes(track.filename);

    if (bytes != null) {
      await _offlineCache.downloadTrack(
        filename: track.filename,
        plainBytes: bytes,
        title: track.title,
        trackNumber: track.trackNumber,
        albumId: widget.album.id,
        albumTitle: widget.album.title,
        coverUrl: widget.album.coverUrl,
      );
      if (mounted) {
        setState(() {
          _downloadingFilenames.remove(track.filename);
          _downloadedFilenames.add(track.filename);
        });
      }
    } else {
      if (mounted) {
        setState(() => _downloadingFilenames.remove(track.filename));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed. Check your connection.')),
        );
      }
    }
  }

  void _openTrack(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          album: widget.album,
          tracks: widget.album.tracks,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.album.title),
        backgroundColor: Colors.grey[900],
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(14),
                image: widget.album.coverUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage("${_musicService.backendUrl}${widget.album.coverUrl}"),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: widget.album.coverUrl.isEmpty
                  ? const Icon(Icons.album, size: 64, color: Colors.amber)
                  : null,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.album.tracks.length,
              itemBuilder: (context, index) {
                final track = widget.album.tracks[index];
                final isDownloaded = _downloadedFilenames.contains(track.filename);
                final isDownloading = _downloadingFilenames.contains(track.filename);

                return ListTile(
                  leading: Text('${track.trackNumber}', style: const TextStyle(color: Colors.grey)),
                  title: Text(track.title, style: const TextStyle(color: Colors.white)),
                  onTap: () => _openTrack(index),
                  trailing: isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                        )
                      : IconButton(
                          icon: Icon(
                            isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                            color: isDownloaded ? Colors.greenAccent : Colors.amber,
                          ),
                          onPressed: isDownloaded ? null : () => _downloadTrack(track),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
