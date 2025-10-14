import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import '../log.dart';
import 'model/model.dart';

part 'notifications.g.dart';

/// Parsed version of an FCM message, of any type.
///
/// Firebase Cloud Messaging (FCM) is the service run by Google that we use
/// for delivering notifications to Android devices.  An FCM message may
/// be to tell us we should show a notification, or something else like
/// to remove one (because the user read the underlying Zulip message).
///
/// The word "message" can be confusing in this context,
/// and in our notification code we usually stick to more specific phrases:
///
///  * An "FCM message" is one of the blobs we receive over FCM; what FCM docs
///    call a "message", and is also known as a "data notification".
///
///    One of these might correspond to zero, one, or more actual notifications
///    we show in the UI.
///
///  * A "Zulip message" is the thing that in other Zulip contexts we call
///    simply a "message": a [Message], the central item in the Zulip app model.
sealed class FcmMessage {
  FcmMessage();

  factory FcmMessage.fromJson(Map<String, dynamic> json) {
    // Check if the data is wrapped in a 'custom' object (for call notifications)
    Map<String, dynamic> data;
    if (json.containsKey('custom')) {
      final custom = json['custom'];
      if (custom is String) {
        // Parse Python dict string: convert single quotes to double quotes
        // and handle Python's None -> null
        try {
          String jsonStr = custom
              .replaceAll("'", '"')  // Convert single quotes to double quotes
              .replaceAll('None', 'null');  // Convert Python None to JSON null
          assert(debugLog('FCM MESSAGE PARSING - Parsed custom string: $jsonStr'));
          data = Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
        } catch (e) {
          assert(debugLog('FCM MESSAGE PARSING - Failed to parse custom string: $e'));
          data = {};
        }
      } else {
        data = Map<String, dynamic>.from(custom as Map);
      }
    } else {
      data = json;
    }

    final event = data['event'];
    assert(debugLog('FCM MESSAGE PARSING - Event type: $event'));
    assert(debugLog('FCM MESSAGE PARSING - Full JSON: $json'));
    assert(debugLog('FCM MESSAGE PARSING - Extracted data: $data'));

    switch (event) {
      case 'message':
        assert(debugLog('FCM MESSAGE PARSING - Creating MessageFcmMessage'));
        return MessageFcmMessage.fromJson(data);
      case 'remove':
        assert(debugLog('FCM MESSAGE PARSING - Creating RemoveFcmMessage'));
        return RemoveFcmMessage.fromJson(data);
      case 'call':
        assert(debugLog('FCM MESSAGE PARSING - Creating CallFcmMessage'));
        return CallFcmMessage.fromJson(data);
      default:
        assert(debugLog('FCM MESSAGE PARSING - Unknown event type: $event, creating UnexpectedFcmMessage'));
        return UnexpectedFcmMessage.fromJson(json);
    }
  }

  Map<String, dynamic> toJson();
}

/// An [FcmMessage] of a type (a value of `event`) we didn't know about.
class UnexpectedFcmMessage extends FcmMessage {
  final Map<String, dynamic> json;

  UnexpectedFcmMessage.fromJson(this.json);

  @override
  Map<String, dynamic> toJson() => json;
}

/// Base class for [FcmMessage]s that identify what Zulip account they're for.
///
/// This includes all known types of FCM messages from Zulip
/// (all [FcmMessage] subclasses other than [UnexpectedFcmMessage]),
/// and it seems likely that it always will.
sealed class FcmMessageWithIdentity extends FcmMessage {
  /// The server's `EXTERNAL_HOST` setting.  This is a hostname,
  /// or a colon-separated hostname-plus-port.
  ///
  /// For documentation, see zulip-server:zproject/prod_settings_template.py .
  final String server;

  /// The realm's ID within the server.
  @JsonKey(fromJson: _parseIntWithDefaultRealmId)
  final int realmId;

  /// The realm's own URL.
  ///
  /// This is a real, absolute URL which is the base for all URLs a client uses
  /// with this realm.  It corresponds to [GetServerSettingsResult.realmUri].
  @JsonKey(readValue: _readRealmUrl) // TODO(server-9)
  final Uri realmUrl;

  /// This user's ID within the server.
  ///
  /// Useful mainly in the case where the user has multiple accounts in the
  /// same realm.
  @JsonKey(fromJson: _parseIntFromString)
  final int userId;

  FcmMessageWithIdentity({
    required this.server,
    required this.realmId,
    required this.realmUrl,
    required this.userId,
  });

