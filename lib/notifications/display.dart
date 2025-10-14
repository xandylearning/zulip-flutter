import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/model/model.dart';
import '../api/notifications.dart';
import '../host/android_notifications.dart';
import '../log.dart';
import '../model/binding.dart';
import '../model/localizations.dart';
import '../model/narrow.dart';
import '../widgets/app.dart';
import '../widgets/color.dart';
import '../widgets/theme.dart';
import 'call_notification_bridge.dart';
import '../api/model/call.dart' as model_call;
import 'callkit_incoming.dart';
import 'open.dart';

AndroidNotificationHostApi get _androidHost => ZulipBinding.instance.androidNotificationHost;

enum NotificationSound {
  // TODO(i18n): translate these file display names
  chime2(resourceName: 'chime2', fileDisplayName: 'Zulip - Low Chime.m4a'),
  chime3(resourceName: 'chime3', fileDisplayName: 'Zulip - Chime.m4a'),
  chime4(resourceName: 'chime4', fileDisplayName: 'Zulip - High Chime.m4a'),
  ringtone(resourceName: 'ringtone', fileDisplayName: 'Zulip - Call Ringtone.mp3');
  // Any new entry here must appear in `keep.xml` too, see #528.

  const NotificationSound({
    required this.resourceName,
    required this.fileDisplayName,
  });
  final String resourceName;
  final String fileDisplayName;
}

/// Service for configuring our Android "notification channel".
class NotificationChannelManager {
  /// The channel ID we use for our one notification channel, which we use for
  /// all notifications.
  // Previous values from Zulip Flutter Beta:
  //   'messages-1'
  // Previous values from Zulip Mobile:
  //   'default', 'messages-1', (alpha-only: 'messages-2'), 'messages-3'
  @visibleForTesting
  static const kChannelId = 'messages-4';

  /// The channel ID we use for call notifications.
  @visibleForTesting
  static const kCallsChannelId = 'calls-1';

  @visibleForTesting
  static const kDefaultNotificationSound = NotificationSound.chime3;

  @visibleForTesting
  static const kCallsNotificationSound = NotificationSound.ringtone;

  /// The vibration pattern we set for notifications.
  // We try to set a vibration pattern that, with the phone in one's pocket,
  // is both distinctly present and distinctly different from the default.
  // Discussion: https://chat.zulip.org/#narrow/stream/48-mobile/topic/notification.20vibration.20pattern/near/1284530
  @visibleForTesting
  static final kVibrationPattern = Int64List.fromList([0, 125, 100, 450]);

  /// The vibration pattern for call notifications.
  // Longer, more persistent pattern suitable for incoming calls.
  @visibleForTesting
  static final kCallsVibrationPattern = Int64List.fromList([0, 200, 100, 200, 100, 200, 100, 200]);

  /// Generates an Android resource URL for the given resource name and type.
  ///
  /// For example, for a resource `@raw/chime3`, where `raw` would be the
  /// resource type and `chime3` would be the resource name it generates the
  /// following URL:
  ///   `android.resource://com.zulipmobile/raw/chime3`
  ///
  /// Based on: https://stackoverflow.com/a/38340580
  static Future<String> _resourceUrlFromName({
    required String resourceTypeName,
    required String resourceEntryName,
  }) async {
    final packageInfo = await ZulipBinding.instance.packageInfo;

    // URL scheme for Android resource url.
    // See: https://developer.android.com/reference/android/content/ContentResolver#SCHEME_ANDROID_RESOURCE
    const schemeAndroidResource = 'android.resource';

    return Uri(
      scheme: schemeAndroidResource,
      host: packageInfo!.packageName,
      pathSegments: <String>[resourceTypeName, resourceEntryName],
    ).toString();
  }

