import 'package:flutter/material.dart';
import 'screens/library_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/link_login_screen.dart';
import 'services/link_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const SessionGate(),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  final _linkAuth = LinkAuthService();
  bool _checking = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await _linkAuth.getSavedToken();
    if (mounted) {
      setState(() {
        _hasSession = token != null && token.isNotEmpty;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF060F1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF44C8C0))),
      );
    }
    return _hasSession ? const MainNavigationWrapper() : const LinkLoginScreen();
  }
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const LibraryScreen(),
      const DownloadsScreen(),
      const Center(child: Text('Marketplace Grid Coming Soon', style: TextStyle(color: Color(0xFF7AABCC)))),
      const UploadScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF030A10),
        selectedItemColor: const Color(0xFF44C8C0),
        unselectedItemColor: const Color(0xFF7AABCC),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.library_music_rounded), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.download_done_rounded), label: 'Downloads'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'Marketplace'),
          BottomNavigationBarItem(icon: Icon(Icons.mic_external_on_rounded), label: 'Artist Portal'),
        ],
      ),
    );
  }
}
