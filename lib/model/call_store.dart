import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../api/model/call.dart';
import '../api/route/calls.dart' as api;
import '../api/model/events.dart';
import 'store.dart';

/// Store for call-related data.
class CallStore extends PerAccountStoreBase with ChangeNotifier {
  CallStore({required super.core}) {
    _callHistoryController = StreamController<List<Call>>.broadcast();
    _incomingCallController = StreamController<Call>.broadcast();
    _hasActiveCallController = StreamController<bool>.broadcast();
    // Load call history from server
    loadCallHistory();
  }

  /// The currently active call, if any.
  Call? _activeCall;
  Call? get activeCall => _activeCall;

  /// History of completed calls.
  final List<Call> _callHistory = [];
  List<Call> get callHistory => List.unmodifiable(_callHistory);

  /// Whether call history is currently being loaded from the server.
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  /// Stream for call history updates.
  late final StreamController<List<Call>> _callHistoryController;
  Stream<List<Call>> get callHistoryStream => _callHistoryController.stream;

  /// Stream for incoming calls.
  late final StreamController<Call> _incomingCallController;
  Stream<Call> get incomingCallStream => _incomingCallController.stream;

  /// Stream for active call state changes.
  late final StreamController<bool> _hasActiveCallController;
  Stream<bool> get hasActiveCallStream => _hasActiveCallController.stream;

  /// Track pending outgoing calls (calls we initiated that haven't been answered yet).
  final Map<String, Call> _pendingOutgoingCalls = {};

  /// Track timeout timers for pending calls (45-second timeout).
  final Map<String, Timer> _callTimeoutTimers = {};

  /// Track call creation timestamps for timeout management.
  final Map<String, DateTime> _callCreationTimes = {};

  void handleCallCreatedEvent(CallCreatedEvent event) {
    final call = event.call;
    debugPrint('CallStore: handleCallCreatedEvent: callId=${call.callId}, callerId=${call.callerId}, selfUserId=${core.selfUserId}');

    // If we're the caller, this is an outgoing call we're waiting on
    if (call.callerId == core.selfUserId) {
      _pendingOutgoingCalls[call.callId] = call;
      _callCreationTimes[call.callId] = DateTime.now();
      debugPrint('CallStore: Added to pending outgoing calls');

      // Start 45-second timeout timer for unanswered calls
      _startCallTimeout(call.callId);
    } else {
      // Incoming call - notify listeners and stream
      debugPrint('CallStore: INCOMING CALL DETECTED - Adding to stream controller');
      debugPrint('CallStore: Stream controller has ${_incomingCallController.hasListener ? "listeners" : "NO listeners"}');
      _activeCall = call;
      _incomingCallController.add(call);
      debugPrint('CallStore: Set as active call (incoming) and added to stream');
    }

    debugPrint('CallStore: hasActiveCall: $hasActiveCall');
    _notifyCallStateChange();
  }

  void handleCallAcknowledgedEvent(CallAcknowledgedEvent event) {
    // Cancel timeout timer since call was acknowledged
    _cancelCallTimeout(event.callId);

    // Update call status if it's the active call
    if (_activeCall?.callId == event.callId) {
      _activeCall = Call(
        callId: _activeCall!.callId,
        callerId: _activeCall!.callerId,
        recipientId: _activeCall!.recipientId,
        callType: _activeCall!.callType,
        status: CallStatus.ringing,
        jitsiUrl: _activeCall!.jitsiUrl,
        timestamp: _activeCall!.timestamp,
        duration: _activeCall!.duration,
      );
      _notifyCallStateChange();
      return;
    }

    // Update pending outgoing call status
    if (_pendingOutgoingCalls.containsKey(event.callId)) {
      final call = _pendingOutgoingCalls[event.callId]!;
      _pendingOutgoingCalls[event.callId] = Call(
        callId: call.callId,
        callerId: call.callerId,
        recipientId: call.recipientId,
        callType: call.callType,
        status: CallStatus.ringing,
        jitsiUrl: call.jitsiUrl,
        timestamp: call.timestamp,
        duration: call.duration,
      );
      _notifyCallStateChange();
    }
  }

