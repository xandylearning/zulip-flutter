import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../api/model/call.dart';
import '../api/model/model.dart';
import '../api/route/calls.dart';
import '../generated/l10n/zulip_localizations.dart';
import '../model/store.dart';
import 'jitsi_call_screen.dart';
import 'page.dart';
import 'store.dart';
import '../model/call_ui_state.dart';
import 'user.dart';

class CallDialingScreen extends StatefulWidget {
  const CallDialingScreen({
    super.key,
    required this.call,
    required this.recipient,
  });

  final Call call;
  final User recipient;

  static Route<void> buildRoute({
    required int accountId,
    required Call call,
    required User recipient,
  }) {
    return MaterialAccountWidgetRoute(
      accountId: accountId,
      settings: const RouteSettings(name: 'CallDialingScreen'),
      page: CallDialingScreen(call: call, recipient: recipient),
    );
  }

  @override
  State<CallDialingScreen> createState() => _CallDialingScreenState();
}

class _CallDialingScreenState extends State<CallDialingScreen>
    with PerAccountStoreAwareStateMixin<CallDialingScreen>, SingleTickerProviderStateMixin<CallDialingScreen> {
  Timer? _callTimer;
  int _callDuration = 0;
  bool _isCancelling = false;
  bool _isNavigatingToJitsi = false; // Prevent race condition with call ending
  PerAccountStore? _store; // Cache the store reference for dispose
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void onNewStore() {
    debugPrint('CallDialingScreen: onNewStore: Setting up store listener');
    _store = PerAccountStoreWidget.of(context);
    _store!.callStore.addListener(_onCallStoreChange);
    debugPrint('CallDialingScreen: onNewStore: Listener added to callStore');
    debugPrint('CallDialingScreen: onNewStore: Current call ID: ${widget.call.callId}');
    debugPrint('CallDialingScreen: onNewStore: Store has active call: ${_store!.callStore.hasActiveCall}');
  }

  void _onCallStoreChange() {
    debugPrint('CallDialingScreen: _onCallStoreChange: Store change detected');
    debugPrint('CallDialingScreen: _onCallStoreChange: Widget mounted: $mounted');
    if (!mounted) return;

    setState(() {});

    // If we're already navigating to Jitsi, ignore any further state changes
    // to prevent race condition where call ends before navigation completes
    if (_isNavigatingToJitsi) {
      debugPrint('CallDialingScreen: Already navigating to Jitsi, ignoring state change');
      return;
    }

    // Check if call was accepted and navigate to Jitsi
    final store = PerAccountStoreWidget.of(context);
    final callStore = store.callStore;
    final currentCall = callStore.getCall(widget.call.callId);

    debugPrint('CallDialingScreen: Store change detected for call ${widget.call.callId}');
    debugPrint('CallDialingScreen: Current call status: ${currentCall?.status}');
    debugPrint('CallDialingScreen: Active call: ${callStore.activeCall?.callId}');
    debugPrint('CallDialingScreen: Has active call: ${callStore.hasActiveCall}');
    debugPrint('CallDialingScreen: Active call status: ${callStore.activeCall?.status}');

    // Check both the specific call and the active call
    if (currentCall?.status == CallStatus.accepted ||
        (callStore.activeCall?.callId == widget.call.callId && callStore.activeCall?.status == CallStatus.accepted)) {
      debugPrint('CallDialingScreen: Call accepted, navigating to Jitsi');
      _navigateToJitsi();
    } else if (currentCall?.status == CallStatus.declined ||
               currentCall?.status == CallStatus.cancelled ||
               currentCall?.status == CallStatus.ended) {
      debugPrint('CallDialingScreen: Call ended, handling call end');
      _handleCallEnded();
    }
  }

  @override
  void initState() {
    super.initState();
    developer.log('initState: CallDialingScreen initialized for call ${widget.call.callId}', name: 'CallDialingScreen');
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

    _startCallTimer();
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

  Future<void> _navigateToJitsi() async {
    debugPrint('CallDialingScreen: _navigateToJitsi: Starting navigation to Jitsi');

    // Set flag to prevent race condition with call ending
    _isNavigatingToJitsi = true;

    if (!mounted) {
      debugPrint('CallDialingScreen: _navigateToJitsi: Widget not mounted, aborting');
      return;
    }

    // Double-check that the call is still in accepted state
    final store = PerAccountStoreWidget.of(context);
    final currentCall = store.callStore.getCall(widget.call.callId);
    if (currentCall == null) {
      debugPrint('CallDialingScreen: _navigateToJitsi: Call no longer exists, aborting');
      _isNavigatingToJitsi = false;
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (currentCall.status != CallStatus.accepted) {
      debugPrint('CallDialingScreen: _navigateToJitsi: Call status changed to ${currentCall.status}, aborting');
      _isNavigatingToJitsi = false;
      return;
    }

    // Stop the timer
    _callTimer?.cancel();
    debugPrint('CallDialingScreen: _navigateToJitsi: Timer cancelled');

    // Navigate to Jitsi screen
    debugPrint('CallDialingScreen: _navigateToJitsi: Navigating to JitsiCallScreen');
    debugPrint('CallDialingScreen: _navigateToJitsi: Call object: ${widget.call}');
    debugPrint('CallDialingScreen: _navigateToJitsi: Call status: ${widget.call.status}');
    debugPrint('CallDialingScreen: _navigateToJitsi: Call Jitsi URL: ${widget.call.jitsiUrl}');

    try {
      await Navigator.of(context).pushReplacement(
        JitsiCallScreen.buildRoute(
          accountId: PerAccountStoreWidget.accountIdOf(context),
          call: widget.call,
        ),
      );
      debugPrint('CallDialingScreen: _navigateToJitsi: Navigation completed successfully');
    } catch (e) {
      debugPrint('CallDialingScreen: _navigateToJitsi: Navigation failed with error: $e');
      _isNavigatingToJitsi = false;
    }
  }

  void _handleCallEnded() {
    if (!mounted) return;

    // Stop the timer
    _callTimer?.cancel();

    // Navigate back to previous screen
    Navigator.of(context).pop();
  }

  Future<void> _cancelCall() async {
    if (_isCancelling) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      final store = PerAccountStoreWidget.of(context);
      await cancelCall(store.connection, callId: widget.call.callId);
    } catch (e) {
      debugPrint('Failed to cancel call: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  String _getStatusText() {
    final l10n = ZulipLocalizations.of(context);
    final store = PerAccountStoreWidget.of(context);
    final callStore = store.callStore;
    final currentCall = callStore.getCall(widget.call.callId);

    if (currentCall == null) {
      return l10n.callStatusCalling;
    }

    switch (currentCall.status) {
      case CallStatus.created:
        return l10n.callStatusCalling;
      case CallStatus.ringing:
        return l10n.callStatusRinging;
      case CallStatus.accepted:
        return l10n.callStatusConnecting;
      case CallStatus.declined:
        return l10n.callStatusDeclined;
      case CallStatus.cancelled:
        return l10n.callStatusCancelled;
      case CallStatus.ended:
        return l10n.callStatusEnded;
    }
  }

  String _formatDuration() {
    final minutes = _callDuration ~/ 60;
    final seconds = _callDuration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Use cached store reference instead of looking it up from context
    _store?.callStore.removeListener(_onCallStoreChange);
    _callTimer?.cancel();
    CallUiState.isCallUiVisible.value = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ZulipLocalizations.of(context);
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
              // Header with back button and timer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios, color: textColor, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        _getStatusText(),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _formatDuration(),
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated pulsing avatar
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer pulsing ring
                            Container(
                              width: 160 * _pulseAnimation.value,
                              height: 160 * _pulseAnimation.value,
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
                              width: 145 * _pulseAnimation.value,
                              height: 145 * _pulseAnimation.value,
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
                                userId: widget.recipient.userId,
                                size: 130,
                                borderRadius: 65,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Recipient name
                    Text(
                      widget.recipient.fullName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // Call type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.call.callType == CallType.video ? l10n.videoCall : l10n.audioCall,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Status indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(textColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _getStatusText(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Cancel button at bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isCancelling ? null : _cancelCall,
                      customBorder: const CircleBorder(),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      
    );
  }
}
