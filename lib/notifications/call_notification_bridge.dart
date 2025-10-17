import 'dart:async';
import 'dart:developer' as developer;

import 'package:collection/collection.dart';
import 'package:zulip_call_kit/zulip_call_kit.dart';

import '../api/model/call.dart';
import '../api/model/events.dart';
import '../api/notifications.dart';
import '../model/binding.dart';
import '../model/store.dart';

/// Bridge between FCM call notifications and the app's call card system.
///
/// This class handles the communication between the notification system
/// and the app's UI to show call cards when the app is open.
class CallNotificationBridge {
  static final CallNotificationBridge _instance = CallNotificationBridge._internal();
  factory CallNotificationBridge() => _instance;
  CallNotificationBridge._internal();

  final StreamController<Call> _incomingCallController = StreamController<Call>.broadcast();

  /// Stream of incoming calls that should show the call card
  Stream<Call> get incomingCallStream => _incomingCallController.stream;

  /// Handle an incoming call FCM message when the app is open
  static Future<void> handleCallFcmMessage(CallFcmMessage fcmMessage) async {
    developer.log('CallNotificationBridge: Handling call FCM message', name: 'CallNotificationBridge');
    developer.log('CallNotificationBridge: Call ID: ${fcmMessage.callId}', name: 'CallNotificationBridge');
    developer.log('CallNotificationBridge: Sender: ${fcmMessage.senderFullName}', name: 'CallNotificationBridge');
    developer.log('CallNotificationBridge: Call Type: ${fcmMessage.callType}', name: 'CallNotificationBridge');

    try {
      // Convert FCM message to Call object
      final call = _convertFcmMessageToCall(fcmMessage);

      // Get the global store to find the account
      final globalStore = await ZulipBinding.instance.getGlobalStore();
      final account = globalStore.accounts.firstWhereOrNull((Account account) =>
        account.realmUrl.origin == fcmMessage.realmUrl.origin &&
        account.userId == fcmMessage.userId);

      if (account == null) {
        developer.log('CallNotificationBridge: No matching account found', name: 'CallNotificationBridge');
        return;
      }

      // Get the per-account store
      final perAccountStore = await globalStore.perAccount(account.id);

      // Add the call to the call store to trigger the call card
      developer.log('CallNotificationBridge: Adding call to call store', name: 'CallNotificationBridge');
      perAccountStore.callStore.handleCallCreatedEvent(
        CallCreatedEvent(id: 0, call: call) // Use 0 as a placeholder ID for FCM events
      );

      developer.log('CallNotificationBridge: Call added to store successfully', name: 'CallNotificationBridge');
    } catch (e, stackTrace) {
      developer.log('CallNotificationBridge: Error handling call FCM message: $e', name: 'CallNotificationBridge');
      developer.log('CallNotificationBridge: Stack trace: $stackTrace', name: 'CallNotificationBridge');
    }
  }

  /// Convert FCM message to Call object
  static Call _convertFcmMessageToCall(CallFcmMessage fcmMessage) {
    // Determine call type
    final callType = switch (fcmMessage.callType) {
      'video' => CallType.video,
      'audio' => CallType.audio,
      _ => CallType.audio, // Default to audio
    };

    // Create the call object
    final call = Call(
      callId: fcmMessage.callId,
      callerId: fcmMessage.senderId ?? 0,
      recipientId: fcmMessage.userId,
      callType: callType,
      status: CallStatus.created, // Incoming calls start as created
      jitsiUrl: fcmMessage.jitsiUrl ?? '',
      timestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      duration: null,
    );

    developer.log('CallNotificationBridge: Converted FCM to Call: ${call.callId}', name: 'CallNotificationBridge');
    return call;
  }

  /// Check if the app is currently in the foreground
  static bool get isAppInForeground {
    // This is a simple check - in a real implementation, you might want
    // to use a more sophisticated approach to detect app state
    return true; // For now, assume app is in foreground when this is called
  }

  void dispose() {
    _incomingCallController.close();
  }
}