  // TODO(server-9): FL 257 deprecated 'realm_uri' in favor of 'realm_url'.
  static String _readRealmUrl(Map<dynamic, dynamic> json, String key) {
    return (json['realm_url'] ?? json['realm_uri']) as String;
  }

  /// Custom converter for realm ID with default value
  static int _parseIntWithDefaultRealmId(dynamic value) {
    if (value == null) return 1; // Default realm ID
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  /// Custom converter for parsing integers from strings
  static int _parseIntFromString(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.parse(value);
    throw Exception('Cannot parse userId from $value');
  }
}

/// Parsed version of an FCM message of type `message`.
///
/// This corresponds to a Zulip message for which the user wants to
/// see a notification.
///
/// The word "message" can be confusing in this context.
/// See [FcmMessage] for discussion.
@JsonSerializable(fieldRename: FieldRename.snake)
@_IntConverter()
@_IntListConverter()
class MessageFcmMessage extends FcmMessageWithIdentity {
  @JsonKey(includeToJson: true, name: 'event')
  String get type => 'message';

  final int senderId;
  // final String senderEmail; // obsolete; ignore
  final Uri senderAvatarUrl;
  final String senderFullName;

  @JsonKey(includeToJson: false, readValue: _readWhole)
  final FcmMessageRecipient recipient;

  final int zulipMessageId;
  final int time; // in Unix seconds UTC, like [Message.timestamp]

  /// The content of the Zulip message, rendered as plain text.
  ///
  /// This is based on the HTML content, but reduced to plain text specifically
  /// for use in notifications.  For details, see `get_mobile_push_content` in
  /// zulip/zulip:zerver/lib/push_notifications.py .
  final String content;

  static Object? _readWhole(Map<dynamic, dynamic> json, String key) => json;

  MessageFcmMessage({
    required super.server,
    required super.realmId,
    required super.realmUrl,
    required super.userId,
    required this.senderId,
    required this.senderAvatarUrl,
    required this.senderFullName,
    required this.recipient,
    required this.zulipMessageId,
    required this.content,
    required this.time,
  });

  factory MessageFcmMessage.fromJson(Map<String, dynamic> json) {
    assert(json['event'] == 'message');
    return _$MessageFcmMessageFromJson(json);
  }

  @override
  Map<String, dynamic> toJson() {
    final result = _$MessageFcmMessageToJson(this);
    final recipient = this.recipient;
    switch (recipient) {
      case FcmMessageDmRecipient(allRecipientIds: [_] || [_, _]):
        break;
      case FcmMessageDmRecipient(:var allRecipientIds):
        result['pm_users'] = const _IntListConverter().toJson(allRecipientIds);
      case FcmMessageChannelRecipient():
        result['stream_id'] = const _IntConverter().toJson(recipient.streamId);
        if (recipient.streamName != null) result['stream'] = recipient.streamName;
        result['topic'] = recipient.topic;
    }
    result['realm_uri'] = realmUrl.toString(); // TODO(server-9): deprecated in FL 257
    return result;
  }
}

/// Data identifying where a Zulip message was sent, as part of an [FcmMessage].
sealed class FcmMessageRecipient {
  FcmMessageRecipient();

  factory FcmMessageRecipient.fromJson(Map<String, dynamic> json) {
    // There's also a `recipient_type` field, but we don't really need it.
    // The presence or absence of `stream_id` is just as informative.
    return json.containsKey('stream_id')
      ? FcmMessageChannelRecipient.fromJson(json)
      : FcmMessageDmRecipient.fromJson(json);
  }
}

/// An [FcmMessageRecipient] for a Zulip message to a stream.
@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
@_IntConverter()
class FcmMessageChannelRecipient extends FcmMessageRecipient {
  final int streamId;

  // Current servers (as of 2025) always send the stream name.  But
  // future servers might not, once clients get the name from local data.
  // So might as well be ready.
  @JsonKey(name: 'stream')
  final String? streamName;

  final TopicName topic;

  FcmMessageChannelRecipient({required this.streamId, required this.streamName, required this.topic});

  factory FcmMessageChannelRecipient.fromJson(Map<String, dynamic> json) =>
    _$FcmMessageChannelRecipientFromJson(json);
}

/// An [FcmMessageRecipient] for a Zulip message that was a DM.
class FcmMessageDmRecipient extends FcmMessageRecipient {
  final List<int> allRecipientIds;

  FcmMessageDmRecipient({required this.allRecipientIds});

