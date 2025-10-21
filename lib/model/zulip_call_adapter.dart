import 'dart:async';
import 'dart:developer' as developer;

import 'package:zulip_call_kit/zulip_call_kit.dart' as call_kit;

import '../api/core.dart';
import '../api/model/call.dart';
import '../api/model/events.dart';
import '../api/route/calls.dart' as api;
import 'call_errors.dart';
import 'call_store.dart';

/// Zulip-specific implementation of CallBackendAdapter
///
/// This adapter bridges the call plugin with Zulip's backend API.
class ZulipCallAdapter implements call_kit.CallBackendAdapter {
  ZulipCallAdapter({
    required this.connection,
    required this.callStore,
    required this.selfUserId,
  });

  final ApiConnection connection;
  final CallStore callStore;
  final int selfUserId;

  final _eventController = StreamController<call_kit.CallEvent>.broadcast();

  @override
  Future<call_kit.CallSession> createCall({
    required call_kit.CallParticipant initiator,
    required call_kit.CallParticipant recipient,
    required call_kit.CallType type,
    Map<String, dynamic>? metadata,
  }) async {
    final recipientId = int.parse(recipient.id);

    developer.log('ZulipCallAdapter: Creating call for user $recipientId',
        name: 'ZulipCallAdapter');

    // Check cooldown to prevent race conditions
    if (!callStore.canCallUser(recipientId)) {
      final remaining = callStore.getRemainingCooldown(recipientId);
      developer.log(
        'ZulipCallAdapter: Call cooldown active for user $recipientId. '
        'Remaining: ${remaining.inSeconds}s',
        name: 'ZulipCallAdapter',
      );
      throw CallCooldownException(
        recipientId: recipientId,
        remainingSeconds: remaining.inSeconds,
      );
    }

    try {
      final response = await api.createCall(
        connection,
        userId: recipientId,
        isVideoCall: type == call_kit.CallType.video,
      );

      // Normal call creation (HTTP 200)
      // Note: If server returns HTTP 202 with queued response, the API will
      // throw an error or return a different response format.
      // For now, we handle the standard CreateCallResponse.
      // TODO(calls): Handle QueuedCallResponse when server implements HTTP 202
      final call = call_kit.Call(
        callId: response.callId,
        callerId: int.parse(initiator.id),
        recipientId: recipientId,
        callType: type,
        status: call_kit.CallStatus.created,
        jitsiUrl: response.callUrl,
        timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );

      return call_kit.CallSession(
        call: call,
        meetingUrl: response.callUrl,
        meetingId: response.roomName,
        config: {
          'roomName': response.roomName,
          'participantUrl': response.participantUrl,
        },
      );
    } catch (e) {
      developer.log('ZulipCallAdapter: Failed to create call: $e',
          name: 'ZulipCallAdapter');
      rethrow;
    }
  }

  @override
  Future<void> acknowledgeCall({
    required String callId,
    required call_kit.CallParticipant participant,
  }) async {
    developer.log('ZulipCallAdapter: Acknowledging call $callId',
        name: 'ZulipCallAdapter');
    await api.acknowledgeCall(connection, callId: callId);
  }

  @override
  Future<void> acceptCall({
    required String callId,
    required call_kit.CallParticipant participant,
  }) async {
    developer.log('ZulipCallAdapter: Accepting call $callId',
        name: 'ZulipCallAdapter');
    await api.acceptCall(connection, callId: callId);
  }

  @override
  Future<void> declineCall({
    required String callId,
    required call_kit.CallParticipant participant,
  }) async {
    developer.log('ZulipCallAdapter: Declining call $callId',
        name: 'ZulipCallAdapter');
    await api.declineCall(connection, callId: callId);
  }

  @override
  Future<void> endCall({
    required String callId,
    int? duration,
  }) async {
    developer.log('ZulipCallAdapter: Ending call $callId',
        name: 'ZulipCallAdapter');
    await api.endCall(connection, callId: callId, duration: duration);
  }

