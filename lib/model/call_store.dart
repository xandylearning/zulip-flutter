import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zulip_call_kit/zulip_call_kit.dart' as call_kit;
import 'package:zulip_call_kit/zulip_call_kit.dart';

import '../api/model/call.dart';
import '../api/route/calls.dart' as api;
import '../api/model/events.dart' as zulip_events;
import 'store.dart';

/// Store for call-related data
///
/// This is a bridge between Zulip's store architecture and the call plugin.
class CallStore extends PerAccountStoreBase with ChangeNotifier {
  CallStore({required super.core})  : _repository = call_kit.CallRepository(
      adapter: _DummyAdapter(), // Will be replaced with real adapter
    ) {
    _callHistoryController = StreamController<List<Call>>.broadcast();
    _incomingCallController = StreamController<Call>.broadcast();
    _hasActiveCallController = StreamController<bool>.broadcast();
    loadCallHistory();
  }

  final call_kit.CallRepository _repository;

  /// Single source of truth: All calls indexed by callId
  final Map<String, Call> _calls = {};

  /// Queued calls indexed by queueId
  final Map<String, CallQueueEntry> _queuedCalls = {};

  /// Track last call attempt per user for cooldown (userId -> timestamp)
  final Map<int, DateTime> _lastCallAttempts = {};

  /// Cooldown duration between call attempts to same user (race condition prevention)
  static const Duration callCooldown = Duration(seconds: 5);

  /// The currently active call (first call with active status)
  Call? get activeCall {
    for (final call in _calls.values) {
      if (call.status.isActive) return call;
    }
    return null;
  }

  /// Pending outgoing calls (created or ringing state)
  List<Call> get pendingCalls => _calls.values
      .where((call) => call.status == CallStatus.created || call.status == CallStatus.ringing)
      .toList();

  /// Queued calls waiting for recipient to be available
  List<CallQueueEntry> get queuedCalls => _queuedCalls.values.toList();

  /// History of completed calls
  List<call_kit.Call> get callHistory => _repository.callHistory;

  /// Whether call history is currently being loaded
  bool get isLoadingHistory => _repository.isLoadingHistory;

  /// Stream for call history updates
  late final StreamController<List<Call>> _callHistoryController;
  Stream<List<Call>> get callHistoryStream => _callHistoryController.stream;

  /// Stream for incoming calls
  late final StreamController<Call> _incomingCallController;
  Stream<Call> get incomingCallStream => _incomingCallController.stream;

  /// Stream for active call state changes
  late final StreamController<bool> _hasActiveCallController;
  Stream<bool> get hasActiveCallStream => _hasActiveCallController.stream;

  /// Track timeout timers
  final Map<String, Timer> _callTimeoutTimers = {};

  /// Check if we can call a user (cooldown check for race condition prevention)
  bool canCallUser(int userId) {
    final lastAttempt = _lastCallAttempts[userId];
    if (lastAttempt == null) return true;

    final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
    return timeSinceLastAttempt >= callCooldown;
  }

