import 'call.dart';

/// Represents an active call session with meeting details
class CallSession {
  const CallSession({
    required this.call,
    required this.meetingUrl,
    required this.meetingId,
    this.token,
    this.config,
  });

  final Call call;
  final String meetingUrl;
  final String meetingId;
  final String? token; // Auth token for meeting
  final Map<String, dynamic>? config; // Provider-specific config

  Map<String, dynamic> toJson() => {
        'call': call.toJson(),
        'meetingUrl': meetingUrl,
        'meetingId': meetingId,
        'token': token,
        'config': config,
      };

  factory CallSession.fromJson(Map<String, dynamic> json) => CallSession(
        call: Call.fromJson(json['call'] as Map<String, dynamic>),
        meetingUrl: json['meetingUrl'] as String,
        meetingId: json['meetingId'] as String,
        token: json['token'] as String?,
        config: json['config'] as Map<String, dynamic>?,
      );

  CallSession copyWith({
    Call? call,
    String? meetingUrl,
    String? meetingId,
    String? token,
    Map<String, dynamic>? config,
  }) {
    return CallSession(
      call: call ?? this.call,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      meetingId: meetingId ?? this.meetingId,
      token: token ?? this.token,
      config: config ?? this.config,
    );
  }
}