  @override
  Future<void> cancelCall({required String callId}) async {
    developer.log('ZulipCallAdapter: Cancelling call $callId',
        name: 'ZulipCallAdapter');
    await api.cancelCall(connection, callId: callId);
  }

  @override
  Future<void> sendHeartbeat({
    required String callId,
    bool isBackgrounded = false,
  }) async {
    await api.sendHeartbeat(
      connection,
      callId: callId,
      isBackgrounded: isBackgrounded,
    );
  }

  @override
  Future<List<Call>> getCallHistory({
    int? limit,
    int? offset,
    String? userId,
    call_kit.CallStatus? status,
  }) async {
    // Convert status filter to API format
    String? statusFilter;
    if (status != null) {
      switch (status) {
        case call_kit.CallStatus.declined:
          statusFilter = 'missed';
        case call_kit.CallStatus.accepted:
        case call_kit.CallStatus.ended:
          statusFilter = 'answered';
        default:
          statusFilter = 'all';
      }
    }

    final response = await api.getCallHistory(
      connection,
      limit: limit ?? 50,
      cursor: null, // For now, cursor is managed separately
      callType: null, // Filter by call type if needed
      status: statusFilter,
    );

    // Convert HistoricalCall to Call
    return response.calls.map((historicalCall) {
      final call_kit.CallStatus callStatus;
      switch (historicalCall.state) {
        case 'ended':
          callStatus = call_kit.CallStatus.ended;
        case 'declined':
          callStatus = call_kit.CallStatus.declined;
        case 'cancelled':
          callStatus = call_kit.CallStatus.cancelled;
        case 'accepted':
          callStatus = call_kit.CallStatus.accepted;
        case 'queued':
          callStatus = call_kit.CallStatus.queued;
        default:
          callStatus = call_kit.CallStatus.ended;
      }

      final timestamp = DateTime.parse(historicalCall.createdAt).millisecondsSinceEpoch ~/ 1000;

      final int callerId;
      final int recipientId;
      if (historicalCall.wasInitiator) {
        callerId = selfUserId;
        recipientId = historicalCall.otherUser.userId;
      } else {
        callerId = historicalCall.otherUser.userId;
        recipientId = selfUserId;
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
  }

  /// Get pending queued calls for the current user
  Future<CallQueueResponse> getCallQueue() async {
    developer.log('ZulipCallAdapter: Fetching call queue',
        name: 'ZulipCallAdapter');
    return await api.getCallQueue(connection);
  }

  /// Cancel a queued call before it's processed
  Future<void> cancelQueuedCall(String queueId) async {
    developer.log('ZulipCallAdapter: Cancelling queued call $queueId',
        name: 'ZulipCallAdapter');
    await api.cancelQueuedCall(connection, queueId: queueId);
  }

  /// Leave a call without ending it for everyone (non-moderator)
  /// If caller, this ends the call for everyone
  Future<void> leaveCall(String callId) async {
    developer.log('ZulipCallAdapter: Leaving call $callId',
        name: 'ZulipCallAdapter');
    await api.leaveCall(connection, callId: callId);
  }

  @override
  Stream<call_kit.CallEvent> get callEvents {
    // Convert Zulip CallStore events to plugin CallEvent
    // This would listen to callStore.incomingCallStream and convert to plugin events
    return _eventController.stream;
  }

  /// Handle Zulip event and convert to plugin event
  void handleZulipEvent(dynamic event) {
    if (event is CallCreatedEvent) {
      // Convert to plugin IncomingCallEvent if it's for us
      final zulipCall = event.call;
      if (zulipCall.recipientId == selfUserId) {
        _eventController.add(call_kit.IncomingCallEvent(
          timestamp: DateTime.now(),
          call: zulipCall,
          initiator: call_kit.CallParticipant(
            id: zulipCall.callerId.toString(),
            displayName: zulipCall.callerDisplayName ?? 'Unknown',
            avatarUrl: zulipCall.callerAvatarUrl,
          ),
        ));
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _eventController.close();
  }
}