  /// Prepare our notification sounds; return a URL for our default sound.
  ///
  /// Where possible, this copies each of our notification sounds into shared storage
  /// so that the user can choose between them in the system notification settings.
  ///
  /// Returns a URL for our default notification sound: either in shared storage
  /// if we successfully copied it there, or else as our internal resource file.
  static Future<String> _ensureInitNotificationSounds() async {
    String defaultSoundUrl = await _resourceUrlFromName(
      resourceTypeName: 'raw',
      resourceEntryName: kDefaultNotificationSound.resourceName);

    final shouldUseResourceFile = switch (await ZulipBinding.instance.deviceInfo) {
      // Before Android 10 Q, we don't attempt to put the sounds in shared media storage.
      // Just use the resource file directly.
      // TODO(android-sdk-29): Simplify this away.
      AndroidDeviceInfo(:var sdkInt) => sdkInt < 29,
      _                              => true,
    };
    if (shouldUseResourceFile) return defaultSoundUrl;

    // First, look to see what notification sounds we've already stored,
    // and check against our list of sounds we have.
    final soundsToAdd = NotificationSound.values.toList();

    final List<StoredNotificationSound> storedSounds;
    try {
      storedSounds = await _androidHost.listStoredSoundsInNotificationsDirectory();
    } catch (e, st) {
      assert(debugLog('$e\n$st')); // TODO(log)
      return defaultSoundUrl;
    }
    for (final storedSound in storedSounds) {
      // If the file is one we put there, and has the name we give to our
      // default sound, then use it as the default sound.
      if (storedSound.fileName == kDefaultNotificationSound.fileDisplayName
          && storedSound.isOwned) {
        defaultSoundUrl = storedSound.contentUrl;
      }

      // If it has the name of any of our sounds, then don't try to add
      // that sound.  This applies even if we didn't put it there: the
      // name is taken, so if we tried adding it anyway it'd get some
      // other name (like "Zulip - Chime (1).m4a", with " (1)" added).
      // Which means the *next* launch would try to add it again ad infinitum.
      // We could avoid this given some other way to uniquely identify the
      // file, but haven't found an obvious one.
      //
      // This does mean it's possible the file isn't the one we would have
      // put there... but it probably is, just from a debug vs. release build
      // of the app (because those may have different package names).  And anyway,
      // this is a file we're supplying for the user in case they want it, not
      // something where the app depends on it having specific content.
      soundsToAdd.removeWhere((v) => v.fileDisplayName == storedSound.fileName);
    }

    // If that leaves any sounds we haven't yet put into shared storage
    // (e.g., because this is the first run after install, or after an
    // upgrade that added a sound), then store those.

    for (final sound in soundsToAdd) {
      try {
        final url = await _androidHost.copySoundResourceToMediaStore(
          targetFileDisplayName: sound.fileDisplayName,
          sourceResourceName: sound.resourceName);

        if (sound == kDefaultNotificationSound) {
          defaultSoundUrl = url;
        }
      } catch (e, st) {
        assert(debugLog("$e\n$st")); // TODO(log)
      }
    }

    return defaultSoundUrl;
  }

  /// Create our notification channel, if it doesn't already exist.
  ///
  /// Deletes obsolete channels, if present, from old versions of the app.
  //
  // NOTE when changing anything here: the changes will not take effect
  // for existing installs of the app!  That's because we'll have already
  // created the channel with the old settings, and they're in the user's
  // hands from there.  Our choices are:
  //
  //  * Leave the old settings in place for existing installs, so the
  //    changes only apply to new installs.
  //
  //  * Change `kChannelId`, so that we abandon the old channel and use
  //    a new one.  Existing installs will get the new settings.
  //
  //    This also means that if the user has changed any of the notification
  //    settings for the channel -- like "override Do Not Disturb", or "use
  //    a different sound", or "don't pop on screen" -- their changes get
  //    reset.  So this has to be done sparingly.
  @visibleForTesting
  static Future<void> ensureChannel() async {
    // See if our current-version channel already exists; delete any obsolete
    // previous channels.
    var found = false;
    try {
      final channels = await _androidHost.getNotificationChannels();
      for (final channel in channels) {
        if (channel.id == kChannelId) {
          found = true;
        } else {
          await _androidHost.deleteNotificationChannel(channel.id);
        }
      }
    } catch (e) {
      // If we can't get notification channels, assume no channels exist
      // and proceed to create the channel
      debugLog('Failed to get notification channels: $e');
      found = false;
    }

    if (found) {
      // The channel already exists; nothing to do.
      return;
    }

    // The channel doesn't exist. Create it.

    try {
      final defaultSoundUrl = await _ensureInitNotificationSounds();

      await _androidHost.createNotificationChannel(NotificationChannel(
        id: kChannelId,
        name: 'Messages', // TODO(#1284)
        importance: NotificationImportance.high,
        lightsEnabled: true,
        soundUrl: defaultSoundUrl,
        vibrationPattern: kVibrationPattern,
      ));
    } catch (e) {
      // If we can't create the notification channel, log the error but don't crash
      debugLog('Failed to create notification channel: $e');
    }
  }

