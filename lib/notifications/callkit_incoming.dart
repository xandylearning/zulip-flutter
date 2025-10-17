import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:zulip_call_kit/zulip_call_kit.dart';

import '../api/model/call.dart';
import '../widgets/app.dart';

class CallKitIncomingService {
  static final CallKitIncomingService instance = CallKitIncomingService._();

  CallKitIncomingService._();

  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    // We rely on consuming active calls on resume/start; event stream not required here.
  }

  Future<void> showIncoming(Call call, {
    required String uuid,
    required String handle,
    required String displayName,
    required bool isVideo,
    required String deepLinkUrl,
    String? avatar,
    String? androidBackgroundColorHex,
    String? androidActionColorHex,
    int? timeoutSeconds,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final params = <String, dynamic>{
      'id': uuid,
      'nameCaller': displayName,
      'appName': 'Zulip',
      'avatar': avatar ?? call.callerAvatarUrl,
      'handle': handle,
      'type': isVideo ? 1 : 0,
      'textAccept': 'Accept',
      'textDecline': 'Decline',
      'extra': <String, dynamic>{
        'deep_link': deepLinkUrl,
        'call_id': call.callId,
        'jitsi_url': call.jitsiUrl,
        'call_type': describeEnum(call.callType),
        'avatar': avatar ?? call.callerAvatarUrl,
        'name': displayName.isNotEmpty ? displayName : (call.callerDisplayName ?? ''),
      },
      'headers': const <String, dynamic>{},
      'missedCallNotification': const <String, dynamic>{
        'showNotification': true,
        'id': 101,
        'subtitle': 'Missed call',
        'callbackText': 'Call back',
      },
      'android': <String, dynamic>{
        'isCustomNotification': true,
        'isShowLogo': true,
        'ringtonePath': 'ringtone',
        'backgroundColor': androidBackgroundColorHex ?? '#3B82F6',
        'actionColor': androidActionColorHex ?? '#FFFFFF',
        'incomingCallNotificationChannelName': 'Incoming Calls',
      },
      'ios': const <String, dynamic>{
        'iconName': 'AppIcon',
        'handleType': 'generic',
        'supportsVideo': true,
        'maximumCallGroups': 1,
        'maximumCallsPerCallGroup': 1,
      },
    };

    if (timeoutSeconds != null && timeoutSeconds > 0) {
      await const MethodChannel('flutter_callkit_incoming').invokeMethod('showCallkitIncoming', params);
      await Future<void>.delayed(Duration(seconds: timeoutSeconds));
      await end(uuid);
      return;
    }

    await const MethodChannel('flutter_callkit_incoming').invokeMethod('showCallkitIncoming', params);
  }

  Future<void> end(String uuid) async {
    try {
      await const MethodChannel('flutter_callkit_incoming').invokeMethod('endCall', <String, dynamic>{'id': uuid});
    } catch (_) {}
  }

  Future<void> maybeConsumeAcceptedCall() async {
    try {
      final dynamic raw = await const MethodChannel('flutter_callkit_incoming').invokeMethod('activeCalls');
      final List<dynamic>? calls = raw is List ? raw : null;
      if (calls == null || calls.isEmpty) return;
      final Map<String, dynamic> current = (calls.first as Map).cast<String, dynamic>();
      final Map<String, dynamic> extra = (current['extra'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final String? deepLink = extra['deep_link'] as String?;
      if (deepLink != null) await _navigateViaDeepLink(deepLink);
    } catch (_) {}
  }

  Future<void> _navigateViaDeepLink(String deepLink) async {
    try {
      // First, request a route update so the app gets the deep link normally
      await SystemNavigator.routeInformationUpdated(location: deepLink);
      // Also call a direct navigator fallback in case the above is ignored
      final uri = Uri.tryParse(deepLink);
      if (uri != null && uri.scheme == 'zulip' && uri.host == 'call') {
        // Schedule after frame to avoid Navigator lock
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // ignore: unawaited_futures
          ZulipApp.navigateCallDeepLink(uri);
        });
      }
    } catch (_) {}
  }
}


