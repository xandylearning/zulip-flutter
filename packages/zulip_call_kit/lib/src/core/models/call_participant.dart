/// Represents a participant in a call
class CallParticipant {
  const CallParticipant({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.email,
    this.phoneNumber,
    this.metadata,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? email;
  final String? phoneNumber;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'email': email,
        'phoneNumber': phoneNumber,
        'metadata': metadata,
      };

  factory CallParticipant.fromJson(Map<String, dynamic> json) =>
      CallParticipant(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        email: json['email'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}