  /// Create our calls notification channel, if it doesn't already exist.
  ///
  /// This is similar to [ensureChannel] but specifically for call notifications
  /// with the ringtone sound and call-specific vibration pattern.
  /// Uses MAX importance to ensure calls wake the device from terminated state.
  @visibleForTesting
  static Future<void> ensureCallsChannel() async {
    // See if our calls channel already exists; delete any obsolete
    // previous channels.
    var found = false;
    try {
      final channels = await _androidHost.getNotificationChannels();
      for (final channel in channels) {
        if (channel.id == kCallsChannelId) {
          found = true;
        } else if (channel.id.startsWith('calls-')) {
          // Delete any old calls channels
          await _androidHost.deleteNotificationChannel(channel.id);
        }
      }
    } catch (e) {
      // If we can't get notification channels, assume no channels exist
      // and proceed to create the channel
      debugLog('Failed to get notification channels: $e');
      found = false;
    }

    if (found) {
      // The channel already exists; nothing to do.
      return;
    }

    // The channel doesn't exist. Create it.

    try {
      final ringtoneSoundUrl = await _resourceUrlFromName(
        resourceTypeName: 'raw',
        resourceEntryName: kCallsNotificationSound.resourceName);

      // Use MAX importance to ensure full-screen intent works when app is terminated
      await _androidHost.createNotificationChannel(NotificationChannel(
        id: kCallsChannelId,
        name: 'Incoming Calls', // TODO(#1284)
        importance: NotificationImportance.max,
        lightsEnabled: true,
        soundUrl: ringtoneSoundUrl,
        vibrationPattern: kCallsVibrationPattern,
      ));
    } catch (e) {
      // If we can't create the notification channel, log the error but don't crash
      debugLog('Failed to create calls notification channel: $e');
    }
  }
}

/// Service for managing the notifications shown to the user.
class NotificationDisplayManager {
  static Future<void> init() async {
    assert(defaultTargetPlatform == TargetPlatform.android);
    await NotificationChannelManager.ensureChannel();
    await NotificationChannelManager.ensureCallsChannel();
  }

  static void onFcmMessage(FcmMessage data, Map<String, dynamic> dataJson) {
    assert(defaultTargetPlatform == TargetPlatform.android);
    assert(debugLog("NOTIFICATION DISPLAY MANAGER - Processing FCM message: ${data.runtimeType}"));
    switch (data) {
      case MessageFcmMessage():
        assert(debugLog("NOTIFICATION DISPLAY MANAGER - Handling message FCM"));
        _onMessageFcmMessage(data, dataJson);
      case RemoveFcmMessage():
        assert(debugLog("NOTIFICATION DISPLAY MANAGER - Handling remove FCM"));
        _onRemoveFcmMessage(data);
      case CallFcmMessage():
        assert(debugLog("NOTIFICATION DISPLAY MANAGER - Handling call FCM"));
        _onCallFcmMessage(data);
      case UnexpectedFcmMessage():
        assert(debugLog("NOTIFICATION DISPLAY MANAGER - Handling unexpected FCM: ${dataJson}"));
        break;
    }
  }

