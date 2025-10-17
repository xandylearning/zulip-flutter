import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:zulip_call_kit/zulip_call_kit.dart';

import '../api/model/call.dart';
import '../api/model/events.dart' as zulip_events;
import '../api/route/calls.dart';
import '../model/call_permissions.dart';
import 'home.dart';
import 'page.dart';
import 'store.dart';
import '../model/call_ui_state.dart';

class JitsiCallScreen extends StatefulWidget {
  const JitsiCallScreen({
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
      settings: const RouteSettings(name: 'JitsiCallScreen'),
      page: JitsiCallScreen(call: call),
    );
  }

  @override
  State<JitsiCallScreen> createState() => _JitsiCallScreenState();
}

class _JitsiCallScreenState extends State<JitsiCallScreen> with WidgetsBindingObserver {
  final _jitsiMeetPlugin = JitsiMeet();
  bool _isLoading = true;
  bool _callEnded = false;
  DateTime? _callStartTime;
  bool _userRequestedEnd = false; // Track if user explicitly ended the call

  // Heartbeat monitoring
  Timer? _heartbeatTimer;
  bool _isBackgrounded = false;
  VoidCallback? _callStoreListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CallUiState.isCallUiVisible.value = true;
    // Listen for call status changes coming from the server (e.g., other side ended)
    _callStoreListener = () {
      try {
        final store = PerAccountStoreWidget.of(context);
        final currentCall = store.callStore.getCall(widget.call.callId);
        if (currentCall == null
            || currentCall.status == CallStatus.ended
            || currentCall.status == CallStatus.cancelled
            || currentCall.status == CallStatus.declined) {
          developer.log('Call state changed to terminal on server; hanging up local Jitsi and closing screen', name: 'JitsiCall');
          // Ensure local Jitsi meeting leaves
          _jitsiMeetPlugin.hangUp();
          // Close screen if still mounted
          if (mounted) {
            Navigator.of(context).maybePop();
          }
        }
      } catch (e) {
        developer.log('Error while handling call store change: $e', name: 'JitsiCall');
      }
    };
    // Defer adding the listener until after first frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = PerAccountStoreWidget.of(context);
      store.callStore.addListener(_callStoreListener!);
    });
    _initializeCall();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    developer.log('App lifecycle changed to: $state', name: 'JitsiCall');

    // Update backgrounded state
    _isBackgrounded = state == AppLifecycleState.paused ||
                      state == AppLifecycleState.inactive ||
                      state == AppLifecycleState.hidden;

    // Send immediate heartbeat when backgrounded to notify server
    if (_isBackgrounded && _heartbeatTimer != null) {
      _sendHeartbeat();
    }

    // Handle app state changes for better UX
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App is being backgrounded or minimized
      developer.log('App is being backgrounded, ensuring clean state', name: 'JitsiCall');
      _handleAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      // App is being resumed
      developer.log('App is being resumed', name: 'JitsiCall');
      _handleAppResumed();
    }
  }

  Future<void> _initializeCall() async {
    developer.log(
      'Initializing Jitsi call: callId=${widget.call.callId}, callType=${widget.call.callType}',
      name: 'JitsiCall',
    );
    developer.log(
      'Call details: callerId=${widget.call.callerId}, recipientId=${widget.call.recipientId}, status=${widget.call.status}, jitsiUrl=${widget.call.jitsiUrl}',
      name: 'JitsiCall',
    );

    // Request permissions
    developer.log('Requesting permissions for ${widget.call.callType} call...', name: 'JitsiCall');
    final hasPermission = widget.call.callType == CallType.video
        ? await CallPermissions.requestVideoCallPermissions(context)
        : await CallPermissions.requestAudioCallPermissions(context);

    developer.log('Permission request result: $hasPermission', name: 'JitsiCall');

    if (!hasPermission) {
      developer.log('ERROR: Call initialization failed - permissions denied', name: 'JitsiCall');
      developer.log('Call will be ended and screen will be closed', name: 'JitsiCall');
      if (mounted) {
        // Show error to user before closing
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call permissions denied. Please enable camera/microphone permissions.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
        Navigator.of(context).pop();
      }
      return;
    }

    developer.log('Permissions granted, proceeding to join meeting...', name: 'JitsiCall');
    await _joinMeeting();
  }

  Future<void> _joinMeeting() async {
    try {
      developer.log('=== Starting Jitsi meeting join process ===', name: 'JitsiCall');
      developer.log('Step 1: Getting store and user info...', name: 'JitsiCall');

      final store = PerAccountStoreWidget.of(context);
      final user = store.getUser(store.selfUserId);

      developer.log('User info: userId=${store.selfUserId}, fullName=${user?.fullName}, email=${user?.email}', name: 'JitsiCall');

      // Extract room name from Jitsi URL
      developer.log('Step 2: Parsing Jitsi URL...', name: 'JitsiCall');
      developer.log('Jitsi URL: ${widget.call.jitsiUrl}', name: 'JitsiCall');

      final uri = Uri.parse(widget.call.jitsiUrl);
      final roomName = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : widget.call.callId;

      developer.log('Parsed URI - scheme: ${uri.scheme}, host: ${uri.host}, pathSegments: ${uri.pathSegments}', name: 'JitsiCall');
      developer.log('Room name: $roomName', name: 'JitsiCall');
      developer.log('Server URL: ${uri.scheme}://${uri.host}', name: 'JitsiCall');

      developer.log('Step 3: Creating Jitsi conference options...', name: 'JitsiCall');
      var options = JitsiMeetConferenceOptions(
        room: roomName,
        serverURL: uri.scheme + '://' + uri.host,
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": widget.call.callType == CallType.audio,
          "subject": "Zulip Call",
          "prejoinPageEnabled": false,
          // Add stability configurations to prevent crashes
          "disableRtx": true,
          "enableLayerSuspension": true,
          "channelLastN": 1,
          // Task management to prevent separate app entries
          "pipEnabled": true,
          "pipMode": "picture-in-picture"
        },
        featureFlags: {
          "unsaferoomwarning.enabled": false,
          "ios.screensharing.enabled": true,
          "prejoin.enabled": false,
          "prejoinpage.enabled": false,
          // Add stability feature flags
          "disableRtx": true,
          "enableLayerSuspension": true,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: user?.fullName ?? "User",
          email: user?.email,
          avatar: user?.avatarUrl,
        ),
      );

      developer.log('Jitsi options configured:', name: 'JitsiCall');
      developer.log('  - Room: $roomName', name: 'JitsiCall');
      developer.log('  - Server: ${uri.scheme}://${uri.host}', name: 'JitsiCall');
      developer.log('  - Call type: ${widget.call.callType}', name: 'JitsiCall');
      developer.log('  - Start with video: ${widget.call.callType == CallType.video}', name: 'JitsiCall');

      developer.log('Step 4: Setting up Jitsi event listeners...', name: 'JitsiCall');
      var listener = JitsiMeetEventListener(
        conferenceJoined: (url) {
          developer.log("✅ SUCCESS: Conference joined - $url", name: 'JitsiCall');
          developer.log("Call is now active, starting heartbeat...", name: 'JitsiCall');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _callStartTime = DateTime.now();
            });
            // Start heartbeat when call is active
            _startHeartbeat();
          }
        },
        conferenceTerminated: (url, error) {
          developer.log("❌ ERROR: Conference terminated!", name: 'JitsiCall');
          developer.log("  - URL: $url", name: 'JitsiCall');
          developer.log("  - Error: $error", name: 'JitsiCall');
          developer.log("  - Error type: ${error?.runtimeType}", name: 'JitsiCall');
          developer.log("  - Call start time: $_callStartTime", name: 'JitsiCall');
          developer.log("  - Time since init: ${_callStartTime == null ? 'N/A' : DateTime.now().difference(_callStartTime!).inSeconds}s", name: 'JitsiCall');
          _stopHeartbeat();

          // Handle different types of termination
          if (error != null) {
            developer.log("Conference terminated due to error: $error", name: 'JitsiCall');
            // This might be a crash - try to recover gracefully
            _handleConferenceError(error);
          } else {
            developer.log("Conference terminated normally", name: 'JitsiCall');
            _userRequestedEnd = true; // User ended via Jitsi UI
          }
          _endCall();
        },
        conferenceWillJoin: (url) {
          developer.log("⏳ Conference will join: $url", name: 'JitsiCall');
          developer.log("Jitsi SDK is preparing to join the conference...", name: 'JitsiCall');
        },
        participantJoined: (email, name, role, participantId) {
          developer.log("Participant joined: $name", name: 'JitsiCall');
        },
        participantLeft: (participantId) {
          developer.log("Participant left: $participantId", name: 'JitsiCall');
          // For 1:1 calls: if any participant leaves, end the call.
          // This ensures the call model is closed promptly when either side leaves the meeting.
          _endCall();
        },
        audioMutedChanged: (muted) {
          developer.log("Audio muted changed: $muted", name: 'JitsiCall');
        },
        videoMutedChanged: (muted) {
          developer.log("Video muted changed: $muted", name: 'JitsiCall');
        },
        screenShareToggled: (participantId, sharing) {
          developer.log("Screen share toggled: $participantId, $sharing", name: 'JitsiCall');
        },
        readyToClose: () {
          developer.log("📱 Ready to close", name: 'JitsiCall');
          developer.log("  - Call start time: $_callStartTime", name: 'JitsiCall');
          developer.log("  - Time since init: ${_callStartTime == null ? 'N/A' : DateTime.now().difference(_callStartTime!).inSeconds}s", name: 'JitsiCall');
          _stopHeartbeat();

          // User is leaving the Jitsi meeting - end the call immediately
          developer.log("User is leaving Jitsi meeting, ending call", name: 'JitsiCall');
          developer.log("Call ID: ${widget.call.callId}", name: 'JitsiCall');
          _userRequestedEnd = true;
          _endCall();
        },
      );

      developer.log('Step 5: Calling Jitsi SDK join()...', name: 'JitsiCall');

      // Add timeout protection to prevent hanging
      await _jitsiMeetPlugin.join(options, listener).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          developer.log('⚠️ Jitsi join timed out after 30 seconds', name: 'JitsiCall');
          throw TimeoutException('Jitsi join timed out', const Duration(seconds: 30));
        },
      );

      developer.log('✅ Jitsi SDK join() completed successfully', name: 'JitsiCall');
      developer.log('Waiting for Jitsi callbacks (conferenceWillJoin, conferenceJoined, etc.)', name: 'JitsiCall');
    } catch (error, stackTrace) {
      developer.log('❌ FATAL ERROR: Exception while joining Jitsi meeting', name: 'JitsiCall');
      developer.log('Error: $error', name: 'JitsiCall');
      developer.log('Error type: ${error.runtimeType}', name: 'JitsiCall');
      developer.log('Stack trace: $stackTrace', name: 'JitsiCall');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join call: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _endCall() async {
    if (_callEnded) {
      developer.log('Call already ended, skipping', name: 'JitsiCall');
      return;
    }
    _callEnded = true;

    developer.log('Ending call: callId=${widget.call.callId}', name: 'JitsiCall');
    developer.log('User requested end: $_userRequestedEnd', name: 'JitsiCall');

    try {
      final store = PerAccountStoreWidget.of(context);
      final duration = _callStartTime != null
          ? DateTime.now().difference(_callStartTime!).inSeconds
          : null;

      developer.log('Call duration: $duration seconds', name: 'JitsiCall');
      developer.log('Calling endCall API for callId: ${widget.call.callId}', name: 'JitsiCall');

      await endCall(
        store.connection,
        callId: widget.call.callId,
        duration: duration,
      );

      developer.log('Call ended successfully via API', name: 'JitsiCall');

      // Local fallback: immediately clear active call in store so UI updates
      // even if server event is delayed or missed.
      try {
        // Manually clear active call when server event may be delayed
        final active = store.callStore.activeCall;
        if (active?.callId == widget.call.callId) {
          store.callStore.handleCallEndedEvent(
            // Use minimal shape that CallStore reads: callId + duration
            // We can't import the part file directly, so call through events.dart factory
            // But here we can just build a small map and use the factory
            zulip_events.CallEndedEvent.fromJson({
              'id': 0,
              'type': 'call',
              'op': 'ended',
              'call_id': widget.call.callId,
              'duration': duration ?? 0,
            }),
          );
        }
      } catch (e) {
        developer.log('Failed to update local call store on end: $e', name: 'JitsiCall');
      }
    } catch (e) {
      developer.log('Failed to end call: $e', name: 'JitsiCall');
      developer.log('Error type: ${e.runtimeType}', name: 'JitsiCall');
    }

    if (mounted) {
      developer.log('Navigating back from Jitsi call screen', name: 'JitsiCall');
      Navigator.of(context).pop();
    }
  }

  /// Start sending heartbeat to server every 5 seconds.
  void _startHeartbeat() {
    developer.log('Starting heartbeat for call: callId=${widget.call.callId}', name: 'JitsiCall');

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _sendHeartbeat();
    });
  }

  /// Send heartbeat to server.
  Future<void> _sendHeartbeat() async {
    try {
      final store = PerAccountStoreWidget.of(context);
      await sendHeartbeat(
        store.connection,
        callId: widget.call.callId,
        isBackgrounded: _isBackgrounded,
      );
      developer.log('Heartbeat sent successfully', name: 'JitsiCall');
    } catch (e) {
      developer.log('Failed to send heartbeat: $e', name: 'JitsiCall');
      // Server will handle network failure detection (15-second timeout)
    }
  }

  /// Stop sending heartbeat.
  void _stopHeartbeat() {
    developer.log('Stopping heartbeat for call: callId=${widget.call.callId}', name: 'JitsiCall');
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Handle conference errors and crashes gracefully.
  void _handleConferenceError(dynamic error) {
    developer.log('Handling conference error: $error', name: 'JitsiCall');

    // Check if this is a crash-related error
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('crash') ||
        errorString.contains('segfault') ||
        errorString.contains('sigsegv') ||
        errorString.contains('null pointer') ||
        errorString.contains('memory')) {
      developer.log('Detected potential crash-related error, attempting recovery...', name: 'JitsiCall');

      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call encountered an error and was terminated. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Handle app being backgrounded (minimized) for better UX.
  void _handleAppBackgrounded() {
    developer.log('App is being backgrounded, ensuring clean state', name: 'JitsiCall');

    // When app is backgrounded, we want to ensure the main app UI is clean
    // This prevents showing debug/development content when Jitsi is minimized
    try {
      if (mounted) {
        // Navigate to home page to ensure clean UI when Jitsi is minimized
        final currentRoute = ModalRoute.of(context);

        // If we're not on the home page, navigate there
        if (currentRoute?.settings.name != 'HomePage') {
          developer.log('Navigating to home page for clean background state', name: 'JitsiCall');
          // Import the home page navigation
          // This ensures users see the main app interface when Jitsi is minimized
          _navigateToHomePage();
        }
      }
    } catch (e) {
      developer.log('Error handling app backgrounded state: $e', name: 'JitsiCall');
    }
  }

  /// Navigate to home page for clean background state.
  void _navigateToHomePage() {
    try {
      if (mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        final accountId = PerAccountStoreWidget.accountIdOf(context);

        // Navigate to home page to show clean interface
        // Use the proper home page navigation method
        navigator.pushAndRemoveUntil(
          HomePage.buildRoute(accountId: accountId),
          (route) => false,
        );
      }
    } catch (e) {
      developer.log('Error navigating to home page: $e', name: 'JitsiCall');
    }
  }

  /// Handle app being resumed for better UX.
  void _handleAppResumed() {
    developer.log('App is being resumed', name: 'JitsiCall');

    // When app is resumed, ensure proper state
    try {
      if (mounted) {
        developer.log('App resumed, ensuring proper state', name: 'JitsiCall');
      }
    } catch (e) {
      developer.log('Error handling app resumed state: $e', name: 'JitsiCall');
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to call...'),
            ],
          ),
        ),
      );
    }

    // Jitsi handles its own UI, so we return an empty container
    // The call UI is rendered natively
    return const Scaffold(
      body: SizedBox.expand(),
    );
  }

  @override
  void dispose() {
    developer.log('JitsiCallScreen dispose: _callEnded=$_callEnded, _userRequestedEnd=$_userRequestedEnd, _callStartTime=$_callStartTime', name: 'JitsiCall');
    WidgetsBinding.instance.removeObserver(this);
    _heartbeatTimer?.cancel();
    // Remove call store listener if added
    try {
      if (_callStoreListener != null && context.mounted) {
        final store = PerAccountStoreWidget.of(context);
        store.callStore.removeListener(_callStoreListener!);
      }
    } catch (_) {}

    // If the call hasn't been ended yet and the call has started, end it
    // This ensures the call is properly ended when the user leaves the meeting
    if (!_callEnded && _callStartTime != null) {
      developer.log('JitsiCallScreen dispose: Ending call because user left meeting and call started', name: 'JitsiCall');
      _userRequestedEnd = true;
      _endCall();
    } else {
      developer.log('JitsiCallScreen dispose: Not ending call - _callEnded=$_callEnded, _callStartTime=$_callStartTime', name: 'JitsiCall');
    }
    CallUiState.isCallUiVisible.value = false;
    super.dispose();
  }
}

