import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/music_service.dart';
import '../services/offline_cache_service.dart';

/// Feeds already-decrypted bytes straight to the player from memory —
/// no plaintext file is ever written to disk for a downloaded track.
class _InMemoryAudioSource extends StreamAudioSource {
  final Uint8List bytes;
  _InMemoryAudioSource(this.bytes) : super(tag: 'offline_track');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/mpeg',
    );
  }
}

class PlayerScreen extends StatefulWidget {
  final Album album;
  final List<Track> tracks;
  final int initialIndex;

  const PlayerScreen({
    super.key,
    required this.album,
    required this.tracks,
    required this.initialIndex,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final MusicService _musicService = MusicService();
  final OfflineCacheService _offlineCache = OfflineCacheService();

  late int _currentIndex;
  bool _isPlaying = false;
  bool _isLoadingAudio = true;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  Track get _currentTrack => widget.tracks[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _duration = d ?? Duration.zero);
    });
    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
    });

    _loadTrack(_currentIndex);
  }

  Future<void> _loadTrack(int index) async {
    setState(() {
      _isLoadingAudio = true;
      _duration = Duration.zero;
      _position = Duration.zero;
    });

    final track = widget.tracks[index];
    final isDownloaded = await _offlineCache.isDownloaded(track.filename);

    try {
      if (isDownloaded) {
        // Decrypted straight into memory — never written back to disk as plaintext.
        final bytes = await _offlineCache.getDecryptedBytes(track.filename);
        await _audioPlayer.setAudioSource(_InMemoryAudioSource(bytes));
      } else {
        final headers = await _musicService.getAuthHeaders();
        final url = _musicService.getStreamUrl(track.filename);
        await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url), headers: headers));
      }

      if (mounted) {
        setState(() {
          _isDownloaded = isDownloaded;
          _isLoadingAudio = false;
        });
      }
      _audioPlayer.play();
    } catch (e) {
      debugPrint("Error loading track: $e");
      if (mounted) setState(() => _isLoadingAudio = false);
    }
  }

  Future<void> _downloadCurrentTrack() async {
    if (_isDownloaded || _isDownloading) return;
    setState(() => _isDownloading = true);

    final bytes = await _musicService.fetchTrackBytes(_currentTrack.filename);
    if (bytes != null) {
      await _offlineCache.downloadTrack(
        filename: _currentTrack.filename,
        plainBytes: bytes,
        title: _currentTrack.title,
        trackNumber: _currentTrack.trackNumber,
        albumId: widget.album.id,
        albumTitle: widget.album.title,
        coverUrl: widget.album.coverUrl,
      );
      if (mounted) {
        setState(() {
          _isDownloaded = true;
          _isDownloading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed. Check your connection.')),
        );
      }
    }
  }

  void _playNext() {
    if (_currentIndex < widget.tracks.length - 1) {
      setState(() => _currentIndex++);
      _loadTrack(_currentIndex);
    }
  }

  void _playPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _loadTrack(_currentIndex);
    }
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeMax = _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0;
    final safeValue = _position.inMilliseconds.toDouble().clamp(0.0, safeMax);
    final hasNext = _currentIndex < widget.tracks.length - 1;
    final hasPrevious = _currentIndex > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.album.title, style: const TextStyle(fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                image: widget.album.coverUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage("${_musicService.backendUrl}${widget.album.coverUrl}"),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: widget.album.coverUrl.isEmpty
                  ? const Icon(Icons.music_note, size: 100, color: Colors.amber)
                  : null,
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_currentTrack.title,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('Track ${_currentTrack.trackNumber} of ${widget.tracks.length}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
                if (_isLoadingAudio || _isDownloading)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2))
                else
                  IconButton(
                    icon: Icon(
                      _isDownloaded ? Icons.download_done_rounded : Icons.download_rounded,
                      color: _isDownloaded ? Colors.greenAccent : Colors.amber,
                    ),
                    onPressed: _isDownloaded ? null : _downloadCurrentTrack,
                    tooltip: _isDownloaded ? 'Downloaded for offline playback' : 'Download for offline playback',
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Slider(
              activeColor: Colors.amber,
              inactiveColor: Colors.grey[800],
              min: 0.0,
              max: safeMax,
              value: safeValue,
              onChanged: (value) => _audioPlayer.seek(Duration(milliseconds: value.toInt())),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous, size: 36, color: hasPrevious ? Colors.white : Colors.grey[800]),
                  onPressed: hasPrevious ? _playPrevious : null,
                ),
                const SizedBox(width: 24),
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.amber,
                  child: IconButton(
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 36, color: Colors.black),
                    onPressed: _togglePlayPause,
                  ),
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: Icon(Icons.skip_next, size: 36, color: hasNext ? Colors.white : Colors.grey[800]),
                  onPressed: hasNext ? _playNext : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