  static Future<void> _onMessageFcmMessage(MessageFcmMessage data, Map<String, dynamic> dataJson) async {
    assert(debugLog('notif message content: ${data.content}'));
    final zulipLocalizations = GlobalLocalizations.zulipLocalizations;
    final groupKey = _groupKey(data.realmUrl, data.userId);
    final conversationKey = _conversationKey(data, groupKey);

    final globalStore = await ZulipBinding.instance.getGlobalStore();
    final account = globalStore.accounts.firstWhereOrNull((account) =>
      account.realmUrl.origin == data.realmUrl.origin && account.userId == data.userId);

    // Skip showing notifications for a logged-out account. This can occur if
    // the unregisterToken request failed previously. It would be annoying
    // to the user if notifications keep showing up after they've logged out.
    // (Also alarming: it suggests the logout didn't fully work.)
    if (account == null) {
      return;
    }

    final oldMessagingStyle = await _androidHost
      .getActiveNotificationMessagingStyleByTag(conversationKey);

    final MessagingStyle messagingStyle;
    if (oldMessagingStyle != null) {
      messagingStyle = oldMessagingStyle;
      messagingStyle.messages =
        oldMessagingStyle.messages.toList(); // Clone fixed-length list to growable.
    } else {
      messagingStyle = MessagingStyle(
        user: Person(
          key: _personKey(data.realmUrl, data.userId),
          name: zulipLocalizations.notifSelfUser),
        messages: [],
        isGroupConversation: switch (data.recipient) {
          FcmMessageChannelRecipient() => true,
          FcmMessageDmRecipient(:var allRecipientIds) when allRecipientIds.length > 2 => true,
          FcmMessageDmRecipient() => false,
        });
    }

    // The title typically won't change between messages in a conversation, but we
    // update it anyway. This means a DM sender's display name gets updated if it's
    // changed, which is a rare edge case but probably good. The main effect is that
    // group-DM threads (pending #794) get titled with the latest sender, rather than
    // the first.
    messagingStyle.conversationTitle = switch (data.recipient) {
      FcmMessageChannelRecipient(:var streamName?, :var topic) =>
        '#$streamName > ${topic.displayName}',
      FcmMessageChannelRecipient(:var topic) =>
        '#${zulipLocalizations.unknownChannelName} > ${topic.displayName}', // TODO get stream name from data
      FcmMessageDmRecipient(:var allRecipientIds) when allRecipientIds.length > 2 =>
        zulipLocalizations.notifGroupDmConversationLabel(
          data.senderFullName, allRecipientIds.length - 2), // TODO use others' names, from data
      FcmMessageDmRecipient() =>
        data.senderFullName,
    };

    messagingStyle.messages.add(MessagingStyleMessage(
      text: data.content,
      timestampMs: data.time * 1000,
      person: Person(
        key: _personKey(data.realmUrl, data.senderId),
        name: data.senderFullName,
        iconBitmap: await _fetchBitmap(data.senderAvatarUrl))));

    final intentDataUrl = NotificationOpenPayload(
      realmUrl: data.realmUrl,
      userId: data.userId,
      narrow: switch (data.recipient) {
        FcmMessageChannelRecipient(:var streamId, :var topic) =>
          TopicNarrow(streamId, topic),
        FcmMessageDmRecipient(:var allRecipientIds) =>
          DmNarrow(allRecipientIds: allRecipientIds, selfUserId: data.userId),
      }).buildAndroidNotificationUrl();

    await _androidHost.notify(
      id: kNotificationId,
      tag: conversationKey,
      channelId: NotificationChannelManager.kChannelId,
      groupKey: groupKey,

      color: kZulipBrandColor.argbInt,
      // TODO vary notification icon for debug
      smallIconResourceName: 'zulip_notification', // This name must appear in keep.xml too: https://github.com/zulip/zulip-flutter/issues/528

      messagingStyle: messagingStyle,
      number: messagingStyle.messages.length,
      extras: {
        // Used to decide when a `RemoveFcmMessage` event should clear this notification.
        kExtraLastZulipMessageId: data.zulipMessageId.toString(),
      },

      contentIntent: PendingIntent(
        // The intent data URL is distinct for each conversation, so this value
        // doesn't matter.
        requestCode: 0,
        flags: PendingIntentFlag.immutable,
        intent: AndroidIntent(
          action: IntentAction.view,
          dataUrl: intentDataUrl.toString(),
          // See these sections in the Android docs:
          //   https://developer.android.com/guide/components/activities/tasks-and-back-stack#TaskLaunchModes
          //   https://developer.android.com/reference/android/content/Intent#FLAG_ACTIVITY_CLEAR_TOP
          //
          // * From the doc on `PendingIntent.getActivity` at
          //     https://developer.android.com/reference/android/app/PendingIntent#getActivity(android.content.Context,%20int,%20android.content.Intent,%20int)
          //   > Note that the activity will be started outside of the context of an
          //   > existing activity, so you must use the Intent.FLAG_ACTIVITY_NEW_TASK
          //   > launch flag in the Intent.
          //
          // * The flag FLAG_ACTIVITY_CLEAR_TOP is mentioned as being what the
          //   notification manager does; so use that.  It has no effect as long
          //   as we only have one activity; but if we add more, it will destroy
          //   all the activities on top of the target one.
          flags: IntentFlag.activityClearTop | IntentFlag.activityNewTask)),
      autoCancel: true,
    );

    await _androidHost.notify(
      id: kNotificationId,
      tag: groupKey,
      channelId: NotificationChannelManager.kChannelId,
      groupKey: groupKey,
      isGroupSummary: true,

      color: kZulipBrandColor.argbInt,
      // TODO vary notification icon for debug
      smallIconResourceName: 'zulip_notification', // This name must appear in keep.xml too: https://github.com/zulip/zulip-flutter/issues/528
      inboxStyle: InboxStyle(
        // TODO(#570) Show organization name, not URL
        summaryText: data.realmUrl.toString()),

      // On Android 11 and lower, if autoCancel is not specified,
      // the summary notification may linger even after all child
      // notifications have been opened and cleared.
      // TODO(android-12): cut this autoCancel workaround
      autoCancel: true,
    );
  }

