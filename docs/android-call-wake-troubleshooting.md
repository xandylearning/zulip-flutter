# Android Call Wake-Up Troubleshooting Guide

## Issue: Full-Screen Notification Not Showing / App Not Waking

### Android 12+ (API 31+) Requirements

**CRITICAL**: On Android 12 and above, the `USE_FULL_SCREEN_INTENT` permission must be explicitly granted by the user in system settings.

#### How to Grant Permission:

1. **Settings → Apps → [App Name] → Notifications**
2. Scroll down to **"Full screen intent"** or **"Display over other apps"**
3. **Enable** the permission

OR:

1. **Settings → Apps → Special app access**
2. **Full screen intent** (or **Alarms & reminders**)
3. Find your app and **Allow**

### Testing Checklist

#### 1. Verify Permission (Android 12+)
```bash
adb shell dumpsys notification | grep -A 5 "com.dev.zulip.mobile.xandy"
```

Look for `canUseFullScreenIntent: true`

#### 2. Check Notification Channel
```bash
# List all notification channels
adb shell dumpsys notification | grep -A 20 "calls-1"
```

Verify:
- `importance: MAX (5)`
- `sound: android.resource://...ringtone`
- Channel exists before notification is sent

#### 3. Test FCM Message

**Kill the app completely:**
```bash
adb shell am force-stop com.dev.zulip.mobile.xandy
```

**Send test FCM notification** and check logs:
```bash
adb logcat | grep -i "CALL NOTIFICATION\|flutter"
```

Expected log sequence:
```
FCM BACKGROUND MESSAGE: {event: call, ...}
CALL NOTIFICATION - Incoming call from: [name]
CALL NOTIFICATION - ZulipApp.ready = false  ← Important!
CALL NOTIFICATION - Using full-screen intent to wake device
CALL NOTIFICATION - Notification sent successfully
```

#### 4. Common Issues

**Problem**: Logs show "App is in foreground" when it's not
- **Cause**: `ZulipApp.ready.value` is `true`
- **Fix**: Ensure `_isAppInForeground()` checks `ZulipApp.ready.value`
- **Verify**: Log should show `ZulipApp.ready = false` in background handler

**Problem**: Notification shows but doesn't wake device
- **Cause**: Missing Android 12+ permission
- **Fix**: Grant "Full screen intent" permission in Settings
- **Android 12+**: User MUST manually grant this permission

**Problem**: No notification at all
- **Cause**: Notification channel not created or has wrong importance
- **Fix**: Delete and reinstall app, or clear app data
- **Verify**: Channel importance should be `MAX (5)`

**Problem**: Deep link not working
- **Cause**: Intent flags missing or MainActivity not handling intent
- **Fix**: Verify `IntentFlag.activityNewTask | IntentFlag.activityClearTop` are set
- **Check**: `didPushRouteInformation` in `app.dart` handles `zulip://call`

### Debug Commands

**Check if app has full-screen intent permission:**
```bash
adb shell dumpsys package com.dev.zulip.mobile.xandy | grep -i "permission"
```

**Force notification (if FCM is working):**
```bash
# Wake device and check notification tray
adb shell input keyevent KEYCODE_WAKEUP
adb shell cmd statusbar expand-notifications
```

**Clear app data (resets notification channels):**
```bash
adb shell pm clear com.dev.zulip.mobile.xandy
```

### Code Verification

Ensure these are in place:

1. **Manifest** (`AndroidManifest.xml`):
   ```xml
   <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
   ```

2. **Notification Channel** (`display.dart:280`):
   ```dart
   importance: NotificationImportance.max,  // Must be MAX, not HIGH
   ```

3. **Full-Screen Intent** (`display.dart:640`):
   ```dart
   fullScreenIntent: pendingIntent,  // Same as contentIntent
   ```

4. **Kotlin Implementation** (`ZulipPlugin.kt:218-219`):
   ```kotlin
   setCategory(NotificationCompat.CATEGORY_CALL)
   setPriority(NotificationCompat.PRIORITY_MAX)
   ```

5. **App State Check** (`display.dart:658`):
   ```dart
   return ZulipApp.ready.value;  // false in background isolate
   ```

### Expected Behavior

| App State | Handler | ZulipApp.ready | Behavior |
|-----------|---------|----------------|----------|
| Foreground | `_onForegroundMessage` | `true` | In-app call card |
| Background | `_onBackgroundMessage` | `false` | Full-screen notification |
| Terminated | `_onBackgroundMessage` | `false` | Full-screen notification → App launches → CallWakeUpScreen |

### Still Not Working?

1. **Restart device** - Notification system can cache settings
2. **Reinstall app** - Clears notification channels
3. **Check Android version** - Android 12+ requires manual permission grant
4. **Test on different device** - Some manufacturers have aggressive battery optimization
5. **Check battery optimization** - Ensure app is not battery optimized
6. **Check Do Not Disturb** - Full-screen intents may be blocked in DND mode

### Manufacturer-Specific Issues

Some manufacturers (Xiaomi, Huawei, OnePlus, etc.) have additional restrictions:

- **Xiaomi MIUI**: Settings → Apps → Manage apps → [App] → Other permissions → Display pop-up windows
- **Huawei EMUI**: Settings → Apps → [App] → Battery → App launch (manual management)
- **OnePlus**: Settings → Apps → Special access → Display over other apps
- **Samsung One UI**: Should work with standard Android 12+ permission

### Reference

- Android Full-Screen Intent docs: https://developer.android.com/training/notify-user/time-sensitive#fullscreen-intent
- NotificationCompat.CATEGORY_CALL: https://developer.android.com/reference/androidx/core/app/NotificationCompat#CATEGORY_CALL
