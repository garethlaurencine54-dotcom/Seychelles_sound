import 'package:flutter/material.dart';

class UploadScreen extends StatelessWidget {
  final String firebaseIdToken;

  // No 'required' keyword, defaults to an empty string if not passed!
  const UploadScreen({super.key, this.firebaseIdToken = ""});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artist Upload Portal', style: TextStyle(fontFamily: 'Fraunces')),
        backgroundColor: const Color(0xFF030A10),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_rounded, size: 64, color: Color(0xFF2CB8A0)),
            const SizedBox(height: 16),
            const Text('Upload Panel Ready', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Token State: $firebaseIdToken', style: const TextStyle(color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

