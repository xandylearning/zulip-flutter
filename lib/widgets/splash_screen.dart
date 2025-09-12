import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/route/realm.dart';
import '../model/server_support.dart';
import 'home.dart';
import 'login.dart';
import 'store.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Set system UI overlay style for immersive experience
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    );

    _textAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    );

    // Create a subtle pulse animation for the logo
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));

    _startAnimations();
    _checkAuthAndNavigate();
  }

  void _startAnimations() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _textController.forward();

    // Start pulse animation after initial animation
    await Future<void>.delayed(const Duration(milliseconds: 600));
    // Don't repeat the logo controller to avoid opacity issues
    // _logoController.repeat(reverse: true);
  }

  void _checkAuthAndNavigate() async {
    // Wait for minimum splash duration
    await Future<void>.delayed(const Duration(seconds: 2, milliseconds: 500));

    if (!mounted) return;

    final globalStore = GlobalStoreWidget.of(context);

    // Check if user has existing accounts (is authenticated)
    final hasAccounts = globalStore.accounts.isNotEmpty;

    if (hasAccounts) {
      // User is authenticated, go directly to home
      final accountId = globalStore.accounts.first.id;

      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (context, animation, secondaryAnimation) {
            // Navigate to HomePage with the account
            Future.microtask(() {
              if (context.mounted) {
                HomePage.navigate(context, accountId: accountId);
              }
            });
            return const SizedBox.shrink();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation.drive(
                Tween(begin: 0.0, end: 1.0).chain(
                  CurveTween(curve: Curves.easeInOut),
                ),
              ),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } else {
      // User is not authenticated, connect to hardcoded server
      _connectToHardcodedServer();
    }
  }

  Future<void> _connectToHardcodedServer() async {
    try {
      final hardcodedUrl = Uri.parse('https://dev.zulip.xandylearning.in');

      final globalStore = GlobalStoreWidget.of(context);
      final connection = globalStore.apiConnection(
        realmUrl: hardcodedUrl,
        zulipFeatureLevel: null,
      );

      try {
        final serverSettings = await getServerSettings(connection);
        final zulipVersionData = ZulipVersionData.fromServerSettings(serverSettings);

        if (zulipVersionData.isUnsupported) {
          throw ServerVersionUnsupportedException(zulipVersionData);
        }

        if (!mounted) return;

        // Navigate to login page with smooth transition
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) =>
                LoginPage(serverSettings: serverSettings),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation.drive(
                  Tween(begin: 0.0, end: 1.0).chain(
                    CurveTween(curve: Curves.easeInOut),
                  ),
                ),
                child: SlideTransition(
                  position: animation.drive(
                    Tween(begin: const Offset(0.0, 0.02), end: Offset.zero)
                        .chain(CurveTween(curve: Curves.easeOut)),
                  ),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } finally {
        connection.close();
      }
    } catch (e) {
      if (!mounted) return;

      // Show error in a beautiful way
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to connect to server'),
          backgroundColor: colorScheme.error,
          action: SnackBarAction(
            label: 'Retry',
            textColor: colorScheme.onError,
            onPressed: _connectToHardcodedServer,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFf5c02d), // Yellow from gradient
              Color(0xFFf3a937), // Orange-yellow
              Color(0xFFf28e44), // Orange
              Color(0xFFf1784f), // Red-orange
              Color(0xFFf06757), // Red-orange
              Color(0xFFef5b5c), // Red
              Color(0xFFef5460), // Red
              Color(0xFFef5361), // Red from gradient
            ],
            stops: [0.0, 0.05, 0.12, 0.2, 0.29, 0.41, 0.57, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative circles in background
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              left: -150,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoAnimation, _pulseAnimation]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _logoAnimation.value * _pulseAnimation.value,
                        child: Opacity(
                          opacity: _logoAnimation.value.clamp(0.0, 1.0),
                          child: Container(
                            width: 120,
                            height: 120,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/app-icons/zulip-combined.png',
                              width: 60,
                              height: 60,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // App name and tagline
                  FadeTransition(
                    opacity: _textAnimation,
                    child: SlideTransition(
                      position: _textAnimation.drive(
                        Tween(begin: const Offset(0, 0.3), end: Offset.zero),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'XandY',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'X&Y Learning Platform',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),

                  // Loading indicator
                  FadeTransition(
                    opacity: _textAnimation,
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}