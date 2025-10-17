import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/call.dart';
import '../adapters/call_backend_adapter.dart';

/// Repository for call data management
///
/// This is a wrapper around CallBackendAdapter that provides
/// additional caching, state management, and business logic.
class CallRepository with ChangeNotifier {
  CallRepository({required CallBackendAdapter adapter}) : _adapter = adapter {
    _callHistoryController = StreamController<List<Call>>.broadcast();
    _incomingCallController = StreamController<Call>.broadcast();
    _hasActiveCallController = StreamController<bool>.broadcast();
  }

  final CallBackendAdapter _adapter;

  /// The currently active call, if any
  Call? _activeCall;
  Call? get activeCall => _activeCall;

  /// History of completed calls
  final List<Call> _callHistory = [];
  List<Call> get callHistory => List.unmodifiable(_callHistory);

  /// Whether call history is currently being loaded
  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

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

  /// Track timeout timers for pending calls
  final Map<String, Timer> _callTimeoutTimers = {};

  /// Track call creation timestamps
  final Map<String, DateTime> _callCreationTimes = {};

  /// Set the active call
  void setActiveCall(Call? call) {
    _activeCall = call;
    _notifyCallStateChange();
  }

  /// Add a call to call history
  void addToHistory(Call call) {
    _callHistory.insert(0, call);
    _callHistoryController.add(callHistory);
    notifyListeners();
  }

  /// Clear active call
  void clearActiveCall() {
    _activeCall = null;
    _notifyCallStateChange();
  }

  /// Get a call by ID from active or pending lists
  Call? getCall(String callId) {
    if (_activeCall?.callId == callId) {
      return _activeCall;
    }
    return _pendingOutgoingCalls[callId];
  }

  /// Add a pending outgoing call
  void addPendingOutgoingCall(Call call) {
    _pendingOutgoingCalls[call.callId] = call;
    _callCreationTimes[call.callId] = DateTime.now();
    _notifyCallStateChange();
  }

  /// Remove a pending outgoing call
  Call? removePendingOutgoingCall(String callId) {
    _callCreationTimes.remove(callId);
    final call = _pendingOutgoingCalls.remove(callId);
    if (call != null) {
      _notifyCallStateChange();
    }
    return call;
  }

  /// Check if there's an active or pending call
  bool get hasActiveCall => _activeCall != null || _pendingOutgoingCalls.isNotEmpty;

  /// Notify listeners of call state change
  void _notifyCallStateChange() {
    notifyListeners();
    _hasActiveCallController.add(hasActiveCall);
  }

  /// Load call history from backend
  Future<void> loadCallHistory({int limit = 50, int offset = 0}) async {
    if (_isLoadingHistory) return;

    _isLoadingHistory = true;
    notifyListeners();

    try {
      final calls = await _adapter.getCallHistory(
        limit: limit,
        offset: offset,
      );

      // Merge with existing history, removing duplicates
      final existingCallIds = _callHistory.map((c) => c.callId).toSet();
      for (final call in calls) {
        if (!existingCallIds.contains(call.callId)) {
          _callHistory.add(call);
        }
      }

      // Sort by timestamp (most recent first)
      _callHistory.sort((a, b) {
        if (a.timestamp == null && b.timestamp == null) return 0;
        if (a.timestamp == null) return 1;
        if (b.timestamp == null) return -1;
        return b.timestamp!.compareTo(a.timestamp!);
      });

      _callHistoryController.add(callHistory);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load call history: $e');
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
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
