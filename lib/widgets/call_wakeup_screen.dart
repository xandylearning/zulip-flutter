import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../api/model/call.dart';
import '../api/route/calls.dart';
import '../generated/l10n/zulip_localizations.dart';
import 'jitsi_call_screen.dart';
import 'home.dart';
import '../model/call_ui_state.dart';
import 'page.dart';
import 'store.dart';
import 'user.dart';

class CallWakeUpScreen extends StatefulWidget {
  const CallWakeUpScreen({
    super.key,
    required this.call,
  });

  final Call call;

  static Route<void> buildRoute({
    required int accountId,
    required Call call,
  }) {
    return MaterialAccountWidgetRoute(
      accountId: accountId,
      settings: const RouteSettings(name: 'CallWakeUpScreen'),
      page: CallWakeUpScreen(call: call),
    );
  }

  @override
  State<CallWakeUpScreen> createState() => _CallWakeUpScreenState();
}

class _CallWakeUpScreenState extends State<CallWakeUpScreen>
    with SingleTickerProviderStateMixin {
  AudioPlayer? _audioPlayer;
  Timer? _callTimer;
  int _callDuration = 0;
  bool _hasAcknowledged = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Mark call UI visible
    CallUiState.isCallUiVisible.value = true;

    // Initialize pulse animation for avatar
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _playRingtone();
    _startCallTimer();

    // Listen to call state changes to auto-dismiss when call ends
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = PerAccountStoreWidget.of(context);
        store.callStore.addListener(_onCallStateChanged);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasAcknowledged) {
      _acknowledgeCall();
      _hasAcknowledged = true;
    }
  }

  void _onCallStateChanged() {
    // Check if our call is still active
    final store = PerAccountStoreWidget.of(context);
    final currentCall = store.callStore.getCall(widget.call.callId);

    // If call is no longer active or has ended, close the screen
    if (currentCall == null ||
        currentCall.status == CallStatus.ended ||
        currentCall.status == CallStatus.cancelled ||
        currentCall.status == CallStatus.declined) {
      debugPrint('CallWakeUpScreen: Call ${widget.call.callId} has ended, auto-dismissing');
      if (mounted) _closeScreenSafely();
    }
  }

  void _playRingtone() async {
    _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.play(AssetSource('sounds/ringtone.mp3'));
    } catch (e) {
      // If ringtone fails to play, continue without it
      debugPrint('Failed to play ringtone: $e');
    }
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration++;
        });
      }
    });
  }

  Future<void> _acknowledgeCall() async {
    try {
      final store = PerAccountStoreWidget.of(context);
      await acknowledgeCall(store.connection, callId: widget.call.callId);
      debugPrint('CallWakeUpScreen: Successfully acknowledged call ${widget.call.callId}');
    } catch (e) {
      debugPrint('CallWakeUpScreen: Failed to acknowledge call ${widget.call.callId}: $e');
      // If acknowledge fails, the event listener will handle auto-dismissing if call ended
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final caller = store.getUser(widget.call.callerId);
    final zulipLocalizations = ZulipLocalizations.of(context);

    // Check if call has already ended and close screen if so
    if (widget.call.status == CallStatus.ended ||
        widget.call.status == CallStatus.cancelled ||
        widget.call.status == CallStatus.declined) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('CallWakeUpScreen: Call has ended, closing screen');
          _closeScreenSafely();
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF212121);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF757575);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
          child: Column(
            children: [
              // Caller info
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (caller != null) ...[
                      // Animated pulsing avatar
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer pulsing ring
                              Container(
                                width: 140 * _pulseAnimation.value,
                                height: 140 * _pulseAnimation.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: (isDark ? Colors.white : const Color(0xFF3B82F6)).withValues(
                                        alpha: 0.3 * (2 - _pulseAnimation.value)),
                                    width: 2,
                                  ),
                                ),
                              ),
                              // Middle pulsing ring
                              Container(
                                width: 130 * _pulseAnimation.value,
                                height: 130 * _pulseAnimation.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: (isDark ? Colors.white : const Color(0xFF3B82F6)).withValues(
                                        alpha: 0.2 * (2 - _pulseAnimation.value)),
                                    width: 2,
                                  ),
                                ),
                              ),
                              // Avatar with border
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? Colors.white : const Color(0xFF3B82F6),
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isDark ? Colors.black : Colors.grey).withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Avatar(
                                  userId: caller.userId,
                                  size: 120,
                                  borderRadius: 60,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Text(
                        caller.fullName,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.call.callType == CallType.video
                              ? zulipLocalizations.incomingVideoCall
                            : zulipLocalizations.incomingAudioCall,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _formatDuration(_callDuration),
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 48, left: 32, right: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline button
                    _CallActionButton(
                      onPressed: _declineCall,
                      backgroundColor: const Color(0xFFEF4444), // Modern red
                      icon: Icons.call_end,
                      label: zulipLocalizations.decline,
                    ),

                    const SizedBox(width: 48),

                    // Accept button
                    _CallActionButton(
                      onPressed: _acceptCall,
                      backgroundColor: const Color(0xFF10B981), // Emerald green
                      icon: Icons.call,
                      label: zulipLocalizations.accept,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _acceptCall() async {
    await _audioPlayer?.stop();
    _callTimer?.cancel();

    try {
      final store = PerAccountStoreWidget.of(context);
      debugPrint('CallWakeUpScreen: Attempting to accept call ${widget.call.callId}');
      debugPrint('CallWakeUpScreen: Call status: ${widget.call.status}');
      debugPrint('CallWakeUpScreen: Call type: ${widget.call.callType}');

      await acceptCall(store.connection, callId: widget.call.callId);
      debugPrint('CallWakeUpScreen: Successfully accepted call ${widget.call.callId}');

      if (!mounted) return;

      // Navigate to Jitsi screen
      await Navigator.of(context).pushReplacement(
        JitsiCallScreen.buildRoute(
          accountId: PerAccountStoreWidget.accountIdOf(context),
          call: widget.call,
        ),
      );
    } catch (e) {
      debugPrint('CallWakeUpScreen: Failed to accept call ${widget.call.callId}: $e');
      debugPrint('CallWakeUpScreen: Error type: ${e.runtimeType}');
      debugPrint('CallWakeUpScreen: Full error details: ${e.toString()}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept call: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _declineCall() async {
    await _audioPlayer?.stop();
    _callTimer?.cancel();

    try {
      final store = PerAccountStoreWidget.of(context);
      debugPrint('CallWakeUpScreen: Attempting to decline call ${widget.call.callId}');
      debugPrint('CallWakeUpScreen: Call status: ${widget.call.status}');
      debugPrint('CallWakeUpScreen: Call type: ${widget.call.callType}');

      await declineCall(store.connection, callId: widget.call.callId);
      debugPrint('CallWakeUpScreen: Successfully declined call ${widget.call.callId}');

      if (!mounted) return;
      _closeScreenSafely();
    } catch (e) {
      debugPrint('CallWakeUpScreen: Failed to decline call ${widget.call.callId}: $e');
      debugPrint('CallWakeUpScreen: Error type: ${e.runtimeType}');
      debugPrint('CallWakeUpScreen: Full error details: ${e.toString()}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline call: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      _closeScreenSafely();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer?.dispose();
    _callTimer?.cancel();

    // Remove listener if context is still available
    try {
      if (context.mounted) {
        final store = PerAccountStoreWidget.of(context);
        store.callStore.removeListener(_onCallStateChanged);
      }
    } catch (e) {
      // Context might not be available during disposal, which is fine
      debugPrint('CallWakeUpScreen: Could not remove listener during dispose: $e');
    }

    // Mark call UI hidden
    CallUiState.isCallUiVisible.value = false;
    super.dispose();
  }

  /// Safely close this screen: pop if possible, otherwise go to HomePage.
  void _closeScreenSafely() {
    try {
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
        return;
      }

      // No back stack (e.g., launched from notification) – navigate to home
      final accountId = PerAccountStoreWidget.accountIdOf(context);
      rootNavigator.pushAndRemoveUntil(
        HomePage.buildRoute(accountId: accountId),
        (route) => false,
      );
    } catch (e) {
      debugPrint('CallWakeUpScreen: _closeScreenSafely error: $e');
    }
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.icon,
    required this.label,
  });

  final VoidCallback onPressed;
  final Color backgroundColor;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor,
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF212121),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

