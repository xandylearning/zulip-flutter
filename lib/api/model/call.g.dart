// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: constant_identifier_names, unnecessary_cast

part of 'call.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Call _$CallFromJson(Map<String, dynamic> json) => Call(
  callId: json['call_id'] as String,
  callerId: (json['caller_id'] as num).toInt(),
  recipientId: (json['recipient_id'] as num).toInt(),
  callType: $enumDecode(_$CallTypeEnumMap, json['call_type']),
  status: $enumDecode(_$CallStatusEnumMap, json['status']),
  jitsiUrl: json['jitsi_url'] as String,
  timestamp: (json['timestamp'] as num).toInt(),
  duration: (json['duration'] as num?)?.toInt(),
);

Map<String, dynamic> _$CallToJson(Call instance) => <String, dynamic>{
  'call_id': instance.callId,
  'caller_id': instance.callerId,
  'recipient_id': instance.recipientId,
  'call_type': instance.callType,
  'status': instance.status,
  'jitsi_url': instance.jitsiUrl,
  'timestamp': instance.timestamp,
  'duration': instance.duration,
};

const _$CallTypeEnumMap = {CallType.audio: 'audio', CallType.video: 'video'};

const _$CallStatusEnumMap = {
  CallStatus.created: 'created',
  CallStatus.ringing: 'ringing',
  CallStatus.accepted: 'accepted',
  CallStatus.declined: 'declined',
  CallStatus.ended: 'ended',
  CallStatus.cancelled: 'cancelled',
};

CreateCallResponse _$CreateCallResponseFromJson(Map<String, dynamic> json) =>
    CreateCallResponse(
      result: json['result'] as String,
      callId: json['call_id'] as String,
      callUrl: json['call_url'] as String,
      participantUrl: json['participant_url'] as String?,
      callType: json['call_type'] as String,
      roomName: json['room_name'] as String,
      recipient: UserInfo.fromJson(json['recipient'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CreateCallResponseToJson(CreateCallResponse instance) =>
    <String, dynamic>{
      'result': instance.result,
      'call_id': instance.callId,
      'call_url': instance.callUrl,
      'participant_url': instance.participantUrl,
      'call_type': instance.callType,
      'room_name': instance.roomName,
      'recipient': instance.recipient,
    };

CallStatusResponse _$CallStatusResponseFromJson(Map<String, dynamic> json) =>
    CallStatusResponse(
      result: json['result'] as String,
      call: Call.fromJson(json['call'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CallStatusResponseToJson(CallStatusResponse instance) =>
    <String, dynamic>{'result': instance.result, 'call': instance.call};

UserInfo _$UserInfoFromJson(Map<String, dynamic> json) => UserInfo(
  userId: (json['user_id'] as num).toInt(),
  fullName: json['full_name'] as String,
  email: json['email'] as String,
);

Map<String, dynamic> _$UserInfoToJson(UserInfo instance) => <String, dynamic>{
  'user_id': instance.userId,
  'full_name': instance.fullName,
  'email': instance.email,
};

CallActionResponse _$CallActionResponseFromJson(Map<String, dynamic> json) =>
    CallActionResponse(
      result: json['result'] as String,
      msg: json['msg'] as String?,
    );

Map<String, dynamic> _$CallActionResponseToJson(CallActionResponse instance) =>
    <String, dynamic>{'result': instance.result, 'msg': instance.msg};

EndAllCallsResponse _$EndAllCallsResponseFromJson(Map<String, dynamic> json) =>
    EndAllCallsResponse(
      result: json['result'] as String,
      message: json['message'] as String,
      callsEnded: (json['calls_ended'] as num).toInt(),
    );

Map<String, dynamic> _$EndAllCallsResponseToJson(
  EndAllCallsResponse instance,
) => <String, dynamic>{
  'result': instance.result,
  'message': instance.message,
  'calls_ended': instance.callsEnded,
};

ActiveCallsResponse _$ActiveCallsResponseFromJson(Map<String, dynamic> json) =>
    ActiveCallsResponse(
      result: json['result'] as String,
      activeCalls: (json['active_calls'] as List<dynamic>)
          .map((e) => ActiveCall.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$ActiveCallsResponseToJson(
  ActiveCallsResponse instance,
) => <String, dynamic>{
  'result': instance.result,
  'active_calls': instance.activeCalls,
  'count': instance.count,
};

ActiveCall _$ActiveCallFromJson(Map<String, dynamic> json) => ActiveCall(
  callId: json['call_id'] as String,
  callType: json['call_type'] as String,
  state: json['state'] as String,
  senderId: (json['sender_id'] as num).toInt(),
  senderName: json['sender_name'] as String,
  receiverId: (json['receiver_id'] as num).toInt(),
  receiverName: json['receiver_name'] as String,
  jitsiUrl: json['jitsi_url'] as String,
  createdAt: json['created_at'] as String,
  isOutgoing: json['is_outgoing'] as bool,
);

Map<String, dynamic> _$ActiveCallToJson(ActiveCall instance) =>
    <String, dynamic>{
      'call_id': instance.callId,
      'call_type': instance.callType,
      'state': instance.state,
      'sender_id': instance.senderId,
      'sender_name': instance.senderName,
      'receiver_id': instance.receiverId,
      'receiver_name': instance.receiverName,
      'jitsi_url': instance.jitsiUrl,
      'created_at': instance.createdAt,
      'is_outgoing': instance.isOutgoing,
    };

CallHistoryResponse _$CallHistoryResponseFromJson(Map<String, dynamic> json) =>
    CallHistoryResponse(
      result: json['result'] as String,
      calls: (json['calls'] as List<dynamic>)
          .map((e) => HistoricalCall.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: json['has_more'] as bool,
    );

Map<String, dynamic> _$CallHistoryResponseToJson(
  CallHistoryResponse instance,
) => <String, dynamic>{
  'result': instance.result,
  'calls': instance.calls,
  'has_more': instance.hasMore,
};

HistoricalCall _$HistoricalCallFromJson(Map<String, dynamic> json) =>
    HistoricalCall(
      callId: json['call_id'] as String,
      callType: json['call_type'] as String,
      state: json['state'] as String,
      wasInitiator: json['was_initiator'] as bool,
      otherUser: UserInfo.fromJson(json['other_user'] as Map<String, dynamic>),
      createdAt: json['created_at'] as String,
      startedAt: json['started_at'] as String?,
      endedAt: json['ended_at'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    );

Map<String, dynamic> _$HistoricalCallToJson(HistoricalCall instance) =>
    <String, dynamic>{
      'call_id': instance.callId,
      'call_type': instance.callType,
      'state': instance.state,
      'was_initiator': instance.wasInitiator,
      'other_user': instance.otherUser,
      'created_at': instance.createdAt,
      'started_at': instance.startedAt,
      'ended_at': instance.endedAt,
      'duration_seconds': instance.durationSeconds,
    };
