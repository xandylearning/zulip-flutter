import 'package:json_annotation/json_annotation.dart';

part 'call.g.dart';

/// Represents a call in the system
@JsonSerializable(fieldRename: FieldRename.snake)
class Call {
  final String callId;
  final int callerId;
  final int recipientId;
  final CallType callType;
  final CallStatus status;
  final String jitsiUrl;
  final int? timestamp;
  final int? duration; // Duration in seconds, null if call not completed

  // Profile fields for incoming UI/customizations
  final String? callerDisplayName;
  final String? callerAvatarUrl;
  final String? callerHandle;

  const Call({
    required this.callId,
    required this.callerId,
    required this.recipientId,
    required this.callType,
    required this.status,
    required this.jitsiUrl,
    this.timestamp,
    this.duration,
    this.callerDisplayName,
    this.callerAvatarUrl,
    this.callerHandle,
  });

  factory Call.fromJson(Map<String, dynamic> json) => _$CallFromJson(json);
  Map<String, dynamic> toJson() => _$CallToJson(this);

  Call copyWith({
    String? callId,
    int? callerId,
    int? recipientId,
    CallType? callType,
    CallStatus? status,
    String? jitsiUrl,
    int? timestamp,
    int? duration,
    String? callerDisplayName,
    String? callerAvatarUrl,
    String? callerHandle,
  }) {
    return Call(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      recipientId: recipientId ?? this.recipientId,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      jitsiUrl: jitsiUrl ?? this.jitsiUrl,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      callerDisplayName: callerDisplayName ?? this.callerDisplayName,
      callerAvatarUrl: callerAvatarUrl ?? this.callerAvatarUrl,
      callerHandle: callerHandle ?? this.callerHandle,
    );
  }
}

/// The type of call (audio or video)
@JsonEnum(fieldRename: FieldRename.snake)
enum CallType {
  audio,
  video;

  String toJson() => _$CallTypeEnumMap[this]!;
}

/// The status of a call
@JsonEnum(fieldRename: FieldRename.snake)
enum CallStatus {
  created,
  ringing,
  accepted,
  declined,
  ended,
  cancelled;

  String toJson() => _$CallStatusEnumMap[this]!;
}

/// Response from creating a call
@JsonSerializable(fieldRename: FieldRename.snake)
class CreateCallResponse {
  final String result;
  final String callId;
  final String callUrl;
  final String? participantUrl;
  final String callType;
  final String roomName;
  final UserInfo recipient;

  const CreateCallResponse({
    required this.result,
    required this.callId,
    required this.callUrl,
    this.participantUrl,
    required this.callType,
    required this.roomName,
    required this.recipient,
  });

  factory CreateCallResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateCallResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CreateCallResponseToJson(this);
}

/// User information for call responses
@JsonSerializable(fieldRename: FieldRename.snake)
class UserInfo {
  final int userId;
  final String fullName;
  final String email;

  const UserInfo({
    required this.userId,
    required this.fullName,
    required this.email,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) =>
      _$UserInfoFromJson(json);
  Map<String, dynamic> toJson() => _$UserInfoToJson(this);
}

/// Generic success response for call operations
@JsonSerializable(fieldRename: FieldRename.snake)
class CallActionResponse {
  final String result;
  final String? msg;

  const CallActionResponse({
    required this.result,
    this.msg,
  });

  factory CallActionResponse.fromJson(Map<String, dynamic> json) =>
      _$CallActionResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CallActionResponseToJson(this);
}

/// Response for call status query
@JsonSerializable(fieldRename: FieldRename.snake)
class CallStatusResponse {
  final String result;
  final Call call;

  const CallStatusResponse({
    required this.result,
    required this.call,
  });

  factory CallStatusResponse.fromJson(Map<String, dynamic> json) =>
      _$CallStatusResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CallStatusResponseToJson(this);
}

/// Response for getting call history
@JsonSerializable(fieldRename: FieldRename.snake)
class CallHistoryResponse {
  final String result;
  final List<HistoricalCall> calls;
  final bool hasMore;

  const CallHistoryResponse({
    required this.result,
    required this.calls,
    required this.hasMore,
  });

  factory CallHistoryResponse.fromJson(Map<String, dynamic> json) =>
      _$CallHistoryResponseFromJson(json);
  Map<String, dynamic> toJson() => _$CallHistoryResponseToJson(this);
}

/// Historical call information
@JsonSerializable(fieldRename: FieldRename.snake)
class HistoricalCall {
  final String callId;
  final String callType;
  final String state;
  final bool wasInitiator;
  final UserInfo otherUser;
  final String createdAt;
  final String? startedAt;
  final String? endedAt;
  final int? durationSeconds;

  const HistoricalCall({
    required this.callId,
    required this.callType,
    required this.state,
    required this.wasInitiator,
    required this.otherUser,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
  });

  factory HistoricalCall.fromJson(Map<String, dynamic> json) =>
      _$HistoricalCallFromJson(json);
  Map<String, dynamic> toJson() => _$HistoricalCallToJson(this);
}

/// Response for ending all calls
@JsonSerializable(fieldRename: FieldRename.snake)
class EndAllCallsResponse {
  final String result;
  final String message;
  final int callsEnded;

  const EndAllCallsResponse({
    required this.result,
    required this.message,
    required this.callsEnded,
  });

  factory EndAllCallsResponse.fromJson(Map<String, dynamic> json) =>
      _$EndAllCallsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$EndAllCallsResponseToJson(this);
}

/// Response for getting active calls
@JsonSerializable(fieldRename: FieldRename.snake)
class ActiveCallsResponse {
  final String result;
  final List<ActiveCall> activeCalls;
  final int count;

  const ActiveCallsResponse({
    required this.result,
    required this.activeCalls,
    required this.count,
  });

  factory ActiveCallsResponse.fromJson(Map<String, dynamic> json) =>
      _$ActiveCallsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ActiveCallsResponseToJson(this);
}

/// Active call information
@JsonSerializable(fieldRename: FieldRename.snake)
class ActiveCall {
  final String callId;
  final String callType;
  final String state;
  final int senderId;
  final String senderName;
  final int receiverId;
  final String receiverName;
  final String jitsiUrl;
  final String createdAt;
  final bool isOutgoing;

  const ActiveCall({
    required this.callId,
    required this.callType,
    required this.state,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.jitsiUrl,
    required this.createdAt,
    required this.isOutgoing,
  });

  factory ActiveCall.fromJson(Map<String, dynamic> json) =>
      _$ActiveCallFromJson(json);
  Map<String, dynamic> toJson() => _$ActiveCallToJson(this);
}
