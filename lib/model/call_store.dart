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

  /// The currently active call, if any
  Call? get activeCall => _repository.activeCall;

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

  /// Track pending outgoing calls
  final Map<String, Call> _pendingOutgoingCalls = {};

  /// Track timeout timers
  final Map<String, Timer> _callTimeoutTimers = {};

  /// Track call creation timestamps
  final Map<String, DateTime> _callCreationTimes = {};

  void handleCallCreatedEvent(zulip_events.CallCreatedEvent event) {
    final call = event.call;
    debugPrint('CallStore: handleCallCreatedEvent: callId=${call.callId}');

    if (call.callerId == core.selfUserId) {
      _repository.addPendingOutgoingCall(call);
      _callCreationTimes[call.callId] = DateTime.now();
      _startCallTimeout(call.callId);
    } else {
      _repository.setActiveCall(call);
      _incomingCallController.add(call);
    }

    _notifyCallStateChange();
  }

  void handleCallAcknowledgedEvent(zulip_events.CallAcknowledgedEvent event) {
    _cancelCallTimeout(event.callId);

    if (activeCall?.callId == event.callId) {
      _repository.setActiveCall(activeCall!.copyWith(status: CallStatus.ringing));
      _notifyCallStateChange();
    }
  }

  void handleCallAcceptedEvent(zulip_events.CallAcceptedEvent event) {
    _cancelCallTimeout(event.callId);

    if (activeCall?.callId == event.callId) {
      _repository.setActiveCall(activeCall!.copyWith(status: CallStatus.accepted));
      _notifyCallStateChange();
    } else if (_pendingOutgoingCalls.containsKey(event.callId)) {
      final call = _pendingOutgoingCalls.remove(event.callId)!;
      _repository.setActiveCall(call.copyWith(status: CallStatus.accepted));
      _notifyCallStateChange();
    }
  }

  void handleCallDeclinedEvent(zulip_events.CallDeclinedEvent event) {
    _cancelCallTimeout(event.callId);

    if (activeCall?.callId == event.callId) {
      final declinedCall = activeCall!.copyWith(status: CallStatus.declined, duration: 0);
      _repository.addToHistory(declinedCall);
      _repository.clearActiveCall();
    } else if (_pendingOutgoingCalls.containsKey(event.callId)) {
      final call = _pendingOutgoingCalls.remove(event.callId)!;
      _repository.addToHistory(call.copyWith(status: CallStatus.declined, duration: 0));
    }

    _callCreationTimes.remove(event.callId);
    _notifyCallStateChange();
  }

  void handleCallEndedEvent(zulip_events.CallEndedEvent event) {
    if (activeCall?.callId == event.callId) {
      final endedCall = activeCall!.copyWith(
        status: CallStatus.ended,
        duration: event.duration as int?,
      );
      _repository.addToHistory(endedCall);
      _repository.clearActiveCall();
      _notifyCallStateChange();
    }
  }

  void handleCallCancelledEvent(zulip_events.CallCancelledEvent event) {
    _cancelCallTimeout(event.callId);

    if (activeCall?.callId == event.callId) {
      final cancelledCall = activeCall!.copyWith(status: CallStatus.cancelled, duration: 0);
      _repository.addToHistory(cancelledCall);
      _repository.clearActiveCall();
    }

    _pendingOutgoingCalls.remove(event.callId);
    _callCreationTimes.remove(event.callId);
    _notifyCallStateChange();
  }

  Call? getCall(String callId) {
    return _repository.getCall(callId) ?? _pendingOutgoingCalls[callId];
  }

  Call? get firstPendingCall {
    if (_pendingOutgoingCalls.isEmpty) return null;
    return _pendingOutgoingCalls.values.first;
  }

  void addPendingOutgoingCall(Call call) {
    _pendingOutgoingCalls[call.callId] = call;
    _repository.addPendingOutgoingCall(call);
    _callCreationTimes[call.callId] = DateTime.now();
    _startCallTimeout(call.callId);
    _notifyCallStateChange();
  }

  bool get hasActiveCall => _repository.hasActiveCall || _pendingOutgoingCalls.isNotEmpty;

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
    if (_pendingOutgoingCalls.containsKey(callId)) {
      _cancelCallOnServer(callId);
      final timedOutCall = _pendingOutgoingCalls.remove(callId);
      _callCreationTimes.remove(callId);

      if (timedOutCall != null) {
        _repository.addToHistory(timedOutCall.copyWith(
          status: CallStatus.cancelled,
          duration: 0,
        ));
      }

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

  Future<void> loadCallHistory({int limit = 50, int offset = 0}) async {
    await _repository.loadCallHistory(limit: limit, offset: offset);
    _callHistoryController.add(callHistory);
  }

  Future<void> endAllActiveCalls() async {
    try {
      await api.endAllCalls(core.connection);
    } catch (e) {
      debugPrint('Failed to end all calls: $e');
    }

    for (final timer in _callTimeoutTimers.values) {
      timer.cancel();
    }
    _callTimeoutTimers.clear();
    _pendingOutgoingCalls.clear();
    _callCreationTimes.clear();
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