  static void _onRemoveFcmMessage(RemoveFcmMessage data) async {
    // We have an FCM message telling us that some Zulip messages were read
    // and should no longer appear as notifications.  We'll remove their
    // conversations' notifications, if appropriate, and then the whole
    // notification group if it's now empty.
    assert(debugLog('notif remove zulipMessageIds: ${data.zulipMessageIds}'));

    // There may be a lot of messages mentioned here, across a lot of
    // conversations.  But they'll all be for one account, so they'll
    // fall under one notification group.
    final groupKey = _groupKey(data.realmUrl, data.userId);

    // Find any conversations we can cancel the notification for.
    // The API doesn't lend itself to removing individual messages as
    // they're read, so we wait until we're ready to remove the whole
    // conversation's notification.  For background discussion, see:
    //   https://github.com/zulip/zulip-mobile/pull/4842#pullrequestreview-725817909
    var haveRemaining = false;
    final activeNotifications = await _androidHost.getActiveNotifications(
      desiredExtras: [kExtraLastZulipMessageId]);
    for (final statusBarNotification in activeNotifications) {
      // The StatusBarNotification object describes an active notification in the UI.
      // Its `.tag`, `.id`, and `.notification` are the same values as we passed to
      // [AndroidNotificationHostApi.notify] (and so to `NotificationManager#notify`
      // in the underlying Android APIs).  So these are good to match on and inspect.
      final notification = statusBarNotification.notification;

      // Sadly we don't get toString on Pigeon data classes: flutter#59027
      assert(debugLog('  existing notif'
        ' id: ${statusBarNotification.id}, tag: ${statusBarNotification.tag},'
        ' notification: (group: ${notification.group}, extras: ${notification.extras}))'));

      // Don't act on notifications that are for other Zulip accounts/identities.
      if (notification.group != groupKey) continue;

      // Don't act on the summary notification for the group.
      if (statusBarNotification.tag == groupKey) continue;

      final lastMessageIdStr = notification.extras[kExtraLastZulipMessageId];
      assert(lastMessageIdStr != null);
      if (lastMessageIdStr == null) continue; // TODO(log)
      final lastMessageId = int.parse(lastMessageIdStr, radix: 10);
      if (data.zulipMessageIds.contains(lastMessageId)) {
        // The latest Zulip message in this conversation was read.
        // That's our cue to cancel the notification for the conversation.
        await _androidHost.cancel(
          tag: statusBarNotification.tag, id: statusBarNotification.id);
        assert(debugLog('  … notif cancelled.'));
      } else {
        // This notification is for another conversation that's still unread.
        // We won't cancel the summary notification.
        haveRemaining = true;
      }
    }

    if (!haveRemaining) {
      // The notification group is now empty; it had no notifications we didn't
      // just cancel, except the summary notification.  Cancel that one too.
      //
      // Even though we enable the `autoCancel` flag for summary notification
      // during creation, the summary notification doesn't get auto canceled if
      // child notifications are canceled programatically as done above.
      await _androidHost.cancel(tag: groupKey, id: kNotificationId);
    }
  }

