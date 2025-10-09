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
      call: Call.fromJson(json['call'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CreateCallResponseToJson(CreateCallResponse instance) =>
    <String, dynamic>{'result': instance.result, 'call': instance.call};

CallStatusResponse _$CallStatusResponseFromJson(Map<String, dynamic> json) =>
    CallStatusResponse(
      result: json['result'] as String,
      call: Call.fromJson(json['call'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CallStatusResponseToJson(CallStatusResponse instance) =>
    <String, dynamic>{'result': instance.result, 'call': instance.call};

CallActionResponse _$CallActionResponseFromJson(Map<String, dynamic> json) =>
    CallActionResponse(
      result: json['result'] as String,
      msg: json['msg'] as String?,
    );

Map<String, dynamic> _$CallActionResponseToJson(CallActionResponse instance) =>
    <String, dynamic>{'result': instance.result, 'msg': instance.msg};
