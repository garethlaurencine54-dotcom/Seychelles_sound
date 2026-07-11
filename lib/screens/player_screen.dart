import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/music_service.dart';

class PlayerScreen extends StatefulWidget {
  final Album album;
  final Track track;

  const PlayerScreen({super.key, required this.album, required this.track});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final MusicService _musicService = MusicService();

  bool _isPlaying = false;
  bool _isLoadingAudio = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  // Streams the track live from the server every time — nothing is ever
  // written to the device's storage. Auth is a signed Link session token
  // sent as a header, verified fresh by the server on every request.
  Future<void> _initAudio() async {
    try {
      final headers = await _musicService.getAuthHeaders();
      final url = _musicService.getStreamUrl(widget.track.filename);

      await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(url), headers: headers));

      _audioPlayer.durationStream.listen((d) {
        if (mounted) setState(() => _duration = d ?? Duration.zero);
      });
      _audioPlayer.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) setState(() => _isPlaying = state.playing);
      });

      if (mounted) setState(() => _isLoadingAudio = false);
      _audioPlayer.play();
    } catch (e) {
      debugPrint("Error loading audio stream: $e");
      if (mounted) setState(() => _isLoadingAudio = false);
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
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(20),
                image: widget.album.coverUrl.isNotEmpty
                    ? DecorationImage(image: NetworkImage("${_musicService.backendUrl}${widget.album.coverUrl}"), fit: BoxFit.cover)
                    : null,
              ),
              child: widget.album.coverUrl.isEmpty
                  ? const Icon(Icons.music_note, size: 100, color: Colors.amber)
                  : null,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.track.title,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(widget.album.artistEmail, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                ),
                if (_isLoadingAudio)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2))
                else
                  const Icon(Icons.stream_rounded, color: Colors.amber, size: 24),
              ],
            ),
            const SizedBox(height: 24),
            Slider(
              activeColor: Colors.amber,
              inactiveColor: Colors.grey[800],
              min: 0.0,
              max: safeMax,
              value: safeValue,
              onChanged: (value) => _audioPlayer.seek(Duration(milliseconds: value.toInt())),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: const Icon(Icons.skip_previous, size: 36, color: Colors.white), onPressed: () {}),
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
                IconButton(icon: const Icon(Icons.skip_next, size: 36, color: Colors.white), onPressed: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
