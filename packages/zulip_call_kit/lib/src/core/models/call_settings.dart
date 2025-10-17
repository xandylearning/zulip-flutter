import 'call.dart';
import 'call_event.dart';
import 'call_participant.dart';

/// Configuration for the call kit
class CallKitConfiguration {
  const CallKitConfiguration({
    required this.appName,
    this.currentUser,
    this.onIncomingCall,
    this.onCallStatusChanged,
    this.onCallEnded,
    this.enableCallHistory = true,
    this.enableNotifications = true,
    this.ringtoneAsset,
    this.maxCallDuration = const Duration(hours: 2),
    this.callTimeout = const Duration(seconds: 45),
    this.heartbeatInterval = const Duration(seconds: 5),
  });

  /// Application name (shown in notifications)
  final String appName;

  /// Current logged-in user
  final CallParticipant? currentUser;

  /// Callback for incoming calls
  final void Function(Call call, CallParticipant initiator)? onIncomingCall;

  /// Callback for call status changes
  final void Function(String callId, CallStatus oldStatus, CallStatus newStatus)?
      onCallStatusChanged;

  /// Callback for call ended
  final void Function(String callId, CallEndReason reason, int? duration)?
      onCallEnded;

  /// Enable call history tracking
  final bool enableCallHistory;

  /// Enable system notifications
  final bool enableNotifications;

  /// Custom ringtone asset path
  final String? ringtoneAsset;

  /// Maximum call duration (auto-end after this)
  final Duration maxCallDuration;

  /// Call timeout (cancel if not answered)
  final Duration callTimeout;

  /// Heartbeat interval during active calls
  final Duration heartbeatInterval;
}
