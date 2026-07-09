import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/library_screen.dart';
import 'screens/upload_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SeychellesSoundApp());
}

class SeychellesSoundApp extends StatelessWidget {
  const SeychellesSoundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seychelles Sound',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF060F1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF44C8C0),
          secondary: Color(0xFF2CB8A0),
          surface: Color(0xFF0C1C2E),
        ),
        fontFamily: 'Inter',
      ),
      home: const MainNavigationWrapper(),
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;
  String _liveToken = "loading_token...";

  @override
  void initState() {
    super.initState();
    _fetchFirebaseToken();
  }

  Future<void> _fetchFirebaseToken() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String? token = await user.getIdToken();
        if (token != null) {
          setState(() {
            _liveToken = token;
          });
        }
      } else {
        setState(() {
          _liveToken = "no_user_logged_in";
        });
      }
    } catch (e) {
      setState(() {
        _liveToken = "error_fetching_token";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const LibraryScreen(),
      const Center(child: Text('Marketplace Grid Coming Soon', style: TextStyle(color: Color(0xFF7AABCC)))),
      UploadScreen(firebaseIdToken: _liveToken),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF030A10),
        selectedItemColor: const Color(0xFF44C8C0),
        unselectedItemColor: const Color(0xFF7AABCC),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.library_music_rounded), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'Marketplace'),
          BottomNavigationBarItem(icon: Icon(Icons.mic_external_on_rounded), label: 'Artist Portal'),
        ],
      ),
    );
  }
}

