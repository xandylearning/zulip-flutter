import 'call.dart';
import 'call_participant.dart';

/// Base class for call events
sealed class CallEvent {
  const CallEvent({required this.timestamp});

  final DateTime timestamp;
}

/// Incoming call event
class IncomingCallEvent extends CallEvent {
  const IncomingCallEvent({
    required super.timestamp,
    required this.call,
    required this.initiator,
  });

  final Call call;
  final CallParticipant initiator;
}

/// Call status changed event
class CallStatusChangedEvent extends CallEvent {
  const CallStatusChangedEvent({
    required super.timestamp,
    required this.callId,
    required this.oldStatus,
    required this.newStatus,
  });

  final String callId;
  final CallStatus oldStatus;
  final CallStatus newStatus;
}

/// Participant joined event
class ParticipantJoinedEvent extends CallEvent {
  const ParticipantJoinedEvent({
    required super.timestamp,
    required this.callId,
    required this.participant,
  });

  final String callId;
  final CallParticipant participant;
}

/// Participant left event
class ParticipantLeftEvent extends CallEvent {
  const ParticipantLeftEvent({
    required super.timestamp,
    required this.callId,
    required this.participantId,
  });

  final String callId;
  final String participantId;
}

/// Call ended event
class CallEndedEvent extends CallEvent {
  const CallEndedEvent({
    required super.timestamp,
    required this.callId,
    required this.reason,
    this.duration,
  });

  final String callId;
  final CallEndReason reason;
  final int? duration;
}

enum CallEndReason {
  normal,
  declined,
  cancelled,
  timeout,
  networkFailure,
  error,
}