  void handleCallAcceptedEvent(CallAcceptedEvent event) {
    debugPrint('CallStore: handleCallAcceptedEvent: callId=${event.callId}, userId=${event.userId}');
    debugPrint('CallStore: Current active call: ${_activeCall?.callId}');
    debugPrint('CallStore: Pending outgoing calls: ${_pendingOutgoingCalls.keys}');
    debugPrint('CallStore: Self user ID: ${core.selfUserId}');

    // Cancel timeout timer since call was accepted
    _cancelCallTimeout(event.callId);

    // Update call status to accepted
    if (_activeCall?.callId == event.callId) {
      _activeCall = Call(
        callId: _activeCall!.callId,
        callerId: _activeCall!.callerId,
        recipientId: _activeCall!.recipientId,
        callType: _activeCall!.callType,
        status: CallStatus.accepted,
        jitsiUrl: _activeCall!.jitsiUrl,
        timestamp: _activeCall!.timestamp,
        duration: _activeCall!.duration,
      );
      debugPrint('CallStore: Updated active call status to accepted');
      debugPrint('CallStore: About to notify listeners of state change');
      _notifyCallStateChange();
      debugPrint('CallStore: State change notification sent');
      return;
    }

    // For outgoing calls, move from pending to active
    if (_pendingOutgoingCalls.containsKey(event.callId)) {
      debugPrint('CallStore: Found call in pending outgoing calls, moving to active');
      _activeCall = _pendingOutgoingCalls.remove(event.callId);
      if (_activeCall != null) {
        _activeCall = Call(
          callId: _activeCall!.callId,
          callerId: _activeCall!.callerId,
          recipientId: _activeCall!.recipientId,
          callType: _activeCall!.callType,
          status: CallStatus.accepted,
          jitsiUrl: _activeCall!.jitsiUrl,
          timestamp: _activeCall!.timestamp,
          duration: _activeCall!.duration,
        );
        debugPrint('CallStore: Moved pending call to active with accepted status');
        debugPrint('CallStore: About to notify listeners of state change');
        _notifyCallStateChange();
        debugPrint('CallStore: State change notification sent');
      }
    } else {
      debugPrint('CallStore: Call not found in pending outgoing calls');
    }

    debugPrint('CallStore: hasActiveCall: $hasActiveCall');
  }

  void handleCallDeclinedEvent(CallDeclinedEvent event) {
    debugPrint('CallStore: handleCallDeclinedEvent: callId=${event.callId}');

    // Cancel timeout timer since call was declined
    _cancelCallTimeout(event.callId);

    // Handle active call being declined
    if (_activeCall?.callId == event.callId) {
      final declinedCall = Call(
        callId: _activeCall!.callId,
        callerId: _activeCall!.callerId,
        recipientId: _activeCall!.recipientId,
        callType: _activeCall!.callType,
        status: CallStatus.declined,
        jitsiUrl: _activeCall!.jitsiUrl,
        timestamp: _activeCall!.timestamp,
        duration: 0, // No duration for declined calls
      );
      _callHistory.insert(0, declinedCall); // Add to history at the start
      _callHistoryController.add(callHistory);
      _activeCall = null;
    }

    // Handle pending outgoing call being declined
    if (_pendingOutgoingCalls.containsKey(event.callId)) {
      debugPrint('CallStore: Pending outgoing call declined');
      final pendingCall = _pendingOutgoingCalls[event.callId]!;
      final declinedCall = Call(
        callId: pendingCall.callId,
        callerId: pendingCall.callerId,
        recipientId: pendingCall.recipientId,
        callType: pendingCall.callType,
        status: CallStatus.declined,
        jitsiUrl: pendingCall.jitsiUrl,
        timestamp: pendingCall.timestamp,
        duration: 0,
      );

      // First update the pending call with declined status so UI can see it
      _pendingOutgoingCalls[event.callId] = declinedCall;
      debugPrint('CallStore: Updated pending call status to declined, notifying listeners');
      _notifyCallStateChange();

      // Then after a brief moment, move to history and remove from pending
      Future.delayed(const Duration(milliseconds: 100), () {
        _pendingOutgoingCalls.remove(event.callId);
        _callHistory.insert(0, declinedCall);
        _callHistoryController.add(callHistory);
        _callCreationTimes.remove(event.callId);
        debugPrint('CallStore: Moved declined call to history');
        _notifyCallStateChange();
      });
      return;
    }

    _callCreationTimes.remove(event.callId);
    _notifyCallStateChange();
  }

