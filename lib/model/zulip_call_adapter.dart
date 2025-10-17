import 'dart:async';
import 'dart:developer' as developer;

import 'package:zulip_call_kit/zulip_call_kit.dart' as call_kit;

import '../api/core.dart';
import '../api/model/call.dart';
import '../api/model/events.dart';
import '../api/route/calls.dart' as api;
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
    developer.log('ZulipCallAdapter: Creating call for user ${recipient.id}',
        name: 'ZulipCallAdapter');

    final response = await api.createCall(
      connection,
      userId: int.parse(recipient.id),
      isVideoCall: type == call_kit.CallType.video,
    );

    final call = call_kit.Call(
      callId: response.callId,
      callerId: int.parse(initiator.id),
      recipientId: int.parse(recipient.id),
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
    final response = await api.getCallHistory(
      connection,
      limit: limit ?? 50,
      offset: offset ?? 0,
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
