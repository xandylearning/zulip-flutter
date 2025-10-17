import 'dart:async';

import '../models/call.dart';
import '../models/call_participant.dart';
import '../models/call_session.dart';
import '../models/call_settings.dart';
import '../adapters/call_backend_adapter.dart';
import '../repository/call_repository.dart';

/// Main service for managing calls
///
/// This is the primary interface for integrating the call kit.
class CallKitService {
  CallKitService({
    required CallBackendAdapter adapter,
    required CallKitConfiguration config,
    CallRepository? repository,
  })  : _adapter = adapter,
        _config = config,
        _repository = repository ?? CallRepository(adapter: adapter);

  final CallBackendAdapter _adapter;
  final CallKitConfiguration _config;
  final CallRepository _repository;

  StreamSubscription<dynamic>? _eventSubscription;

  /// Initialize the call kit service
  ///
  /// Must be called before using any other methods.
  Future<void> initialize() async {
    // Subscribe to backend events
    _eventSubscription = _adapter.callEvents.listen(_handleCallEvent);
  }

  /// Start a new call
  ///
  /// Returns [CallSession] with meeting details.
  Future<CallSession> startCall({
    required CallParticipant recipient,
    required CallType type,
    Map<String, dynamic>? metadata,
  }) async {
    final initiator = _config.currentUser;
    if (initiator == null) {
      throw Exception('Current user not configured');
    }

    final session = await _adapter.createCall(
      initiator: initiator,
      recipient: recipient,
      type: type,
      metadata: metadata,
    );

    // Update repository state
    _repository.addPendingOutgoingCall(session.call);

    return session;
  }

  /// Accept an incoming call
  Future<void> acceptCall(Call call) async {
    final participant = _config.currentUser;
    if (participant == null) {
      throw Exception('Current user not configured');
    }

    await _adapter.acceptCall(
      callId: call.callId,
      participant: participant,
    );

    _repository.setActiveCall(call.copyWith(status: CallStatus.accepted));
  }

  /// Decline an incoming call
  Future<void> declineCall(Call call) async {
    final participant = _config.currentUser;
    if (participant == null) {
      throw Exception('Current user not configured');
    }

    await _adapter.declineCall(
      callId: call.callId,
      participant: participant,
    );

    final declinedCall = call.copyWith(status: CallStatus.declined, duration: 0);
    _repository.addToHistory(declinedCall);
    _repository.clearActiveCall();
  }

  /// End an active call
  Future<void> endCall(Call call, {int? duration}) async {
    await _adapter.endCall(
      callId: call.callId,
      duration: duration,
    );

    final endedCall = call.copyWith(status: CallStatus.ended, duration: duration);
    _repository.addToHistory(endedCall);
    _repository.clearActiveCall();
  }

  /// Get call history
  Future<List<Call>> getCallHistory({int? limit, int? offset}) async {
    await _repository.loadCallHistory(
      limit: limit ?? 50,
      offset: offset ?? 0,
    );
    return _repository.callHistory;
  }

  /// Current call repository (for accessing state)
  CallRepository get repository => _repository;

  void _handleCallEvent(dynamic event) {
    // Handle events from backend
    // This would be expanded based on the actual event types
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _adapter.dispose();
    _repository.dispose();
  }
}