  static Future<void> removeNotificationsForAccount(Uri realmUrl, int userId) async {
    assert(defaultTargetPlatform == TargetPlatform.android);

    final groupKey = _groupKey(realmUrl, userId);
    final activeNotifications = await _androidHost.getActiveNotifications(
      desiredExtras: []);
    for (final statusBarNotification in activeNotifications) {
      if (statusBarNotification.notification.group == groupKey) {
        await _androidHost.cancel(
          tag: statusBarNotification.tag, id: statusBarNotification.id);
      }
    }
  }

  static Future<void> _onCallFcmMessage(CallFcmMessage data) async {
    // Handle incoming call FCM message
    assert(debugLog('CALL NOTIFICATION - Incoming call from: ${data.senderFullName ?? "Unknown"}, callId: ${data.callId}'));
    assert(debugLog('CALL NOTIFICATION - Call type: ${data.callType}'));
    assert(debugLog('CALL NOTIFICATION - Jitsi URL: ${data.jitsiUrl ?? "None"}'));
    assert(debugLog('CALL NOTIFICATION - Realm URL: ${data.realmUrl}'));
    assert(debugLog('CALL NOTIFICATION - User ID: ${data.userId}'));
    assert(debugLog('CALL NOTIFICATION - Sender ID: ${data.senderId ?? "None"}'));
    assert(debugLog('CALL NOTIFICATION - Timeout: ${data.timeoutSeconds} seconds'));

    final globalStore = await ZulipBinding.instance.getGlobalStore();
    assert(debugLog('CALL NOTIFICATION - Found ${globalStore.accounts.length} accounts'));

    final account = globalStore.accounts.firstWhereOrNull((account) =>
      account.realmUrl.origin == data.realmUrl.origin && account.userId == data.userId);

    // Skip showing notifications for a logged-out account
    if (account == null) {
      assert(debugLog('CALL NOTIFICATION - No matching account found, skipping notification'));
      assert(debugLog('CALL NOTIFICATION - Available accounts: ${globalStore.accounts.map((a) => '${a.realmUrl.origin}:${a.userId}').join(', ')}'));
      return;
    }

    // Don't show notification for call responses to outgoing calls
    // If senderId is null or equals userId, this is likely a response to our outgoing call
    if (data.senderId == null || data.senderId == data.userId) {
      assert(debugLog('CALL NOTIFICATION - This is a response to an outgoing call, not showing notification'));
      return;
    }

    assert(debugLog('CALL NOTIFICATION - Found matching account: ${account.realmUrl.origin}:${account.userId}'));

    // Check if app is in foreground - if so, show call card instead of notification
    if (_isAppInForeground()) {
      assert(debugLog('CALL NOTIFICATION - App is in foreground, showing call card instead of notification'));

      // Import the bridge and handle the call
      try {
        await CallNotificationBridge.handleCallFcmMessage(data);
        assert(debugLog('CALL NOTIFICATION - Call card triggered successfully'));
        return; // Don't show system notification
      } catch (e) {
        assert(debugLog('CALL NOTIFICATION - Error showing call card: $e'));
        // Fall back to system notification if call card fails
      }
    }

    // Show native incoming call UI using CallKit/ConnectionService in background/terminated
    assert(debugLog('CALL NOTIFICATION - App is in background, showing native incoming UI via CallKit'));

    // Create a deep link URL for the call (consumed on accept)
    final callUrl = Uri(
      scheme: 'zulip',
      host: 'call',
      pathSegments: [data.callId],
      queryParameters: {
        'realm_url': data.realmUrl.toString(),
        'user_id': data.userId.toString(),
        'call_type': data.callType ?? 'audio',
        'jitsi_url': data.jitsiUrl,
        'sender_id': (data.senderId ?? 0).toString(),
        'sender_name': data.senderFullName,
      },
    );

    assert(debugLog('CALL NOTIFICATION - Created deep link URL: $callUrl'));

    try {
      // Build absolute avatar URL from realm + senderId if available
      final String? avatarUrl = (data.senderId != null)
        ? Uri.parse(data.realmUrl.toString())
            .resolve('/avatar/${data.senderId}')
            .toString()
        : null;

      await CallKitIncomingService.instance.showIncoming(
        model_call.Call(
          callId: data.callId,
          callerId: data.senderId ?? 0,
          recipientId: data.userId,
          callType: (data.callType == 'video') ? model_call.CallType.video : model_call.CallType.audio,
          status: model_call.CallStatus.ringing,
          jitsiUrl: data.jitsiUrl ?? '',
          callerDisplayName: data.senderFullName,
          callerAvatarUrl: avatarUrl,
          callerHandle: data.senderFullName, // no phone; use name/username
        ),
        uuid: data.callId,
        handle: data.senderFullName ?? 'Caller',
        displayName: data.senderFullName ?? 'Caller',
        isVideo: data.callType == 'video',
        deepLinkUrl: callUrl.toString(),
        avatar: avatarUrl,
        androidBackgroundColorHex: '#1976D2',
        androidActionColorHex: '#FFFFFF',
        timeoutSeconds: data.timeoutSeconds,
      );
      assert(debugLog('CALL NOTIFICATION - Native incoming UI shown via CallKit'));
    } catch (e, stackTrace) {
      assert(debugLog('CALL NOTIFICATION - Failed to show CallKit incoming UI: $e'));
      assert(debugLog('CALL NOTIFICATION - Stack trace: $stackTrace'));
      rethrow;
    }
  }

