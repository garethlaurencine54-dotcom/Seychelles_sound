import 'package:flutter/material.dart';
import '../services/music_service.dart';
import '../services/link_auth_service.dart';
import 'player_screen.dart';
import 'link_login_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final MusicService musicService = MusicService();
  final LinkAuthService linkAuth = LinkAuthService();
  late Future<List<Album>> futureLibrary;

  @override
  void initState() {
    super.initState();
    futureLibrary = musicService.fetchUserLibrary();
  }

  Future<void> _logout() async {
    await linkAuth.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LinkLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('My Library', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded), tooltip: 'Sign out', onPressed: _logout),
        ],
      ),
      body: FutureBuilder<List<Album>>(
        future: futureLibrary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          } else if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No music found in your collection.', style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          final albums = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.75,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return GestureDetector(
                onTap: () {
                  if (album.tracks.isNotEmpty) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => PlayerScreen(album: album, track: album.tracks.first),
                    ));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('This album has no tracks available.')),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            image: album.coverUrl.isNotEmpty
                                ? DecorationImage(image: NetworkImage("${musicService.backendUrl}${album.coverUrl}"), fit: BoxFit.cover)
                                : null,
                          ),
                          child: album.coverUrl.isEmpty
                              ? const Center(child: Icon(Icons.album, size: 64, color: Colors.amber))
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(album.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