  void handleCallEndedEvent(CallEndedEvent event) {
    // Move call to history and clear active call
    if (_activeCall?.callId == event.callId) {
      final endedCall = Call(
        callId: _activeCall!.callId,
        callerId: _activeCall!.callerId,
        recipientId: _activeCall!.recipientId,
        callType: _activeCall!.callType,
        status: CallStatus.ended,
        jitsiUrl: _activeCall!.jitsiUrl,
        timestamp: _activeCall!.timestamp,
        duration: event.duration,
      );
      _callHistory.insert(0, endedCall); // Add to history at the start
      _callHistoryController.add(callHistory);
      _activeCall = null;
      _notifyCallStateChange();
    }
  }

  void handleCallCancelledEvent(CallCancelledEvent event) {
    // Cancel timeout timer since call was cancelled
    _cancelCallTimeout(event.callId);

    // Remove from active/pending calls
    if (_activeCall?.callId == event.callId) {
      final cancelledCall = Call(
        callId: _activeCall!.callId,
        callerId: _activeCall!.callerId,
        recipientId: _activeCall!.recipientId,
        callType: _activeCall!.callType,
        status: CallStatus.cancelled,
        jitsiUrl: _activeCall!.jitsiUrl,
        timestamp: _activeCall!.timestamp,
        duration: 0, // No duration for cancelled calls
      );
      _callHistory.insert(0, cancelledCall); // Add to history at the start
      _callHistoryController.add(callHistory);
      _activeCall = null;
    }

    _pendingOutgoingCalls.remove(event.callId);
    _callCreationTimes.remove(event.callId);
    _notifyCallStateChange();
  }

  /// Get a call from either active or pending lists.
  Call? getCall(String callId) {
    developer.log('getCall: Looking for callId=$callId', name: 'CallStore');
    developer.log('getCall: Active call=${_activeCall?.callId}', name: 'CallStore');
    developer.log('getCall: Pending calls=${_pendingOutgoingCalls.keys}', name: 'CallStore');

    // Check active call first
    if (_activeCall?.callId == callId) {
      developer.log('getCall: Found in active call', name: 'CallStore');
      return _activeCall;
    }

    // Check pending calls
    final pendingCall = _pendingOutgoingCalls[callId];
    if (pendingCall != null) {
      developer.log('getCall: Found in pending calls', name: 'CallStore');
      return pendingCall;
    }

    // Check call history as fallback
    final historyCall = _callHistory.firstWhere(
      (call) => call.callId == callId,
      orElse: () => Call(
        callId: '',
        callerId: 0,
        recipientId: 0,
        callType: CallType.audio,
        status: CallStatus.ended,
        jitsiUrl: '',
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        duration: 0,
      ),
    );

    if (historyCall.callId.isNotEmpty) {
      developer.log('getCall: Found in call history', name: 'CallStore');
      return historyCall;
    }

    developer.log('getCall: Call not found anywhere', name: 'CallStore');
    return null;
  }

  /// Get the first pending outgoing call, if any.
  Call? get firstPendingCall {
    if (_pendingOutgoingCalls.isEmpty) return null;
    return _pendingOutgoingCalls.values.first;
  }

