import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/music_service.dart';
import 'player_screen.dart';

class LibraryScreen extends StatefulWidget {
  final String firebaseIdToken;

  const LibraryScreen({super.key, required this.firebaseIdToken});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final MusicService musicService = MusicService();
  late Future<List<Album>> futureLibrary;

  @override
  void initState() {
    super.initState();
    // Instantly load the user's secure media library on startup
    futureLibrary = musicService.fetchUserLibrary(widget.firebaseIdToken);
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
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              await GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
              // authStateChanges() in main.dart automatically returns
              // the user to SignInScreen once this completes.
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Album>>(
        future: futureLibrary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          } else if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No music found in your collection.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          final albums = snapshot.data!;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return GestureDetector(
                onTap: () {
                  // If the album has tracks, instantly load up the player screen for track 1
                  if (album.tracks.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlayerScreen(album: album, track: album.tracks.first),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('This album has no tracks available.')),
                    );
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            image: album.coverUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage("${musicService.backendUrl}${album.coverUrl}"),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: album.coverUrl.isEmpty
                              ? const Center(child: Icon(Icons.album, size: 64, color: Colors.amber))
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          album.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

