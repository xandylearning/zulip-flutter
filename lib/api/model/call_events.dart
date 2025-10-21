part of 'events.dart';

/// A Zulip event of type `call`.
///
/// These events are sent when call-related actions occur.
sealed class CallEvent extends Event {
  @override
  @JsonKey(includeToJson: true)
  String get type => 'call';

  String get op;

  CallEvent({required super.id});
}

/// A [CallEvent] with op `created`: a new call has been created.
@JsonSerializable(fieldRename: FieldRename.snake)
class CallCreatedEvent extends CallEvent {
  @override
  @JsonKey(includeToJson: true)
  String get op => 'created';

  final Call call;

  CallCreatedEvent({required super.id, required this.call});

  factory CallCreatedEvent.fromJson(Map<String, dynamic> json) =>
    _$CallCreatedEventFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CallCreatedEventToJson(this);
}

/// A [CallEvent] with op `acknowledged`: the recipient has acknowledged the call.
@JsonSerializable(fieldRename: FieldRename.snake)
class CallAcknowledgedEvent extends CallEvent {
  @override
  @JsonKey(includeToJson: true)
  String get op => 'acknowledged';

  final String callId;
  @JsonKey(fromJson: _parseIntFromString)
  final int userId;

  CallAcknowledgedEvent({
    required super.id,
    required this.callId,
    required this.userId,
  });

  factory CallAcknowledgedEvent.fromJson(Map<String, dynamic> json) =>
    _$CallAcknowledgedEventFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CallAcknowledgedEventToJson(this);
}

/// A [CallEvent] with op `accepted`: the call has been accepted.
@JsonSerializable(fieldRename: FieldRename.snake)
class CallAcceptedEvent extends CallEvent {
  @override
  @JsonKey(includeToJson: true)
  String get op => 'accepted';

  final String callId;
  @JsonKey(fromJson: _parseIntFromString)
  final int userId;

  CallAcceptedEvent({
    required super.id,
    required this.callId,
    required this.userId,
  });

  factory CallAcceptedEvent.fromJson(Map<String, dynamic> json) =>
    _$CallAcceptedEventFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CallAcceptedEventToJson(this);
}

/// A [CallEvent] with op `declined`: the call has been declined.
@JsonSerializable(fieldRename: FieldRename.snake)
class CallDeclinedEvent extends CallEvent {
  @override
  @JsonKey(includeToJson: true)
  String get op => 'declined';

  final String callId;
  @JsonKey(fromJson: _parseIntFromString)
  final int userId;

  CallDeclinedEvent({
    required super.id,
    required this.callId,
    required this.userId,
  });

  factory CallDeclinedEvent.fromJson(Map<String, dynamic> json) =>
    _$CallDeclinedEventFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CallDeclinedEventToJson(this);
}

/// A [CallEvent] with op `ended`: the call has ended.
@JsonSerializable(fieldRename: FieldRename.snake)
class CallEndedEvent extends CallEvent {
  @override
  @JsonKey(includeToJson: true)
  String get op => 'ended';

  final String callId;
  final int? duration; // Duration in seconds

  CallEndedEvent({
    required super.id,
    required this.callId,
    this.duration,
  });

  factory CallEndedEvent.fromJson(Map<String, dynamic> json) =>
    _$CallEndedEventFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CallEndedEventToJson(this);
}

/// A [CallEvent] with op `cancelled`: the call has been cancelled by the caller.
@JsonSerializable(fieldRename: FieldRename.snake)
class CallCancelledEvent extends CallEvent {
  @override
  @JsonKey(includeToJson: true)
  String get op => 'cancelled';

  final String callId;
  @JsonKey(fromJson: _parseIntFromString)
  final int userId;

  CallCancelledEvent({
    required super.id,
    required this.callId,
    required this.userId,
  });

  factory CallCancelledEvent.fromJson(Map<String, dynamic> json) =>
    _$CallCancelledEventFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CallCancelledEventToJson(this);
}

/// A [CallEvent] with op `queued`: call was queued due to busy recipient.
@JsonSerializable(fieldRename: FieldRename.snake)
class CallQueuedEvent extends CallEvent {
  @override
  @JsonKey(includeToJson: true)
  String get op => 'queued';

  final String callId;
  final String queueId;
  final String message;
  final String expiresAt;

  CallQueuedEvent({
    required super.id,
    required this.callId,
    required this.queueId,
    required this.message,
    required this.expiresAt,
  });

  factory CallQueuedEvent.fromJson(Map<String, dynamic> json) =>
    _$CallQueuedEventFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CallQueuedEventToJson(this);
}

/// A [CallEvent] with op `network_failure`: network disconnection detected.
@JsonSerializable(fieldRename: FieldRename.snake)
class CallNetworkFailureEvent extends CallEvent {
  @override
  @JsonKey(includeToJson: true)
  String get op => 'network_failure';

  final String callId;
  @JsonKey(fromJson: _parseIntFromString)
  final int userId;

  CallNetworkFailureEvent({
    required super.id,
    required this.callId,
    required this.userId,
  });

  factory CallNetworkFailureEvent.fromJson(Map<String, dynamic> json) =>
    _$CallNetworkFailureEventFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CallNetworkFailureEventToJson(this);
}

/// A [CallEvent] with op `participant_left`: non-moderator left the call.
@JsonSerializable(fieldRename: FieldRename.snake)
class ParticipantLeftEvent extends CallEvent {
  @override
  @JsonKey(includeToJson: true)
  String get op => 'participant_left';

  final String callId;
  @JsonKey(fromJson: _parseIntFromString)
  final int userId;

  ParticipantLeftEvent({
    required super.id,
    required this.callId,
    required this.userId,
  });

  factory ParticipantLeftEvent.fromJson(Map<String, dynamic> json) =>
    _$ParticipantLeftEventFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$ParticipantLeftEventToJson(this);
}

/// Custom converter for parsing integers from strings
int _parseIntFromString(dynamic value) {
  if (value == null) {
    throw Exception('Cannot parse userId from null value - this indicates malformed server response');
  }
  if (value is int) return value;
  if (value is String) {
    try {
      return int.parse(value);
    } catch (e) {
      throw Exception('Cannot parse userId from string "$value": $e');
    }
  }
  throw Exception('Cannot parse userId from $value (type: ${value.runtimeType}) - expected int or string');
}

