import 'dart:async';
import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../api/model/call.dart';
import '../api/route/calls.dart';
import '../generated/l10n/zulip_localizations.dart';
import 'app.dart';
import 'call_wakeup_screen.dart';
import 'jitsi_call_screen.dart';
import 'store.dart';

/// A beautiful call card that slides down from the top when there's an incoming call.
/// This replaces system notifications when the app is open.
class IncomingCallCard extends StatefulWidget {
  const IncomingCallCard({
    super.key,
    required this.call,
    required this.onDismiss,
  });

  final Call call;
  final VoidCallback onDismiss;

  @override
  State<IncomingCallCard> createState() => _IncomingCallCardState();
}

class _IncomingCallCardState extends State<IncomingCallCard>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _expandController;
  late AnimationController _pulseController;
  late AnimationController _ringController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _widthAnimation;
  late Animation<double> _heightAnimation;
  late Animation<double> _borderRadiusAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ringAnimation;

  Timer? _autoDeclineTimer;
  Timer? _shrinkTimer;
  bool _isProcessing = false;
  bool _isDismissing = false;

  // Audio player for ringtone
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingRingtone = false;

  // Dimensions for pill and expanded states
  static const double _pillWidth = 180.0;
  static const double _pillHeight = 48.0;
  static const double _pillRadius = 24.0;
  static const double _cardHeight = 180.0;
  static const double _cardRadius = 20.0;

  @override
  void initState() {
    super.initState();

    // Fast slide animation (300ms - snappy like Dynamic Island)
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Smooth expansion animation (700ms - buttery smooth)
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    // Pulse animation for avatar
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Ring animation for status indicator
    _ringController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Slide from top - fast and snappy
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Scale for pill appearance
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    // Width expansion - smooth elastic growth
    _widthAnimation = Tween<double>(
      begin: _pillWidth,
      end: double.infinity, // Will be constrained by parent
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    ));

    // Height expansion - smooth elastic growth
    _heightAnimation = Tween<double>(
      begin: _pillHeight,
      end: _cardHeight,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    ));

    // Border radius - smooth transition from pill to card
    _borderRadiusAnimation = Tween<double>(
      begin: _pillRadius,
      end: _cardRadius,
    ).animate(CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _ringAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _ringController,
      curve: Curves.easeInOut,
    ));

    // Animation sequence: Fast slide, then smooth expand
    _slideController.forward().then((_) {
      if (mounted) {
        // Small delay for visual appeal (like Dynamic Island)
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _expandController.forward();
          }
        });
      }
    });

    _pulseController.repeat(reverse: true);
    _ringController.repeat(reverse: true);

    // Start playing ringtone
    _startRingtone();

    // Start shrinking 5 seconds before auto-decline
    _shrinkTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && !_isDismissing) {
        _startSmoothShrink();
      }
    });

    // Auto-decline after 30 seconds
    _autoDeclineTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && !_isDismissing) {
        _declineCall();
      }
    });
  }

  void _startSmoothShrink() {
    developer.log('IncomingCallCard: Starting smooth shrink animation', name: 'IncomingCallCard');

    // Reverse the expansion animation smoothly
    _expandController.reverse().then((_) {
      if (mounted && !_isDismissing) {
        // After shrinking to pill, slide up
        _slideController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _expandController.dispose();
    _pulseController.dispose();
    _ringController.dispose();
    _autoDeclineTimer?.cancel();
    _shrinkTimer?.cancel();
    _stopRingtone();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// Start playing the ringtone
  Future<void> _startRingtone() async {
    if (_isPlayingRingtone) return;

    try {
      developer.log('IncomingCallCard: Starting ringtone', name: 'IncomingCallCard');
      _isPlayingRingtone = true;

      // Play the ringtone from assets
      await _audioPlayer.play(AssetSource('sounds/ringtone.mp3'));

      // Set up loop for continuous ringing
      _audioPlayer.onPlayerComplete.listen((_) {
        if (_isPlayingRingtone && mounted) {
          _audioPlayer.resume();
        }
      });

      developer.log('IncomingCallCard: Ringtone started successfully', name: 'IncomingCallCard');
    } catch (e) {
      developer.log('IncomingCallCard: Failed to start ringtone: $e', name: 'IncomingCallCard');
      _isPlayingRingtone = false;
    }
  }

  /// Stop playing the ringtone
  Future<void> _stopRingtone() async {
    if (!_isPlayingRingtone) return;

    try {
      developer.log('IncomingCallCard: Stopping ringtone', name: 'IncomingCallCard');
      _isPlayingRingtone = false;
      await _audioPlayer.stop();
      developer.log('IncomingCallCard: Ringtone stopped successfully', name: 'IncomingCallCard');
    } catch (e) {
      developer.log('IncomingCallCard: Failed to stop ringtone: $e', name: 'IncomingCallCard');
    }
  }

  Future<void> _acceptCall() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      developer.log('Accepting call: ${widget.call.callId}', name: 'IncomingCallCard');

      // Stop ringtone when accepting call
      await _stopRingtone();

      final store = PerAccountStoreWidget.of(context);
      await acceptCall(store.connection, callId: widget.call.callId);

      developer.log('Call accepted successfully', name: 'IncomingCallCard');

      // Dismiss the card first
      widget.onDismiss();

      // Navigate directly to JitsiCallScreen
      if (mounted) {
        final navigatorState = ZulipApp.navigatorKey.currentState;
        if (navigatorState != null) {
          navigatorState.push(
            JitsiCallScreen.buildRoute(
              accountId: PerAccountStoreWidget.accountIdOf(context),
              call: widget.call,
            ),
          );
        }
      }
    } catch (e) {
      developer.log('Failed to accept call: $e', name: 'IncomingCallCard');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept call: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _declineCall() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      developer.log('Declining call: ${widget.call.callId}', name: 'IncomingCallCard');

      // Stop ringtone when declining call
      await _stopRingtone();

      final store = PerAccountStoreWidget.of(context);
      await declineCall(store.connection, callId: widget.call.callId);

      developer.log('Call declined successfully', name: 'IncomingCallCard');

      // Dismiss the card
      widget.onDismiss();
    } catch (e) {
      developer.log('Failed to decline call: $e', name: 'IncomingCallCard');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline call: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _onCardTap() {
    developer.log('IncomingCallCard: Card tapped', name: 'IncomingCallCard');

    try {
      developer.log('IncomingCallCard: Dismissing card and navigating to CallWakeUpScreen', name: 'IncomingCallCard');
      developer.log('IncomingCallCard: Call details: callId=${widget.call.callId}, status=${widget.call.status}', name: 'IncomingCallCard');

      // Stop ringtone when card is tapped
      _stopRingtone();

      // Dismiss the card with animation
      _dismissCard();

      // Navigate after animation completes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final navigatorState = ZulipApp.navigatorKey.currentState;
          if (navigatorState != null) {
            navigatorState.push(
              CallWakeUpScreen.buildRoute(
                accountId: PerAccountStoreWidget.accountIdOf(context),
                call: widget.call,
              ),
            );
          }
        }
      });

      developer.log('IncomingCallCard: Card dismissed and navigation initiated', name: 'IncomingCallCard');
    } catch (e) {
      developer.log('IncomingCallCard: Failed to dismiss card and navigate: $e', name: 'IncomingCallCard');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open call: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _dismissCard() {
    if (_isDismissing) return;

    developer.log('IncomingCallCard: Dismissing card', name: 'IncomingCallCard');

    setState(() {
      _isDismissing = true;
    });

    // Stop other animations
    _pulseController.stop();
    _ringController.stop();

    // Cancel timers
    _autoDeclineTimer?.cancel();
    _shrinkTimer?.cancel();

    // Smooth dismissal: shrink then slide
    _expandController.reverse().then((_) {
      if (mounted) {
        _slideController.reverse().then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final l10n = ZulipLocalizations.of(context);

    // Get the caller information
    final caller = store.getUser(widget.call.callerId);
    final callerName = caller?.fullName ?? 'Unknown Caller';
    final callerAvatar = caller?.avatarUrl;

    developer.log('IncomingCallCard: Caller ID: ${widget.call.callerId}', name: 'IncomingCallCard');
    developer.log('IncomingCallCard: Caller found: ${caller != null}', name: 'IncomingCallCard');
    developer.log('IncomingCallCard: Caller name: $callerName', name: 'IncomingCallCard');

    // Determine if it's dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SafeArea(
          bottom: false,
          child: GestureDetector(
            onTap: _onCardTap,
            onPanEnd: (details) {
              // Swipe up to dismiss
              if (details.velocity.pixelsPerSecond.dy < -500) {
                _dismissCard();
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _expandController,
                  _widthAnimation,
                  _heightAnimation,
                  _borderRadiusAnimation,
                ]),
                builder: (context, child) {
                  final width = _widthAnimation.value;
                  final height = _heightAnimation.value;
                  final borderRadius = _borderRadiusAnimation.value;

                  return Center(
                    child: Container(
                      width: width == double.infinity ? null : width,
                      height: height,
                      constraints: width == double.infinity
                          ? const BoxConstraints(maxWidth: 400, minWidth: 350)
                          : null,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                        borderRadius: BorderRadius.circular(borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(76),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(borderRadius),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Material(
                  child: AnimatedBuilder(
                    animation: _expandController,
                    builder: (context, child) {
                      // Only show full content when expanded past 50%
                      if (_expandController.value < 0.3) {
                        // Show minimal pill content
                        return Center(
                          child: Opacity(
                            opacity: 1 - (_expandController.value * 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Incoming call...',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Show full content with fade-in
                      return Opacity(
                        opacity: ((_expandController.value - 0.3) / 0.7).clamp(0.0, 1.0),
                        child: child,
                      );
                    },
                    child: Stack(
                      children: [
                        // Close button
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _dismissCard,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(51),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),

                        // Main content
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Avatar Section
                              Stack(
                                children: [
                                  // Pulsing rings
                                  AnimatedBuilder(
                                    animation: _pulseAnimation,
                                    builder: (context, child) {
                                      return Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.blue.withAlpha(
                                              (51 * (1 - _pulseAnimation.value)).round()),
                                        ),
                                      );
                                    },
                                  ),

                                  // Avatar
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF3B82F6),
                                          Color(0xFFA855F7),
                                          Color(0xFFEC4899),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withAlpha(127),
                                          blurRadius: 12,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: callerAvatar != null
                                        ? ClipOval(
                                            child: Image.network(
                                              callerAvatar,
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return _buildAvatarInitials(callerName);
                                              },
                                            ),
                                          )
                                        : _buildAvatarInitials(callerName),
                                  ),

                                  // Online Indicator
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withAlpha(127),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: 16),

                               // Content Section
                               Expanded(
                                 child: SingleChildScrollView(
                                   child: ConstrainedBox(
                                     constraints: const BoxConstraints(
                                       minHeight: 140,
                                     ),
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       mainAxisAlignment: MainAxisAlignment.center,
                                       mainAxisSize: MainAxisSize.min,
                                       children: [
                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF3B82F6).withAlpha(51)
                                            : const Color(0xFFDBEAFE),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedBuilder(
                                            animation: _ringAnimation,
                                            builder: (context, child) {
                                              return Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF3B82F6).withAlpha(
                                                      (255 * _ringAnimation.value).round()),
                                                  shape: BoxShape.circle,
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              l10n.callStatusRinging,
                                              style: TextStyle(
                                                color: isDark
                                                    ? const Color(0xFF60A5FA)
                                                    : const Color(0xFF2563EB),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                     const SizedBox(height: 4),

                                     // Name
                                     Flexible(
                                       child: Text(
                                         callerName,
                                         style: TextStyle(
                                           color: isDark ? Colors.white : const Color(0xFF111827),
                                           fontSize: 14,
                                           fontWeight: FontWeight.bold,
                                         ),
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                     ),

                                     const SizedBox(height: 2),

                                    // Secondary line (generic state only)
                                    Flexible(
                                      child: Text(
                                        l10n.callStatusRinging,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF6B7280),
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                     const SizedBox(height: 8),

                                    // Action Buttons
                                    Row(
                                      children: [
                                        // Decline Button
                                        Expanded(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _isProcessing ? null : _declineCall,
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                 padding:
                                                     const EdgeInsets.symmetric(vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444),
                                                  borderRadius: BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFFEF4444)
                                                          .withAlpha(76),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: const Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.call_end,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Decline',
                                                       style: TextStyle(
                                                         color: Colors.white,
                                                         fontSize: 12,
                                                         fontWeight: FontWeight.w600,
                                                       ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        // Accept Button
                                        Expanded(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _isProcessing ? null : _acceptCall,
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                 padding:
                                                     const EdgeInsets.symmetric(vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981),
                                                  borderRadius: BorderRadius.circular(8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFF10B981)
                                                          .withAlpha(76),
                                                      blurRadius: 6,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: const Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.call,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Accept',
                                                       style: TextStyle(
                                                         color: Colors.white,
                                                         fontSize: 12,
                                                         fontWeight: FontWeight.w600,
                                                       ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarInitials(String name) {
    final initials = name.isNotEmpty
        ? name
            .split(' ')
            .map((word) => word.isNotEmpty ? word[0].toUpperCase() : '')
            .take(2)
            .join()
        : '?';

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}