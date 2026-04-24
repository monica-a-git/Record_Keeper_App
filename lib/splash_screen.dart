import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'index.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String _authStatus = "Initializing Secure Vault...";

  @override
  void initState() {
    super.initState();
    // Start authentication after a small delay to show the logo
    Future.delayed(const Duration(seconds: 2), () {
      _authenticate();
    });
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
        _authStatus = "Authenticating...";
      });

      // Check if biometrics are supported on this device
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        // If device has no security (No PIN/No Biometrics), skip to app
        _navigateToDashboard();
        return;
      }

      authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access your sheets',
        options: const AuthenticationOptions(
          stickyAuth: true, // Keeps auth alive if app goes to background
          biometricOnly: false, // Allows PIN/Passcode if biometrics fail
        ),
      );

      if (authenticated) {
        _navigateToDashboard();
      } else {
        setState(() {
          _authStatus = "Authentication Failed";
          _isAuthenticating = false;
        });
      }
    } on PlatformException catch (e) {
      print(e);
      setState(() {
        _authStatus = "Error: ${e.message}";
        _isAuthenticating = false;
      });
    }
  }

  void _navigateToDashboard() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const IndexPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            const Icon(Icons.security_rounded, size: 100, color: Colors.blue),
            const SizedBox(height: 20),

            // App Name
            const Text(
              "RECORD MANAGER",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "SECURE OFFLINE VAULT",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 60),

            // Auth Status & Controls
            Text(
              _authStatus,
              style: const TextStyle(color: Colors.blueGrey, fontSize: 14),
            ),
            const SizedBox(height: 20),

            if (_isAuthenticating)
              const CircularProgressIndicator()
            else
            // If auth failed, show a retry button
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.lock_open),
                label: const Text("Retry Unlock"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}