  /// Manually add a call to pending outgoing calls (fallback for when CallCreatedEvent is not received).
  void addPendingOutgoingCall(Call call) {
    debugPrint('CallStore: addPendingOutgoingCall: callId=${call.callId}, callerId=${call.callerId}, selfUserId=${core.selfUserId}');
    debugPrint('CallStore: Before adding - pending calls: ${_pendingOutgoingCalls.keys}');

    _pendingOutgoingCalls[call.callId] = call;
    _callCreationTimes[call.callId] = DateTime.now();

    debugPrint('CallStore: After adding - pending calls: ${_pendingOutgoingCalls.keys}');
    debugPrint('CallStore: Manually added to pending outgoing calls');

    // Start 45-second timeout timer for unanswered calls
    _startCallTimeout(call.callId);
    _notifyCallStateChange();

    debugPrint('CallStore: addPendingOutgoingCall completed');
  }

  /// Check if there's an active or pending outgoing call.
  bool get hasActiveCall {
    final result = _activeCall != null || _pendingOutgoingCalls.isNotEmpty;
    developer.log('hasActiveCall: $result (activeCall=${_activeCall?.callId}, pendingCalls=${_pendingOutgoingCalls.keys})', name: 'CallStore');
    return result;
  }

  /// Helper method to notify listeners and emit stream event when call state changes.
  void _notifyCallStateChange() {
    final currentHasActiveCall = hasActiveCall;
    developer.log('_notifyCallStateChange: hasActiveCall=$currentHasActiveCall, activeCall=${_activeCall?.callId}', name: 'CallStore');
    notifyListeners();
    _hasActiveCallController.add(currentHasActiveCall);
  }

  /// Start a 45-second timeout timer for a call.
  void _startCallTimeout(String callId) {
    _callTimeoutTimers[callId] = Timer(const Duration(seconds: 45), () {
      _handleCallTimeout(callId);
    });
  }

  /// Cancel the timeout timer for a call.
  void _cancelCallTimeout(String callId) {
    _callTimeoutTimers[callId]?.cancel();
    _callTimeoutTimers.remove(callId);
  }

  /// Handle call timeout - cancel the call if it hasn't been answered.
  void _handleCallTimeout(String callId) {
    if (_pendingOutgoingCalls.containsKey(callId)) {
      // Cancel the call on the server
      _cancelCallOnServer(callId);

      // Remove from pending calls
      final timedOutCall = _pendingOutgoingCalls.remove(callId);
      _callCreationTimes.remove(callId);

      if (timedOutCall != null) {
        // Add to history as cancelled due to timeout
        final cancelledCall = Call(
          callId: timedOutCall.callId,
          callerId: timedOutCall.callerId,
          recipientId: timedOutCall.recipientId,
          callType: timedOutCall.callType,
          status: CallStatus.cancelled,
          jitsiUrl: timedOutCall.jitsiUrl,
          timestamp: timedOutCall.timestamp,
          duration: 0,
        );
        _callHistory.insert(0, cancelledCall);
        _callHistoryController.add(callHistory);
      }

      _notifyCallStateChange();
    }
  }

  /// Cancel a call on the server.
  Future<void> _cancelCallOnServer(String callId) async {
    try {
      await api.cancelCall(core.connection, callId: callId);
    } catch (e) {
      // Log error but don't throw - this is cleanup
      debugPrint('Failed to cancel call on server: $e');
    }
  }

