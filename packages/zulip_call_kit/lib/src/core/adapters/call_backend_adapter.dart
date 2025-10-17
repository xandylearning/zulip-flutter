import '../models/call.dart';
import '../models/call_event.dart';
import '../models/call_participant.dart';
import '../models/call_session.dart';

/// Abstract adapter for backend communication
///
/// Implement this to integrate with your backend system.
///
/// Example implementations:
/// - ZulipCallAdapter for Zulip backend
/// - JitsiCallAdapter for direct Jitsi Meet integration
abstract class CallBackendAdapter {
  /// Create a new call
  ///
  /// Returns a [CallSession] with meeting URL and call details.
  ///
  /// Throws Exception on error.
  Future<CallSession> createCall({
    required CallParticipant initiator,
    required CallParticipant recipient,
    required CallType type,
    Map<String, dynamic>? metadata,
  });

  /// Acknowledge an incoming call
  ///
  /// Throws Exception on error.
  Future<void> acknowledgeCall({
    required String callId,
    required CallParticipant participant,
  });

  /// Accept an incoming call
  ///
  /// Throws Exception on error.
  Future<void> acceptCall({
    required String callId,
    required CallParticipant participant,
  });

  /// Decline an incoming call
  ///
  /// Throws Exception on error.
  Future<void> declineCall({
    required String callId,
    required CallParticipant participant,
  });

  /// End an active call
  ///
  /// Throws Exception on error.
  Future<void> endCall({
    required String callId,
    int? duration,
  });

  /// Cancel a call before it's answered
  ///
  /// Throws Exception on error.
  Future<void> cancelCall({
    required String callId,
  });

  /// Send heartbeat during active call
  ///
  /// Used for keep-alive and network failure detection.
  Future<void> sendHeartbeat({
    required String callId,
    bool isBackgrounded = false,
  });

  /// Get call history
  ///
  /// Returns list of past calls, optionally filtered and paginated.
  Future<List<Call>> getCallHistory({
    int? limit,
    int? offset,
    String? userId,
    CallStatus? status,
  });

  /// Stream of call events from backend
  ///
  /// Emits events like:
  /// - Incoming calls
  /// - Call status changes
  /// - Participant joined/left
  /// - Call ended
  Stream<CallEvent> get callEvents;

  /// Dispose resources
  Future<void> dispose();
}
