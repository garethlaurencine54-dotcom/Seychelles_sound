import 'package:flutter/material.dart';
import '../services/music_service.dart';
import '../services/offline_cache_service.dart';
import '../services/background_download_service.dart';
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
  final BackgroundDownloadService _backgroundDownloads = BackgroundDownloadService();

  final Set<String> _downloadedFilenames = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, void Function(double)> _progressCallbacks = {};
  final Map<String, void Function(bool)> _completionCallbacks = {};

  @override
  void initState() {
    super.initState();
    _checkExistingState();
  }

  Future<void> _checkExistingState() async {
    for (final track in widget.album.tracks) {
      final isDownloaded = await _offlineCache.isDownloaded(track.filename);
      if (isDownloaded) {
        if (mounted) setState(() => _downloadedFilenames.add(track.filename));
        continue;
      }
      // Reconnect to a download already running in the background — e.g.
      // you started it, left this screen, and just came back.
      if (_backgroundDownloads.isDownloading(track.filename)) {
        _attachListeners(track.filename);
        if (mounted) {
          setState(() => _downloadProgress[track.filename] = _backgroundDownloads.getProgress(track.filename));
        }
      }
    }
  }

  void _attachListeners(String filename) {
    if (_progressCallbacks.containsKey(filename)) return;

    void onProgress(double progress) {
      if (mounted) setState(() => _downloadProgress[filename] = progress);
    }

    void onDone(bool success) {
      if (mounted) {
        setState(() {
          _downloadProgress.remove(filename);
          if (success) _downloadedFilenames.add(filename);
        });
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download failed. Check your connection.')),
          );
        }
      }
      _progressCallbacks.remove(filename);
      _completionCallbacks.remove(filename);
    }

    _progressCallbacks[filename] = onProgress;
    _completionCallbacks[filename] = onDone;
    _backgroundDownloads.addProgressListener(filename, onProgress);
    _backgroundDownloads.addCompletionListener(filename, onDone);
  }

  Future<void> _downloadTrack(Track track) async {
    if (_downloadedFilenames.contains(track.filename) ||
        _downloadProgress.containsKey(track.filename)) {
      return;
    }

    setState(() => _downloadProgress[track.filename] = 0.0);
    _attachListeners(track.filename);

    await _backgroundDownloads.startDownload(
      filename: track.filename,
      title: track.title,
      trackNumber: track.trackNumber,
      albumId: widget.album.id,
      albumTitle: widget.album.title,
      coverUrl: widget.album.coverUrl,
    );
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
  void dispose() {
    for (final entry in _progressCallbacks.entries) {
      _backgroundDownloads.removeProgressListener(entry.key, entry.value);
    }
    for (final entry in _completionCallbacks.entries) {
      _backgroundDownloads.removeCompletionListener(entry.key, entry.value);
    }
    super.dispose();
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
                final progress = _downloadProgress[track.filename];

                return ListTile(
                  leading: Text('${track.trackNumber}', style: const TextStyle(color: Colors.grey)),
                  title: Text(track.title, style: const TextStyle(color: Colors.white)),
                  onTap: () => _openTrack(index),
                  trailing: progress != null
                      ? SizedBox(
                          width: 36,
                          height: 36,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress > 0 ? progress : null,
                                strokeWidth: 2,
                                color: Colors.amber,
                              ),
                              if (progress > 0)
                                Text('${(progress * 100).toInt()}',
                                    style: const TextStyle(fontSize: 9, color: Colors.amber)),
                            ],
                          ),
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