  /// Get remaining cooldown time for a user
  Duration getRemainingCooldown(int userId) {
    final lastAttempt = _lastCallAttempts[userId];
    if (lastAttempt == null) return Duration.zero;

    final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
    final remaining = callCooldown - timeSinceLastAttempt;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Record call attempt timestamp (for cooldown tracking)
  void _recordCallAttempt(int userId) {
    _lastCallAttempts[userId] = DateTime.now();
  }

  /// Get a call by ID from the unified map
  Call? getCall(String callId) {
    return _calls[callId];
  }

  /// Update or add a call to the store with state validation
  void _updateCall(Call call) {
    final existingCall = _calls[call.callId];

    // Validate state transition if there's an existing call
    if (existingCall != null && !existingCall.status.canTransitionTo(call.status)) {
      debugPrint('CallStore: Invalid state transition from ${existingCall.status} to ${call.status} for call ${call.callId}');
      return;
    }

    _calls[call.callId] = call;

    // Update repository for active/pending calls
    if (call.status.isActive) {
      _repository.setActiveCall(call);
    } else if (call.status.isTerminal && existingCall != null) {
      _repository.addToHistory(call);
      _repository.clearActiveCall();
    }
  }

  void handleCallCreatedEvent(zulip_events.CallCreatedEvent event) {
    final call = event.call;
    debugPrint('CallStore: handleCallCreatedEvent: callId=${call.callId}');

    // Check for duplicate/stale events (idempotency)
    final existingCall = _calls[call.callId];
    if (existingCall != null && existingCall.timestamp != null && call.timestamp != null) {
      if (call.timestamp! <= existingCall.timestamp!) {
        debugPrint('CallStore: Ignoring stale CallCreatedEvent for ${call.callId}');
        return;
      }
    }

    if (call.callerId == core.selfUserId) {
      // Outgoing call - record attempt for cooldown
      _recordCallAttempt(call.recipientId);
      _updateCall(call);
      _startCallTimeout(call.callId);
    } else {
      // Incoming call
      _updateCall(call);
      _incomingCallController.add(call);
    }

    _notifyCallStateChange();
  }

  void handleCallAcknowledgedEvent(zulip_events.CallAcknowledgedEvent event) {
    _cancelCallTimeout(event.callId);

    final call = _calls[event.callId];
    if (call != null) {
      _updateCall(call.copyWith(status: CallStatus.ringing));
      _notifyCallStateChange();
    }
  }

  void handleCallAcceptedEvent(zulip_events.CallAcceptedEvent event) {
    _cancelCallTimeout(event.callId);

    final call = _calls[event.callId];
    if (call != null) {
      _updateCall(call.copyWith(status: CallStatus.accepted));
      _notifyCallStateChange();
    }
  }

  void handleCallDeclinedEvent(zulip_events.CallDeclinedEvent event) {
    _cancelCallTimeout(event.callId);

    final call = _calls[event.callId];
    if (call != null) {
      _updateCall(call.copyWith(status: CallStatus.declined, duration: 0));
      _notifyCallStateChange();
    }
  }

  void handleCallEndedEvent(zulip_events.CallEndedEvent event) {
    final call = _calls[event.callId];
    if (call != null) {
      _updateCall(call.copyWith(
        status: CallStatus.ended,
        duration: event.duration,
      ));
      _notifyCallStateChange();
    }
  }

  void handleCallCancelledEvent(zulip_events.CallCancelledEvent event) {
    _cancelCallTimeout(event.callId);

    final call = _calls[event.callId];
    if (call != null) {
      _updateCall(call.copyWith(status: CallStatus.cancelled, duration: 0));
      _notifyCallStateChange();
    }
  }

  /// Handle call queued event (new in v2.0)
  void handleCallQueuedEvent(zulip_events.CallQueuedEvent event) {
    debugPrint('CallStore: Call ${event.callId} queued with queueId ${event.queueId}');

    // Add to queued calls map
    final queueEntry = CallQueueEntry(
      queueId: event.queueId,
      caller: UserInfo(
        userId: core.selfUserId,
        fullName: '', // Will be filled by caller
        email: '',
      ),
      callType: _calls[event.callId]?.callType == CallType.video ? 'video' : 'audio',
      createdAt: DateTime.now().toIso8601String(),
      expiresAt: event.expiresAt,
    );

    _queuedCalls[event.queueId] = queueEntry;

    // Update call status to queued
    final call = _calls[event.callId];
    if (call != null) {
      _updateCall(call.copyWith(status: CallStatus.queued));
    }

    _notifyCallStateChange();
  }

  /// Handle network failure event (new in v2.0)
  void handleNetworkFailureEvent(zulip_events.CallNetworkFailureEvent event) {
    debugPrint('CallStore: Network failure for call ${event.callId}');

    final call = _calls[event.callId];
    if (call != null) {
      // End the call due to network failure
      _updateCall(call.copyWith(status: CallStatus.ended, duration: 0));
      _notifyCallStateChange();
    }
  }

  /// Handle participant left event (new in v2.0)
  void handleParticipantLeftEvent(zulip_events.ParticipantLeftEvent event) {
    debugPrint('CallStore: Participant ${event.userId} left call ${event.callId}');

    final call = _calls[event.callId];
    if (call != null) {
      // If the other participant left, end the call
      if (event.userId != core.selfUserId) {
        _updateCall(call.copyWith(status: CallStatus.ended));
        _notifyCallStateChange();
      }
    }
  }

  Call? get firstPendingCall {
    return pendingCalls.isNotEmpty ? pendingCalls.first : null;
  }

  void addPendingOutgoingCall(Call call) {
    _recordCallAttempt(call.recipientId);
    _updateCall(call);
    _startCallTimeout(call.callId);
    _notifyCallStateChange();
  }

  bool get hasActiveCall => activeCall != null || pendingCalls.isNotEmpty;

  void _notifyCallStateChange() {
    notifyListeners();
    _hasActiveCallController.add(hasActiveCall);
  }

  void _startCallTimeout(String callId) {
    _callTimeoutTimers[callId] = Timer(const Duration(seconds: 45), () {
      _handleCallTimeout(callId);
    });
  }

  void _cancelCallTimeout(String callId) {
    _callTimeoutTimers[callId]?.cancel();
    _callTimeoutTimers.remove(callId);
  }

  void _handleCallTimeout(String callId) {
    final call = _calls[callId];
    if (call != null && !call.status.isTerminal) {
      _cancelCallOnServer(callId);
      _updateCall(call.copyWith(
        status: CallStatus.cancelled,
        duration: 0,
      ));
      _notifyCallStateChange();
    }
  }

  Future<void> _cancelCallOnServer(String callId) async {
    try {
      await api.cancelCall(core.connection, callId: callId);
    } catch (e) {
      debugPrint('Failed to cancel call on server: $e');
    }
  }

  Future<void> loadCallHistory({
    int limit = 50,
    String? cursor,
    String? callType,
    String? status,
  }) async {
    try {
      final response = await api.getCallHistory(
        core.connection,
        limit: limit,
        cursor: cursor,
        callType: callType,
        status: status,
      );

      // Convert to Call objects and update repository
      final calls = response.calls.map((historicalCall) {
        final callStatus = _parseCallStatus(historicalCall.state);
        final timestamp = DateTime.parse(historicalCall.createdAt).millisecondsSinceEpoch ~/ 1000;

        final int callerId;
        final int recipientId;
        if (historicalCall.wasInitiator) {
          callerId = core.selfUserId;
          recipientId = historicalCall.otherUser.userId;
        } else {
          callerId = historicalCall.otherUser.userId;
          recipientId = core.selfUserId;
        }

        final callType = historicalCall.callType == 'video'
            ? call_kit.CallType.video
            : call_kit.CallType.audio;

        return call_kit.Call(
          callId: historicalCall.callId,
          callerId: callerId,
          recipientId: recipientId,
          callType: callType,
          status: callStatus,
          jitsiUrl: '',
          timestamp: timestamp,
          duration: historicalCall.durationSeconds ?? 0,
        );
      }).toList();

      for (final call in calls) {
        _repository.addToHistory(call);
      }

      _callHistoryController.add(callHistory);
    } catch (e) {
      debugPrint('Failed to load call history: $e');
    }
  }

  CallStatus _parseCallStatus(String state) {
    switch (state) {
      case 'ended':
        return CallStatus.ended;
      case 'declined':
        return CallStatus.declined;
      case 'cancelled':
        return CallStatus.cancelled;
      case 'accepted':
        return CallStatus.accepted;
      case 'ringing':
        return CallStatus.ringing;
      case 'queued':
        return CallStatus.queued;
      default:
        return CallStatus.ended;
    }
  }

  Future<void> endAllActiveCalls() async {
    try {
      await api.endAllCalls(core.connection);
    } catch (e) {
      debugPrint('Failed to end all calls: $e');
    }

    // Cancel all timeout timers
    for (final timer in _callTimeoutTimers.values) {
      timer.cancel();
    }
    _callTimeoutTimers.clear();

    // End all active calls
    for (final call in _calls.values.where((c) => c.status.isActive).toList()) {
      _updateCall(call.copyWith(status: CallStatus.ended, duration: 0));
    }

    // Clear queued calls
    _queuedCalls.clear();

    _repository.clearActiveCall();
    _notifyCallStateChange();
  }

  @override
  void dispose() {
    for (final timer in _callTimeoutTimers.values) {
      timer.cancel();
    }
    _callTimeoutTimers.clear();

    _callHistoryController.close();
    _incomingCallController.close();
    _hasActiveCallController.close();
    super.dispose();
  }
}

// Dummy adapter for now - will be replaced with real adapter
class _DummyAdapter implements call_kit.CallBackendAdapter {
  @override
  Future<call_kit.CallSession> createCall({
    required call_kit.CallParticipant initiator,
    required call_kit.CallParticipant recipient,
    required CallType type,
    Map<String, dynamic>? metadata,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> acknowledgeCall({
    required String callId,
    required call_kit.CallParticipant participant,
  }) async {}

  @override
  Future<void> acceptCall({
    required String callId,
    required call_kit.CallParticipant participant,
  }) async {}

  @override
  Future<void> declineCall({
    required String callId,
    required call_kit.CallParticipant participant,
  }) async {}

  @override
  Future<void> endCall({
    required String callId,
    int? duration,
  }) async {}

  @override
  Future<void> cancelCall({required String callId}) async {}

  @override
  Future<void> sendHeartbeat({
    required String callId,
    bool isBackgrounded = false,
  }) async {}

  @override
  Future<List<Call>> getCallHistory({
    int? limit,
    int? offset,
    String? userId,
    CallStatus? status,
  }) async {
    return [];
  }

  @override
  Stream<call_kit.CallEvent> get callEvents => const Stream.empty();

  @override
  Future<void> dispose() async {}
}