  /// Load call history from the server.
  ///
  /// Fetches historical calls from the server API and merges them with
  /// the local call history, removing duplicates.
  ///
  /// This method is called automatically when the CallStore is created,
  /// and can also be called manually to refresh the history (e.g., pull-to-refresh).
  Future<void> loadCallHistory({int limit = 50, int offset = 0}) async {
    if (_isLoadingHistory) return; // Prevent concurrent loads

    _isLoadingHistory = true;
    notifyListeners();

    try {
      debugPrint('CallStore: Loading call history with limit=$limit, offset=$offset');
      final response = await api.getCallHistory(
        core.connection,
        limit: limit,
        offset: offset,
      );
      debugPrint('CallStore: Received call history response with ${response.calls.length} calls');

      // Convert HistoricalCall objects to Call objects
      final serverCalls = response.calls.map((historicalCall) {
        debugPrint('CallStore: Processing historical call ${historicalCall.callId}, duration: ${historicalCall.durationSeconds}');
        // Determine call status from server state
        final CallStatus status;
        switch (historicalCall.state) {
          case 'ended':
            status = CallStatus.ended;
          case 'declined':
            status = CallStatus.declined;
          case 'cancelled':
            status = CallStatus.cancelled;
          default:
            status = CallStatus.ended; // Default to ended for unknown states
        }

        // Parse timestamp
        final timestamp = DateTime.parse(historicalCall.createdAt).millisecondsSinceEpoch ~/ 1000;

        // Determine caller and recipient
        final int callerId;
        final int recipientId;
        if (historicalCall.wasInitiator) {
          callerId = core.selfUserId;
          recipientId = historicalCall.otherUser.userId;
        } else {
          callerId = historicalCall.otherUser.userId;
          recipientId = core.selfUserId;
        }

        // Parse call type
        final callType = historicalCall.callType == 'video' ? CallType.video : CallType.audio;

        return Call(
          callId: historicalCall.callId,
          callerId: callerId,
          recipientId: recipientId,
          callType: callType,
          status: status,
          jitsiUrl: '', // Historical calls don't need Jitsi URL
          timestamp: timestamp,
          duration: historicalCall.durationSeconds ?? 0, // Handle null duration
        );
      }).toList();

      // Merge with existing history, removing duplicates
      final existingCallIds = _callHistory.map((c) => c.callId).toSet();
      for (final serverCall in serverCalls) {
        if (!existingCallIds.contains(serverCall.callId)) {
          _callHistory.add(serverCall);
        }
      }

      // Sort by timestamp (most recent first)
      // Handle null timestamps by putting them at the end
      _callHistory.sort((a, b) {
        if (a.timestamp == null && b.timestamp == null) return 0;
        if (a.timestamp == null) return 1; // a goes after b
        if (b.timestamp == null) return -1; // b goes after a
        return b.timestamp!.compareTo(a.timestamp!);
      });

      _callHistoryController.add(callHistory);
      notifyListeners();
    } catch (e) {
      debugPrint('CallStore: Failed to load call history: $e');
      debugPrint('CallStore: Error type: ${e.runtimeType}');
      debugPrint('CallStore: Full error details: ${e.toString()}');

      // Check for specific malformed response errors
      if (e.toString().contains('malformed response')) {
        debugPrint('CallStore: Server returned malformed response - likely null values in expected number fields');
      }
      if (e.toString().contains('type \'Null\' is not a subtype of type \'num\'')) {
        debugPrint('CallStore: Type casting error - server returned null where number expected');
      }

      // Don't throw - just log the error and continue
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// End all active calls (used when app is killed).
  Future<void> endAllActiveCalls() async {
    try {
      // Use the new end-all endpoint for efficiency
      await api.endAllCalls(core.connection);
      debugPrint('Successfully ended all calls via end-all endpoint');
    } catch (e) {
      debugPrint('Failed to end all calls via end-all endpoint: $e');
      // Fallback to individual call ending
      await _endAllCallsIndividually();
    }

    // Clear all local state
    for (final timer in _callTimeoutTimers.values) {
      timer.cancel();
    }
    _callTimeoutTimers.clear();
    _pendingOutgoingCalls.clear();
    _callCreationTimes.clear();
    _activeCall = null;

    _notifyCallStateChange();
  }

  /// Fallback method to end calls individually.
  Future<void> _endAllCallsIndividually() async {
    // End active call if any
    if (_activeCall != null) {
      try {
        await api.endCall(core.connection, callId: _activeCall!.callId);
      } catch (e) {
        debugPrint('Failed to end active call: $e');
      }
    }

    // Cancel all pending outgoing calls
    for (final callId in _pendingOutgoingCalls.keys.toList()) {
      try {
        await api.cancelCall(core.connection, callId: callId);
      } catch (e) {
        debugPrint('Failed to cancel pending call $callId: $e');
      }
    }
  }

  @override
  void dispose() {
    // Cancel all timers
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