  /// Check if the app is currently in the foreground
  static bool _isAppInForeground() {
    // In background isolate, ZulipApp won't be ready yet
    // This is a reliable way to detect if we're in background vs foreground
    return ZulipApp.ready.value;
  }

  /// The constant numeric "ID" we use for all non-test notifications,
  /// along with unique tags.
  ///
  /// Because we construct a unique string "tag" for each distinct
  /// notification, and Android notifications are identified by the
  /// pair (tag, ID), it's simplest to leave these numeric IDs all the same.
  static const kNotificationId = 0x00C0FFEE;

  /// A key we use in [Notification.extras] for the [Message.id] of the
  /// latest Zulip message in the notification's conversation.
  ///
  /// We use this to determine if a [RemoveFcmMessage] event should
  /// clear that specific notification.
  @visibleForTesting
  static const kExtraLastZulipMessageId = 'lastZulipMessageId';

  static String _conversationKey(MessageFcmMessage data, String groupKey) {
    final conversation = switch (data.recipient) {
      FcmMessageChannelRecipient(:var streamId, :var topic) => 'stream:$streamId:${topic.canonicalize()}',
      FcmMessageDmRecipient(:var allRecipientIds) => 'dm:${allRecipientIds.join(',')}',
    };
    return '$groupKey|$conversation';
  }

  static String _groupKey(Uri realmUrl, int userId) {
    // The realm URL can't contain a `|`, because `|` is not a URL code point:
    //   https://url.spec.whatwg.org/#url-code-points
    return "$realmUrl|$userId";
  }

  static String _personKey(Uri realmUrl, int userId) => "$realmUrl|$userId";

  static Future<Uint8List?> _fetchBitmap(Uri url) async {
    try {
      // TODO timeout to prevent waiting indefinitely
      final resp = await http.get(url);
      if (resp.statusCode == HttpStatus.ok) {
        return resp.bodyBytes;
      }
    } catch (e) {
      // TODO(log)
    }
    return null;
  }
}
