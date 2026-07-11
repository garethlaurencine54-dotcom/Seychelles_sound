import 'package:flutter/material.dart';
import '../services/link_auth_service.dart';
import '../main.dart';

class LinkLoginScreen extends StatefulWidget {
  const LinkLoginScreen({super.key});

  @override
  State<LinkLoginScreen> createState() => _LinkLoginScreenState();
}

class _LinkLoginScreenState extends State<LinkLoginScreen> {
  final _linkAuth = LinkAuthService();
  final _linkIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isFirstTime = false;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitLogin() async {
    final linkId = _linkIdController.text.trim();
    final password = _passwordController.text;

    if (linkId.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Enter your Link ID and password.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _linkAuth.login(linkId, password);
    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationWrapper()),
      );
      return;
    }

    if (result.error == "no_password_set") {
      setState(() {
        _isFirstTime = true;
        _isLoading = false;
        _errorMessage = "First time using this ID — set a password below.";
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = result.error;
    });
  }

  Future<void> _submitSetupPassword() async {
    final linkId = _linkIdController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (linkId.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = "Fill in all fields.");
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = "Passwords do not match.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _linkAuth.setupPassword(linkId, password, confirm);
    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationWrapper()),
      );
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = result.error;
    });
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF7AABCC)),
      filled: true,
      fillColor: const Color(0xFF0C1C2E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060F1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.album_rounded, size: 72, color: Color(0xFF44C8C0)),
                const SizedBox(height: 24),
                const Text('Seychelles Sound',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                Text(
                  _isFirstTime
                      ? 'Create a password for this Link ID to finish pairing your account.'
                      : 'Enter the Link ID from your account on the website, plus your password.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF7AABCC), fontSize: 14),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _linkIdController,
                  enabled: !_isFirstTime,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Link ID'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(_isFirstTime ? 'New Password' : 'Password'),
                ),
                if (_isFirstTime) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Confirm Password'),
                  ),
                ],
                const SizedBox(height: 28),
                if (_isLoading)
                  const CircularProgressIndicator(color: Color(0xFF44C8C0))
                else
                  ElevatedButton(
                    onPressed: _isFirstTime ? _submitSetupPassword : _submitLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF44C8C0),
                      foregroundColor: const Color(0xFF030A10),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(_isFirstTime ? 'Create Password & Continue' : 'Access My Library'),
                  ),
                if (_isFirstTime)
                  TextButton(
                    onPressed: () => setState(() {
                      _isFirstTime = false;
                      _errorMessage = null;
                      _passwordController.clear();
                      _confirmController.clear();
                    }),
                    child: const Text('← Back', style: TextStyle(color: Color(0xFF7AABCC))),
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.amberAccent)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
