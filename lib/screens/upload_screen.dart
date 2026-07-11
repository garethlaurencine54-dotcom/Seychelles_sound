import 'package:flutter/material.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artist Upload Portal', style: TextStyle(fontFamily: 'Fraunces')),
        backgroundColor: const Color(0xFF030A10),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_rounded, size: 64, color: Color(0xFF2CB8A0)),
              SizedBox(height: 16),
              Text('Album uploads are managed from the artist dashboard on the website for now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