  factory FcmMessageDmRecipient.fromJson(Map<String, dynamic> json) {
    return FcmMessageDmRecipient(allRecipientIds: switch (json) {
      // Group DM conversations ("huddles") are represented with `pm_users`,
      // which lists all the user IDs in the conversation.
      // TODO check they're sorted.
      {'pm_users': String pmUsers} => const _IntListConverter().fromJson(pmUsers),

      // 1:1 DM conversations have no `pm_users`.  Knowing that it's a
      // 1:1 DM, `sender_id` is enough to identify the conversation.
      {'sender_id': String senderId, 'user_id': String userId} =>
        _pairSet(_parseInt(senderId), _parseInt(userId)),

      _ => throw Exception("bad recipient"),
    });
  }

  /// The set {id1, id2}, represented as a sorted list.
  // (In set theory this is called the "pair" of id1 and id2: https://en.wikipedia.org/wiki/Axiom_of_pairing .)
  static List<int> _pairSet(int id1, int id2) {
    if (id1 == id2) return [id1];
    if (id1 < id2) return [id1, id2];
    return [id2, id1];
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
@_IntConverter()
@_IntListConverter()
class RemoveFcmMessage extends FcmMessageWithIdentity {
  @JsonKey(includeToJson: true, name: 'event')
  String get type => 'remove';

  // Servers have sent zulipMessageIds, obsoleting the singular zulipMessageId
  // and just sending the first ID there redundantly, since 2019.
  // See zulip-mobile@4acd07376.

  final List<int> zulipMessageIds;
  // final String? zulipMessageId; // obsolete; ignore

  RemoveFcmMessage({
    required super.server,
    required super.realmId,
    required super.realmUrl,
    required super.userId,
    required this.zulipMessageIds,
  });

  factory RemoveFcmMessage.fromJson(Map<String, dynamic> json) {
    assert(json['event'] == 'remove');
    return _$RemoveFcmMessageFromJson(json);
  }

  @override
  Map<String, dynamic> toJson() {
    final result = _$RemoveFcmMessageToJson(this);
    result['realm_uri'] = realmUrl.toString(); // TODO(server-9): deprecated in FL 257
    return result;
  }
}

/// An FCM message with event type `call`.
@JsonSerializable(fieldRename: FieldRename.snake)
class CallFcmMessage extends FcmMessageWithIdentity {
  @JsonKey(includeToJson: true, name: 'event')
  String get type => 'call';

  final String callId;
  final String? senderFullName;
  final String? callType; // 'audio' or 'video' or null
  final String? jitsiUrl;
  @JsonKey(fromJson: _parseIntNullable)
  final int? senderId;
  @JsonKey(fromJson: _parseIntWithDefault)
  final int timeoutSeconds;

  CallFcmMessage({
    required super.server,
    required super.realmId,
    required super.realmUrl,
    required super.userId,
    required this.callId,
    this.senderFullName,
    this.callType,
    this.jitsiUrl,
    this.senderId,
    this.timeoutSeconds = 120,
  });

  factory CallFcmMessage.fromJson(Map<String, dynamic> json) {
    assert(json['event'] == 'call');
    assert(debugLog('CALL FCM PARSING - Raw JSON: $json'));
    assert(debugLog('CALL FCM PARSING - Call ID: ${json['call_id']}'));
    assert(debugLog('CALL FCM PARSING - Sender: ${json['sender_full_name']}'));
    assert(debugLog('CALL FCM PARSING - Call Type: ${json['call_type']}'));
    assert(debugLog('CALL FCM PARSING - Jitsi URL: ${json['jitsi_url']}'));
    assert(debugLog('CALL FCM PARSING - Realm URL: ${json['realm_url'] ?? json['realm_uri']}'));
    assert(debugLog('CALL FCM PARSING - User ID: ${json['user_id']}'));
    return _$CallFcmMessageFromJson(json);
  }

  @override
  Map<String, dynamic> toJson() {
    final result = _$CallFcmMessageToJson(this);
    result['realm_uri'] = realmUrl.toString(); // TODO(server-9): deprecated in FL 257
    return result;
  }

  /// Custom converter for nullable int parsing
  static int? _parseIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Custom converter for int with default value
  static int _parseIntWithDefault(dynamic value) {
    if (value == null) return 120; // Default timeout
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 120;
    return 120;
  }
}

class _IntListConverter extends JsonConverter<List<int>, String> {
  const _IntListConverter();

  @override
  List<int> fromJson(String json) => json.split(',').map(_parseInt).toList();

  @override
  String toJson(List<int> value) => value.join(',');
}

class _IntConverter extends JsonConverter<int, String> {
  const _IntConverter();

  @override
  int fromJson(String json) => _parseInt(json);

  @override
  String toJson(int value) => value.toString();
}

int _parseInt(String string) => int.parse(string, radix: 10);