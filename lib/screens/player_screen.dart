import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/music_service.dart';
import '../services/download_service.dart';

class PlayerScreen extends StatefulWidget {
  final Album album;
  final Track track;

  const PlayerScreen({super.key, required this.album, required this.track});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final DownloadService _downloadService = DownloadService();
  
  bool _isPlaying = false;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _checkOfflineStatus();
  }

  // Check if this specific track is already saved locally on the device
  Future<void> _checkOfflineStatus() async {
    bool downloaded = await _downloadService.isTrackDownloaded(widget.track.filename);
    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
      });
    }
  }

  // Initialize audio source (uses local sandbox file if downloaded, hits live droplet if not)
  Future<void> _initAudio() async {
    try {
      String source = await _downloadService.getPlaybackSource(widget.track.filename);
      
      if (source.startsWith('http')) {
        await _audioPlayer.setUrl(source);
      } else {
        await _audioPlayer.setFilePath(source);
      }

      _audioPlayer.durationStream.listen((d) {
        if (mounted) setState(() => _duration = d ?? Duration.zero);
      });

      _audioPlayer.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() => _isPlaying = state.playing);
        }
      });
    } catch (e) {
      print("Error loading audio source: $e");
    }
  }

  // Trigger file download into the hidden sandbox storage
  Future<void> _startSecureDownload() async {
    if (_isDownloaded || _isDownloading) return;

    setState(() => _isDownloading = true);
    
    // Using a placeholder token string—wire real Firebase ID token here when auth is live
    bool success = await _downloadService.downloadTrack(widget.track.filename, "YOUR_FIREBASE_TOKEN");

    if (mounted) {
      setState(() {
        _isDownloading = false;
        if (success) {
          _isDownloaded = true;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Downloaded securely for offline playback!' : 'Download failed.'),
        ),
      );
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
            // Album Art
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                image: widget.album.coverUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage("https://seyinfo.seychellesxstream.com/${widget.album.coverUrl}"),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.album.coverUrl.isEmpty
                  ? const Icon(Icons.music_note, size: 100, color: Colors.amber)
                  : null,
            ),
            const SizedBox(height: 32),
            // Track Info & Download Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.title,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.album.artistEmail,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                _isDownloading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(
                          _isDownloaded ? Icons.check_circle : Icons.download_for_offline,
                          color: _isDownloaded ? Colors.green : Colors.amber,
                          size: 28,
                        ),
                        onPressed: _startSecureDownload,
                      ),
              ],
            ),
            const SizedBox(height: 24),
            // Progress Bar Slider
            Slider(
              activeColor: Colors.amber,
              inactiveColor: Colors.grey[800],
              min: 0.0,
              max: _duration.inMilliseconds.toDouble(),
              value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
              onChanged: (value) {
                _audioPlayer.seek(Duration(milliseconds: value.toInt()));
              },
            ),
            const SizedBox(height: 32),
            // Main Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white),
                  onPressed: () {},
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
                  icon: const Icon(Icons.skip_next, size: 36, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

