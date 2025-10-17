# Call Feature as a Reusable Flutter Plugin

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Plugin Architecture Overview](#plugin-architecture-overview)
3. [Package Structure](#package-structure)
4. [API Design and Contracts](#api-design-and-contracts)
5. [Implementation Guide](#implementation-guide)
6. [Integration Examples](#integration-examples)
7. [Customization and Theming](#customization-and-theming)
8. [Platform-Specific Features](#platform-specific-features)
9. [Testing Strategy](#testing-strategy)
10. [Publishing and Distribution](#publishing-and-distribution)
11. [Migration Roadmap](#migration-roadmap)
12. [Best Practices](#best-practices)

---

## Executive Summary

### Vision
Transform the Zulip call feature into a **standalone, reusable Flutter plugin** (`flutter_video_call_kit`) that can be integrated into any Flutter application with minimal effort.

### Key Goals
1. **Zero-dependency on Zulip code** - Works with any backend
2. **Plug-and-play integration** - Add to any Flutter app in minutes
3. **Fully customizable** - Theme, UI, behavior all configurable
4. **Production-ready** - Includes error handling, logging, testing
5. **Cross-platform** - Android, iOS, Web support

### Value Proposition

#### For Zulip Project
- ✅ **Cleaner codebase** - Separation of concerns
- ✅ **Easier maintenance** - Isolated feature development
- ✅ **Better testing** - Independent test suite
- ✅ **Reusability** - Use in other Anthropic/Zulip projects

#### For External Developers
- ✅ **Save development time** - Don't build from scratch
- ✅ **Production-tested** - Battle-tested in Zulip app
- ✅ **Open source** - Free to use and customize
- ✅ **Well-documented** - Easy to integrate

### Package Name Options
1. `flutter_video_call_kit` (recommended)
2. `flutter_call_manager`
3. `flutter_webrtc_calls`
4. `flutter_jitsi_call_ui`

---

## Plugin Architecture Overview

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Host Application                          │
│              (Zulip, or any Flutter app)                     │
│  ┌────────────────────────────────────────────────────┐     │
│  │         Application-Specific Code                   │     │
│  │  - User authentication                              │     │
│  │  - Backend API integration                          │     │
│  │  - App-specific UI/UX                              │     │
│  └────────────────────────────────────────────────────┘     │
│                          ↓                                    │
│                   Integration Layer                           │
│  ┌────────────────────────────────────────────────────┐     │
│  │    CallKitConfiguration & Callbacks                 │     │
│  └────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────────┐
│            flutter_video_call_kit Plugin                     │
│  ┌────────────────────────────────────────────────────┐     │
│  │                  Public API                         │     │
│  │  - CallKitController                                │     │
│  │  - CallKitWidget                                    │     │
│  │  - CallKitService                                   │     │
│  └────────────────────────────────────────────────────┘     │
│  ┌────────────────────────────────────────────────────┐     │
│  │              Core Call Logic                        │     │
│  │  - Call state management (BLoC)                     │     │
│  │  - Call lifecycle management                        │     │
│  │  - WebRTC integration                               │     │
│  └────────────────────────────────────────────────────┘     │
│  ┌────────────────────────────────────────────────────┐     │
│  │                   UI Layer                          │     │
│  │  - CallWakeUpScreen                                 │     │
│  │  - CallDialingScreen                                │     │
│  │  - ActiveCallScreen                                 │     │
│  │  - CallHistoryWidget                                │     │
│  └────────────────────────────────────────────────────┘     │
│  ┌────────────────────────────────────────────────────┐     │
│  │              Platform Layer                         │     │
│  │  - Android: Notifications, Intents                  │     │
│  │  - iOS: CallKit, PushKit                           │     │
│  │  - Web: WebRTC APIs                                │     │
│  └────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────┘
                          ↓
┌──────────────────────────────────────────────────────────────┐
│                  WebRTC Backend                              │
│         (Jitsi Meet, Twilio, Agora, Custom)                 │
└──────────────────────────────────────────────────────────────┘
```

### Abstraction Layers

#### Layer 1: Backend Adapter (Protocol)
Defines the contract between plugin and backend:
```dart
abstract class CallBackendAdapter {
  Future<CallSession> createCall(CallRequest request);
  Future<void> acceptCall(String callId);
  Future<void> declineCall(String callId);
  Future<void> endCall(String callId);
  Stream<CallEvent> get callEvents;
}
```

#### Layer 2: WebRTC Provider (Implementation)
Concrete implementations for different services:
- `JitsiCallAdapter`
- `TwilioCallAdapter`
- `AgoraCallAdapter`
- `CustomWebRTCAdapter`

#### Layer 3: UI Layer (Customizable)
Pre-built screens with theming support:
- Material Design (default)
- Cupertino (iOS-style)
- Custom theme

---

## Package Structure

### Directory Layout

```
flutter_video_call_kit/
├── lib/
│   ├── flutter_video_call_kit.dart              # Main export file
│   │
│   ├── src/
│   │   ├── core/                                 # Core functionality
│   │   │   ├── models/
│   │   │   │   ├── call.dart                    # Call data model
│   │   │   │   ├── call_session.dart           # Active call session
│   │   │   │   ├── call_participant.dart       # Participant info
│   │   │   │   ├── call_settings.dart          # Settings model
│   │   │   │   └── call_event.dart             # Event types
│   │   │   │
│   │   │   ├── adapters/
│   │   │   │   ├── call_backend_adapter.dart   # Abstract adapter
│   │   │   │   ├── jitsi_adapter.dart          # Jitsi implementation
│   │   │   │   ├── twilio_adapter.dart         # Twilio implementation
│   │   │   │   └── agora_adapter.dart          # Agora implementation
│   │   │   │
│   │   │   ├── state/
│   │   │   │   ├── call_bloc.dart              # Call state management
│   │   │   │   ├── call_event.dart             # BLoC events
│   │   │   │   ├── call_state.dart             # BLoC states
│   │   │   │   └── call_repository.dart        # Data repository
│   │   │   │
│   │   │   └── services/
│   │   │       ├── call_kit_service.dart       # Main service
│   │   │       ├── notification_service.dart   # Notifications
│   │   │       ├── permission_service.dart     # Permissions
│   │   │       └── audio_service.dart          # Audio/Ringtone
│   │   │
│   │   ├── ui/                                   # UI Components
│   │   │   ├── screens/
│   │   │   │   ├── call_wakeup_screen.dart     # Incoming call
│   │   │   │   ├── call_dialing_screen.dart    # Outgoing call
│   │   │   │   ├── active_call_screen.dart     # Active call
│   │   │   │   └── call_history_screen.dart    # Call history
│   │   │   │
│   │   │   ├── widgets/
│   │   │   │   ├── call_avatar.dart            # User avatar
│   │   │   │   ├── call_action_button.dart     # Action buttons
│   │   │   │   ├── call_timer.dart             # Call duration
│   │   │   │   ├── call_controls.dart          # Mute, video, etc.
│   │   │   │   └── call_notification_banner.dart # In-app banner
│   │   │   │
│   │   │   └── theme/
│   │   │       ├── call_theme.dart             # Theme definition
│   │   │       ├── call_theme_data.dart        # Theme data
│   │   │       └── default_themes.dart         # Default themes
│   │   │
│   │   └── platform/                             # Platform-specific
│   │       ├── android/
│   │       │   ├── android_call_manager.dart   # Android impl
│   │       │   └── android_notification.dart   # Notifications
│   │       ├── ios/
│   │       │   ├── ios_call_manager.dart       # iOS impl
│   │       │   └── ios_callkit.dart            # CallKit
│   │       └── web/
│   │           └── web_call_manager.dart       # Web impl
│   │
│   └── l10n/                                     # Localization
│       ├── app_en.arb
│       ├── app_es.arb
│       └── app_fr.arb
│
├── example/                                      # Example app
│   ├── lib/
│   │   ├── main.dart                            # Example app
│   │   ├── mock_backend.dart                    # Mock backend
│   │   └── custom_theme_example.dart           # Theme example
│   └── pubspec.yaml
│
├── test/                                         # Tests
│   ├── unit/
│   │   ├── models_test.dart
│   │   ├── bloc_test.dart
│   │   └── adapters_test.dart
│   ├── widget/
│   │   └── screens_test.dart
│   └── integration/
│       └── call_flow_test.dart
│
├── android/                                      # Android native code
│   ├── src/main/kotlin/
│   │   └── com/example/flutter_video_call_kit/
│   │       └── FlutterVideoCallKitPlugin.kt
│   └── build.gradle
│
├── ios/                                          # iOS native code
│   ├── Classes/
│   │   └── FlutterVideoCallKitPlugin.swift
│   └── flutter_video_call_kit.podspec
│
├── web/                                          # Web implementation
│   └── flutter_video_call_kit.dart
│
├── pubspec.yaml                                  # Dependencies
├── README.md                                     # Documentation
├── CHANGELOG.md                                  # Version history
├── LICENSE                                       # License (MIT/BSD)
└── analysis_options.yaml                        # Lint rules
```

---

## API Design and Contracts

### 1. Main Entry Point

```dart
// lib/flutter_video_call_kit.dart

library flutter_video_call_kit;

// Core exports
export 'src/core/models/call.dart';
export 'src/core/models/call_session.dart';
export 'src/core/models/call_participant.dart';
export 'src/core/models/call_settings.dart';
export 'src/core/models/call_event.dart';

// Adapters
export 'src/core/adapters/call_backend_adapter.dart';
export 'src/core/adapters/jitsi_adapter.dart';

// Services
export 'src/core/services/call_kit_service.dart';

// UI
export 'src/ui/screens/call_wakeup_screen.dart';
export 'src/ui/screens/call_dialing_screen.dart';
export 'src/ui/screens/active_call_screen.dart';
export 'src/ui/theme/call_theme.dart';

// State management (optional - can use internal only)
export 'src/core/state/call_bloc.dart' show CallBloc, CallState, CallEvent;
```

### 2. Core Models

```dart
// lib/src/core/models/call.dart

/// Represents a call in the system
class Call {
  const Call({
    required this.id,
    required this.initiatorId,
    required this.recipientId,
    required this.type,
    required this.status,
    required this.createdAt,
    this.meetingUrl,
    this.duration,
    this.endedAt,
    this.metadata,
  });

  final String id;
  final String initiatorId;
  final String recipientId;
  final CallType type;
  final CallStatus status;
  final DateTime createdAt;
  final String? meetingUrl;
  final Duration? duration;
  final DateTime? endedAt;
  final Map<String, dynamic>? metadata;

  Call copyWith({
    String? id,
    String? initiatorId,
    String? recipientId,
    CallType? type,
    CallStatus? status,
    DateTime? createdAt,
    String? meetingUrl,
    Duration? duration,
    DateTime? endedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Call(
      id: id ?? this.id,
      initiatorId: initiatorId ?? this.initiatorId,
      recipientId: recipientId ?? this.recipientId,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      duration: duration ?? this.duration,
      endedAt: endedAt ?? this.endedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'initiatorId': initiatorId,
    'recipientId': recipientId,
    'type': type.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'meetingUrl': meetingUrl,
    'duration': duration?.inSeconds,
    'endedAt': endedAt?.toIso8601String(),
    'metadata': metadata,
  };

  factory Call.fromJson(Map<String, dynamic> json) => Call(
    id: json['id'] as String,
    initiatorId: json['initiatorId'] as String,
    recipientId: json['recipientId'] as String,
    type: CallType.values.byName(json['type'] as String),
    status: CallStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    meetingUrl: json['meetingUrl'] as String?,
    duration: json['duration'] != null
      ? Duration(seconds: json['duration'] as int)
      : null,
    endedAt: json['endedAt'] != null
      ? DateTime.parse(json['endedAt'] as String)
      : null,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}

enum CallType {
  audio,
  video,
  screenShare,
}

enum CallStatus {
  created,
  ringing,
  connecting,
  connected,
  reconnecting,
  ended,
  declined,
  cancelled,
  failed,
  timeout,
}
```

```dart
// lib/src/core/models/call_participant.dart

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

  factory CallParticipant.fromJson(Map<String, dynamic> json) => CallParticipant(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    email: json['email'] as String?,
    phoneNumber: json['phoneNumber'] as String?,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}
```

### 3. Backend Adapter Protocol

```dart
// lib/src/core/adapters/call_backend_adapter.dart

/// Abstract adapter for backend communication
///
/// Implement this to integrate with your backend system.
///
/// Example implementations:
/// - [JitsiCallAdapter] for Jitsi Meet
/// - [TwilioCallAdapter] for Twilio
/// - [AgoraCallAdapter] for Agora
abstract class CallBackendAdapter {
  /// Create a new call
  ///
  /// Returns a [CallSession] with meeting URL and call details.
  ///
  /// Throws [CallException] on error.
  Future<CallSession> createCall({
    required CallParticipant initiator,
    required CallParticipant recipient,
    required CallType type,
    Map<String, dynamic>? metadata,
  });

  /// Accept an incoming call
  ///
  /// Throws [CallException] on error.
  Future<void> acceptCall({
    required String callId,
    required CallParticipant participant,
  });

  /// Decline an incoming call
  ///
  /// Throws [CallException] on error.
  Future<void> declineCall({
    required String callId,
    required CallParticipant participant,
  });

  /// End an active call
  ///
  /// Throws [CallException] on error.
  Future<void> endCall({
    required String callId,
    Duration? duration,
  });

  /// Cancel a call before it's answered
  ///
  /// Throws [CallException] on error.
  Future<void> cancelCall({
    required String callId,
  });

  /// Send heartbeat during active call
  ///
  /// Used for keep-alive and network failure detection.
  Future<void> sendHeartbeat({
    required String callId,
    bool isBackgrounded = false,
  });

  /// Get call history
  ///
  /// Returns list of past calls, optionally filtered and paginated.
  Future<List<Call>> getCallHistory({
    int? limit,
    int? offset,
    String? userId,
    CallStatus? status,
  });

  /// Stream of call events from backend
  ///
  /// Emits events like:
  /// - Incoming calls
  /// - Call status changes
  /// - Participant joined/left
  /// - Call ended
  Stream<CallEvent> get callEvents;

  /// Dispose resources
  Future<void> dispose();
}
```

```dart
// lib/src/core/models/call_session.dart

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
}
```

```dart
// lib/src/core/models/call_event.dart

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
  final Duration? duration;
}

enum CallEndReason {
  normal,
  declined,
  cancelled,
  timeout,
  networkFailure,
  error,
}
```

### 4. Main Service API

```dart
// lib/src/core/services/call_kit_service.dart

/// Main service for managing calls
///
/// This is the primary interface for integrating the call kit.
///
/// Example usage:
/// ```dart
/// final callKit = CallKitService(
///   adapter: JitsiCallAdapter(serverUrl: 'https://meet.jit.si'),
///   config: CallKitConfiguration(
///     appName: 'MyApp',
///     onIncomingCall: (call, initiator) {
///       // Handle incoming call
///     },
///   ),
/// );
///
/// await callKit.initialize();
///
/// // Start a call
/// final session = await callKit.startCall(
///   recipient: CallParticipant(
///     id: 'user123',
///     displayName: 'John Doe',
///   ),
///   type: CallType.video,
/// );
/// ```
class CallKitService {
  CallKitService({
    required CallBackendAdapter adapter,
    required CallKitConfiguration config,
    CallBloc? callBloc,
  }) : _adapter = adapter,
       _config = config,
       _callBloc = callBloc ?? CallBloc(adapter: adapter);

  final CallBackendAdapter _adapter;
  final CallKitConfiguration _config;
  final CallBloc _callBloc;

  StreamSubscription? _eventSubscription;

  /// Initialize the call kit service
  ///
  /// Must be called before using any other methods.
  /// Sets up event listeners, permissions, etc.
  Future<void> initialize() async {
    // Request permissions
    await _requestPermissions();

    // Subscribe to backend events
    _eventSubscription = _adapter.callEvents.listen(_handleCallEvent);

    // Initialize platform-specific features
    await _initializePlatform();
  }

  /// Start a new call
  ///
  /// Returns [CallSession] with meeting details.
  ///
  /// Throws [CallException] on error.
  Future<CallSession> startCall({
    required CallParticipant recipient,
    required CallType type,
    Map<String, dynamic>? metadata,
  }) async {
    final initiator = _config.currentUser;
    if (initiator == null) {
      throw CallException('Current user not configured');
    }

    final session = await _adapter.createCall(
      initiator: initiator,
      recipient: recipient,
      type: type,
      metadata: metadata,
    );

    // Update state
    _callBloc.add(CallStarted(session: session));

    return session;
  }

  /// Accept an incoming call
  Future<void> acceptCall(Call call) async {
    final participant = _config.currentUser;
    if (participant == null) {
      throw CallException('Current user not configured');
    }

    await _adapter.acceptCall(
      callId: call.id,
      participant: participant,
    );

    _callBloc.add(CallAccepted(callId: call.id));
  }

  /// Decline an incoming call
  Future<void> declineCall(Call call) async {
    final participant = _config.currentUser;
    if (participant == null) {
      throw CallException('Current user not configured');
    }

    await _adapter.declineCall(
      callId: call.id,
      participant: participant,
    );

    _callBloc.add(CallDeclined(callId: call.id));
  }

  /// End an active call
  Future<void> endCall(Call call, {Duration? duration}) async {
    await _adapter.endCall(
      callId: call.id,
      duration: duration,
    );

    _callBloc.add(CallEnded(callId: call.id, duration: duration));
  }

  /// Get call history
  Future<List<Call>> getCallHistory({
    int? limit,
    int? offset,
  }) async {
    return await _adapter.getCallHistory(
      limit: limit,
      offset: offset,
      userId: _config.currentUser?.id,
    );
  }

  /// Stream of call state changes
  Stream<CallState> get callStateStream => _callBloc.stream;

  /// Current call state
  CallState get currentState => _callBloc.state;

  /// Show incoming call screen
  Future<void> showIncomingCallScreen(
    BuildContext context,
    Call call,
    CallParticipant initiator,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallKitProvider(
          service: this,
          child: CallWakeUpScreen(
            call: call,
            initiator: initiator,
            theme: _config.theme,
          ),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _handleCallEvent(CallEvent event) {
    switch (event) {
      case IncomingCallEvent(:final call, :final initiator):
        _config.onIncomingCall?.call(call, initiator);

      case CallStatusChangedEvent():
        _config.onCallStatusChanged?.call(
          event.callId,
          event.oldStatus,
          event.newStatus,
        );

      case CallEndedEvent():
        _config.onCallEnded?.call(event.callId, event.reason, event.duration);

      default:
        // Handle other events
    }
  }

  Future<void> _requestPermissions() async {
    // Request camera, microphone, notification permissions
  }

  Future<void> _initializePlatform() async {
    // Platform-specific initialization
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _eventSubscription?.cancel();
    await _adapter.dispose();
    await _callBloc.close();
  }
}
```

```dart
// lib/src/core/models/call_settings.dart

/// Configuration for the call kit
class CallKitConfiguration {
  const CallKitConfiguration({
    required this.appName,
    this.currentUser,
    this.theme,
    this.onIncomingCall,
    this.onCallStatusChanged,
    this.onCallEnded,
    this.enableCallHistory = true,
    this.enableNotifications = true,
    this.ringtoneAsset,
    this.maxCallDuration = const Duration(hours: 2),
    this.callTimeout = const Duration(seconds: 45),
    this.heartbeatInterval = const Duration(seconds: 5),
  });

  /// Application name (shown in notifications)
  final String appName;

  /// Current logged-in user
  final CallParticipant? currentUser;

  /// Theme for call UI
  final CallThemeData? theme;

  /// Callback for incoming calls
  final void Function(Call call, CallParticipant initiator)? onIncomingCall;

  /// Callback for call status changes
  final void Function(String callId, CallStatus oldStatus, CallStatus newStatus)?
      onCallStatusChanged;

  /// Callback for call ended
  final void Function(String callId, CallEndReason reason, Duration? duration)?
      onCallEnded;

  /// Enable call history tracking
  final bool enableCallHistory;

  /// Enable system notifications
  final bool enableNotifications;

  /// Custom ringtone asset path
  final String? ringtoneAsset;

  /// Maximum call duration (auto-end after this)
  final Duration maxCallDuration;

  /// Call timeout (cancel if not answered)
  final Duration callTimeout;

  /// Heartbeat interval during active calls
  final Duration heartbeatInterval;
}
```

### 5. Jitsi Adapter Implementation

```dart
// lib/src/core/adapters/jitsi_adapter.dart

/// Jitsi Meet adapter implementation
///
/// Integrates with Jitsi Meet for video calls.
///
/// Example:
/// ```dart
/// final adapter = JitsiCallAdapter(
///   serverUrl: 'https://meet.jit.si',
///   jwt: 'optional-jwt-token',
/// );
/// ```
class JitsiCallAdapter implements CallBackendAdapter {
  JitsiCallAdapter({
    required this.serverUrl,
    this.jwt,
    this.apiEndpoint,
    this.httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String serverUrl;
  final String? jwt;
  final String? apiEndpoint; // Optional backend API for call management
  final http.Client _httpClient;

  final _eventController = StreamController<CallEvent>.broadcast();

  @override
  Future<CallSession> createCall({
    required CallParticipant initiator,
    required CallParticipant recipient,
    required CallType type,
    Map<String, dynamic>? metadata,
  }) async {
    // Generate unique room name
    final roomName = _generateRoomName(initiator.id, recipient.id);
    final meetingUrl = '$serverUrl/$roomName';

    // If backend API available, register call
    Call? call;
    if (apiEndpoint != null) {
      final response = await _httpClient.post(
        Uri.parse('$apiEndpoint/calls'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'initiatorId': initiator.id,
          'recipientId': recipient.id,
          'type': type.name,
          'roomName': roomName,
          'metadata': metadata,
        }),
      );

      if (response.statusCode != 200) {
        throw CallException('Failed to create call: ${response.body}');
      }

      call = Call.fromJson(jsonDecode(response.body));
    } else {
      // Create local call object
      call = Call(
        id: const Uuid().v4(),
        initiatorId: initiator.id,
        recipientId: recipient.id,
        type: type,
        status: CallStatus.created,
        createdAt: DateTime.now(),
        meetingUrl: meetingUrl,
      );
    }

    return CallSession(
      call: call,
      meetingUrl: meetingUrl,
      meetingId: roomName,
      token: jwt,
      config: {
        'serverUrl': serverUrl,
        'roomName': roomName,
        'startWithAudioMuted': false,
        'startWithVideoMuted': type == CallType.audio,
      },
    );
  }

  @override
  Future<void> acceptCall({
    required String callId,
    required CallParticipant participant,
  }) async {
    if (apiEndpoint != null) {
      await _httpClient.post(
        Uri.parse('$apiEndpoint/calls/$callId/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'participantId': participant.id}),
      );
    }

    _eventController.add(CallStatusChangedEvent(
      timestamp: DateTime.now(),
      callId: callId,
      oldStatus: CallStatus.ringing,
      newStatus: CallStatus.connecting,
    ));
  }

  @override
  Future<void> declineCall({
    required String callId,
    required CallParticipant participant,
  }) async {
    if (apiEndpoint != null) {
      await _httpClient.post(
        Uri.parse('$apiEndpoint/calls/$callId/decline'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'participantId': participant.id}),
      );
    }

    _eventController.add(CallEndedEvent(
      timestamp: DateTime.now(),
      callId: callId,
      reason: CallEndReason.declined,
    ));
  }

  @override
  Future<void> endCall({
    required String callId,
    Duration? duration,
  }) async {
    if (apiEndpoint != null) {
      await _httpClient.post(
        Uri.parse('$apiEndpoint/calls/$callId/end'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'duration': duration?.inSeconds,
        }),
      );
    }

    _eventController.add(CallEndedEvent(
      timestamp: DateTime.now(),
      callId: callId,
      reason: CallEndReason.normal,
      duration: duration,
    ));
  }

  @override
  Future<void> cancelCall({required String callId}) async {
    if (apiEndpoint != null) {
      await _httpClient.post(
        Uri.parse('$apiEndpoint/calls/$callId/cancel'),
      );
    }

    _eventController.add(CallEndedEvent(
      timestamp: DateTime.now(),
      callId: callId,
      reason: CallEndReason.cancelled,
    ));
  }

  @override
  Future<void> sendHeartbeat({
    required String callId,
    bool isBackgrounded = false,
  }) async {
    if (apiEndpoint != null) {
      await _httpClient.post(
        Uri.parse('$apiEndpoint/calls/$callId/heartbeat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'isBackgrounded': isBackgrounded}),
      );
    }
  }

  @override
  Future<List<Call>> getCallHistory({
    int? limit,
    int? offset,
    String? userId,
    CallStatus? status,
  }) async {
    if (apiEndpoint == null) {
      return [];
    }

    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();
    if (userId != null) queryParams['userId'] = userId;
    if (status != null) queryParams['status'] = status.name;

    final uri = Uri.parse('$apiEndpoint/calls/history')
        .replace(queryParameters: queryParams);

    final response = await _httpClient.get(uri);

    if (response.statusCode != 200) {
      throw CallException('Failed to get call history: ${response.body}');
    }

    final List<dynamic> json = jsonDecode(response.body);
    return json.map((e) => Call.fromJson(e)).toList();
  }

  @override
  Stream<CallEvent> get callEvents => _eventController.stream;

  String _generateRoomName(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return 'call-${ids.join('-')}-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> dispose() async {
    await _eventController.close();
    _httpClient.close();
  }
}
```

---

## Implementation Guide

### Step 1: Create Plugin Structure

```bash
# Create new Flutter plugin
flutter create --template=plugin --platforms=android,ios,web flutter_video_call_kit

cd flutter_video_call_kit

# Add dependencies
flutter pub add flutter_bloc equatable jitsi_meet_flutter_sdk audioplayers permission_handler uuid http

# Add dev dependencies
flutter pub add --dev bloc_test mocktail flutter_lints
```

### Step 2: Implement Core Models

Create all model files as shown in the API Design section.

### Step 3: Implement Backend Adapter

Start with Jitsi adapter (shown above), then add others as needed.

### Step 4: Implement BLoC State Management

```dart
// lib/src/core/state/call_bloc.dart

class CallBloc extends Bloc<CallEvent, CallState> {
  CallBloc({required CallBackendAdapter adapter})
      : _adapter = adapter,
        super(const CallInitial()) {
    on<CallStarted>(_onCallStarted);
    on<CallAccepted>(_onCallAccepted);
    on<CallDeclined>(_onCallDeclined);
    on<CallEnded>(_onCallEnded);

    // Subscribe to backend events
    _eventSubscription = _adapter.callEvents.listen(_onBackendEvent);
  }

  final CallBackendAdapter _adapter;
  StreamSubscription? _eventSubscription;

  Future<void> _onCallStarted(
    CallStarted event,
    Emitter<CallState> emit,
  ) async {
    emit(CallRinging(session: event.session));
  }

  Future<void> _onCallAccepted(
    CallAccepted event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallRinging) {
      final session = (state as CallRinging).session;
      emit(CallActive(
        session: session.copyWith(
          call: session.call.copyWith(status: CallStatus.connected),
        ),
        startTime: DateTime.now(),
      ));
    }
  }

  void _onBackendEvent(CallEvent event) {
    // Handle backend events
    if (event is IncomingCallEvent) {
      // Emit incoming call state
      final session = CallSession(
        call: event.call,
        meetingUrl: event.call.meetingUrl ?? '',
        meetingId: event.call.id,
      );
      add(CallStarted(session: session));
    }
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    return super.close();
  }
}
```

### Step 5: Implement UI Widgets

```dart
// lib/src/ui/screens/call_wakeup_screen.dart

/// Incoming call screen
///
/// Displays when receiving a call, allows accept/decline.
class CallWakeUpScreen extends StatelessWidget {
  const CallWakeUpScreen({
    super.key,
    required this.call,
    required this.initiator,
    this.theme,
    this.onAccept,
    this.onDecline,
  });

  final Call call;
  final CallParticipant initiator;
  final CallThemeData? theme;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final callKit = CallKitProvider.of(context);
    final effectiveTheme = theme ?? CallThemeData.defaultTheme();

    return Scaffold(
      backgroundColor: effectiveTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  CallAvatar(
                    imageUrl: initiator.avatarUrl,
                    displayName: initiator.displayName,
                    size: 120,
                    theme: effectiveTheme,
                  ),
                  const SizedBox(height: 32),

                  // Caller name
                  Text(
                    initiator.displayName,
                    style: effectiveTheme.titleTextStyle,
                  ),
                  const SizedBox(height: 16),

                  // Call type
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: effectiveTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      call.type == CallType.video
                          ? 'Incoming video call'
                          : 'Incoming audio call',
                      style: effectiveTheme.bodyTextStyle,
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CallActionButton(
                    onPressed: () {
                      onDecline?.call();
                      callKit.declineCall(call);
                    },
                    backgroundColor: effectiveTheme.declineColor,
                    icon: Icons.call_end,
                    label: 'Decline',
                    theme: effectiveTheme,
                  ),
                  const SizedBox(width: 48),
                  CallActionButton(
                    onPressed: () {
                      onAccept?.call();
                      callKit.acceptCall(call);
                    },
                    backgroundColor: effectiveTheme.acceptColor,
                    icon: Icons.call,
                    label: 'Accept',
                    theme: effectiveTheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 6: Create Example App

```dart
// example/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_video_call_kit/flutter_video_call_kit.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late CallKitService _callKit;

  @override
  void initState() {
    super.initState();
    _initializeCallKit();
  }

  Future<void> _initializeCallKit() async {
    _callKit = CallKitService(
      adapter: JitsiCallAdapter(
        serverUrl: 'https://meet.jit.si',
        // Optional: backend API endpoint for call management
        apiEndpoint: 'https://your-backend.com/api',
      ),
      config: CallKitConfiguration(
        appName: 'Example App',
        currentUser: const CallParticipant(
          id: 'user-123',
          displayName: 'John Doe',
          email: 'john@example.com',
        ),
        onIncomingCall: (call, initiator) {
          // Show incoming call screen
          _callKit.showIncomingCallScreen(context, call, initiator);
        },
        theme: CallThemeData(
          backgroundColor: Colors.grey[900]!,
          primaryColor: Colors.blue,
          acceptColor: Colors.green,
          declineColor: Colors.red,
        ),
      ),
    );

    await _callKit.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Kit Example',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Call Kit Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () async {
                  // Start a video call
                  final session = await _callKit.startCall(
                    recipient: const CallParticipant(
                      id: 'user-456',
                      displayName: 'Jane Smith',
                    ),
                    type: CallType.video,
                  );

                  // Navigate to active call screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActiveCallScreen(
                        session: session,
                      ),
                    ),
                  );
                },
                child: const Text('Start Video Call'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  // Start an audio call
                  final session = await _callKit.startCall(
                    recipient: const CallParticipant(
                      id: 'user-456',
                      displayName: 'Jane Smith',
                    ),
                    type: CallType.audio,
                  );

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ActiveCallScreen(
                        session: session,
                      ),
                    ),
                  );
                },
                child: const Text('Start Audio Call'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callKit.dispose();
    super.dispose();
  }
}
```

---

## Integration Examples

### Example 1: Integrate into Existing Zulip App

```dart
// In Zulip app - lib/model/zulip_call_adapter.dart

/// Zulip-specific call adapter
class ZulipCallAdapter implements CallBackendAdapter {
  ZulipCallAdapter({
    required this.connection,
    required this.callStore,
  });

  final ApiConnection connection;
  final CallStore callStore;

  @override
  Future<CallSession> createCall({
    required CallParticipant initiator,
    required CallParticipant recipient,
    required CallType type,
    Map<String, dynamic>? metadata,
  }) async {
    // Use existing Zulip API
    final response = await api.createCall(
      connection,
      userId: int.parse(recipient.id),
      isVideoCall: type == CallType.video,
    );

    final call = Call(
      id: response.callId,
      initiatorId: initiator.id,
      recipientId: recipient.id,
      type: type,
      status: CallStatus.created,
      createdAt: DateTime.now(),
      meetingUrl: response.callUrl,
    );

    return CallSession(
      call: call,
      meetingUrl: response.callUrl,
      meetingId: response.callId,
    );
  }

  @override
  Stream<CallEvent> get callEvents {
    // Convert Zulip CallStore events to plugin events
    return callStore.incomingCallStream.map((zulipCall) {
      return IncomingCallEvent(
        timestamp: DateTime.now(),
        call: _convertZulipCallToPluginCall(zulipCall),
        initiator: _getParticipant(zulipCall.callerId),
      );
    });
  }

  // Implement other methods...
}

// In main app initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final globalStore = await LiveGlobalStore.load();

  // Initialize call kit plugin
  final callKit = CallKitService(
    adapter: ZulipCallAdapter(
      connection: globalStore.apiConnectionFromAccount(account),
      callStore: perAccountStore.callStore,
    ),
    config: CallKitConfiguration(
      appName: 'Zulip',
      currentUser: CallParticipant(
        id: account.userId.toString(),
        displayName: user.fullName,
        avatarUrl: user.avatarUrl,
      ),
    ),
  );

  await callKit.initialize();

  runApp(ZulipApp(globalStore: globalStore, callKit: callKit));
}
```

### Example 2: Use with Custom Backend

```dart
// Custom backend adapter
class MyCustomCallAdapter implements CallBackendAdapter {
  MyCustomCallAdapter({
    required this.apiClient,
    required this.websocketUrl,
  });

  final ApiClient apiClient;
  final String websocketUrl;

  late WebSocketChannel _channel;

  @override
  Future<CallSession> createCall({
    required CallParticipant initiator,
    required CallParticipant recipient,
    required CallType type,
    Map<String, dynamic>? metadata,
  }) async {
    // Call your custom API
    final response = await apiClient.post('/v1/calls', {
      'from': initiator.id,
      'to': recipient.id,
      'type': type.name,
      'metadata': metadata,
    });

    return CallSession(
      call: Call.fromJson(response['call']),
      meetingUrl: response['meeting_url'],
      meetingId: response['meeting_id'],
      token: response['token'],
    );
  }

  @override
  Stream<CallEvent> get callEvents {
    // Connect to WebSocket
    _channel = WebSocketChannel.connect(Uri.parse(websocketUrl));

    return _channel.stream.map((message) {
      final json = jsonDecode(message);
      return _parseCallEvent(json);
    });
  }

  CallEvent _parseCallEvent(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'incoming_call':
        return IncomingCallEvent(
          timestamp: DateTime.parse(json['timestamp']),
          call: Call.fromJson(json['call']),
          initiator: CallParticipant.fromJson(json['initiator']),
        );
      // Handle other event types...
      default:
        throw UnimplementedError('Unknown event type: ${json['type']}');
    }
  }

  // Implement other methods...
}
```

### Example 3: Minimal Integration (No Backend)

```dart
// Peer-to-peer calls without backend
void main() {
  runApp(MaterialApp(
    home: Builder(
      builder: (context) {
        return ElevatedButton(
          onPressed: () {
            // Direct Jitsi call without backend
            final session = CallSession(
              call: Call(
                id: Uuid().v4(),
                initiatorId: 'me',
                recipientId: 'friend',
                type: CallType.video,
                status: CallStatus.created,
                createdAt: DateTime.now(),
                meetingUrl: 'https://meet.jit.si/my-room',
              ),
              meetingUrl: 'https://meet.jit.si/my-room',
              meetingId: 'my-room',
            );

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ActiveCallScreen(
                  session: session,
                  // No backend adapter needed for basic calls
                ),
              ),
            );
          },
          child: const Text('Join Call'),
        );
      },
    ),
  ));
}
```

---

## Customization and Theming

### Theme System

```dart
// lib/src/ui/theme/call_theme_data.dart

/// Theme data for call UI
class CallThemeData {
  const CallThemeData({
    this.backgroundColor = const Color(0xFF121212),
    this.surfaceColor = const Color(0xFF1E1E1E),
    this.primaryColor = const Color(0xFF3B82F6),
    this.acceptColor = const Color(0xFF10B981),
    this.declineColor = const Color(0xFFEF4444),
    this.textColor = Colors.white,
    this.subtextColor = Colors.white70,
    this.titleTextStyle,
    this.bodyTextStyle,
    this.buttonTextStyle,
    this.avatarBorderColor,
    this.avatarBorderWidth = 4.0,
    this.buttonSize = 72.0,
    this.iconSize = 36.0,
    this.borderRadius = 20.0,
  });

  final Color backgroundColor;
  final Color surfaceColor;
  final Color primaryColor;
  final Color acceptColor;
  final Color declineColor;
  final Color textColor;
  final Color subtextColor;

  final TextStyle? titleTextStyle;
  final TextStyle? bodyTextStyle;
  final TextStyle? buttonTextStyle;

  final Color? avatarBorderColor;
  final double avatarBorderWidth;
  final double buttonSize;
  final double iconSize;
  final double borderRadius;

  /// Default Material Design theme
  factory CallThemeData.defaultTheme() => const CallThemeData();

  /// iOS-style theme
  factory CallThemeData.cupertino() => const CallThemeData(
    backgroundColor: Color(0xFFF2F2F7),
    surfaceColor: Colors.white,
    primaryColor: Color(0xFF007AFF),
    acceptColor: Color(0xFF34C759),
    declineColor: Color(0xFFFF3B30),
    textColor: Colors.black,
    subtextColor: Colors.black54,
    borderRadius: 14.0,
  );

  /// Dark theme
  factory CallThemeData.dark() => const CallThemeData(
    backgroundColor: Colors.black,
    surfaceColor: Color(0xFF1C1C1E),
    primaryColor: Color(0xFF0A84FF),
    textColor: Colors.white,
    subtextColor: Colors.white60,
  );

  /// Light theme
  factory CallThemeData.light() => const CallThemeData(
    backgroundColor: Colors.white,
    surfaceColor: Color(0xFFF5F5F5),
    primaryColor: Color(0xFF2196F3),
    acceptColor: Color(0xFF4CAF50),
    declineColor: Color(0xFFF44336),
    textColor: Colors.black87,
    subtextColor: Colors.black54,
  );

  CallThemeData copyWith({
    Color? backgroundColor,
    Color? surfaceColor,
    Color? primaryColor,
    Color? acceptColor,
    Color? declineColor,
    Color? textColor,
    Color? subtextColor,
    TextStyle? titleTextStyle,
    TextStyle? bodyTextStyle,
    TextStyle? buttonTextStyle,
    Color? avatarBorderColor,
    double? avatarBorderWidth,
    double? buttonSize,
    double? iconSize,
    double? borderRadius,
  }) {
    return CallThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      primaryColor: primaryColor ?? this.primaryColor,
      acceptColor: acceptColor ?? this.acceptColor,
      declineColor: declineColor ?? this.declineColor,
      textColor: textColor ?? this.textColor,
      subtextColor: subtextColor ?? this.subtextColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      bodyTextStyle: bodyTextStyle ?? this.bodyTextStyle,
      buttonTextStyle: buttonTextStyle ?? this.buttonTextStyle,
      avatarBorderColor: avatarBorderColor ?? this.avatarBorderColor,
      avatarBorderWidth: avatarBorderWidth ?? this.avatarBorderWidth,
      buttonSize: buttonSize ?? this.buttonSize,
      iconSize: iconSize ?? this.iconSize,
      borderRadius: borderRadius ?? this.borderRadius,
    );
  }
}
```

### Custom UI Example

```dart
// Build custom call screen using plugin components
class CustomCallScreen extends StatelessWidget {
  const CustomCallScreen({
    super.key,
    required this.call,
    required this.initiator,
  });

  final Call call;
  final CallParticipant initiator;

  @override
  Widget build(BuildContext context) {
    final callKit = CallKitProvider.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade900,
              Colors.blue.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Incoming Call',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Use plugin's avatar widget
              CallAvatar(
                imageUrl: initiator.avatarUrl,
                displayName: initiator.displayName,
                size: 150,
              ),

              const Spacer(),

              // Custom action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decline with animation
                  GestureDetector(
                    onTap: () => callKit.declineCall(call),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade600,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),

                  // Accept with animation
                  GestureDetector(
                    onTap: () => callKit.acceptCall(call),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.shade600,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Platform-Specific Features

### Android

```kotlin
// android/src/main/kotlin/FlutterVideoCallKitPlugin.kt

class FlutterVideoCallKitPlugin : FlutterPlugin, MethodCallHandler {
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "showFullScreenNotification" -> {
        val callId = call.argument<String>("callId")
        val callerName = call.argument<String>("callerName")
        showFullScreenNotification(callId!!, callerName!!)
        result.success(null)
      }
      else -> result.notImplemented()
    }
  }

  private fun showFullScreenNotification(callId: String, callerName: String) {
    val intent = Intent(context, CallActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
      putExtra("callId", callId)
      putExtra("callerName", callerName)
    }

    val fullScreenPendingIntent = PendingIntent.getActivity(
      context,
      0,
      intent,
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )

    val notification = NotificationCompat.Builder(context, CHANNEL_ID)
      .setSmallIcon(R.drawable.ic_call)
      .setContentTitle("Incoming call")
      .setContentText("$callerName is calling")
      .setPriority(NotificationCompat.PRIORITY_MAX)
      .setCategory(NotificationCompat.CATEGORY_CALL)
      .setFullScreenIntent(fullScreenPendingIntent, true)
      .setAutoCancel(true)
      .build()

    notificationManager.notify(NOTIFICATION_ID, notification)
  }
}
```

### iOS

```swift
// ios/Classes/FlutterVideoCallKitPlugin.swift

import CallKit
import AVFoundation

public class FlutterVideoCallKitPlugin: NSObject, FlutterPlugin, CXProviderDelegate {
  private let provider: CXProvider
  private let callController = CXCallController()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_video_call_kit",
      binaryMessenger: registrar.messenger()
    )
    let instance = FlutterVideoCallKitPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "reportIncomingCall":
      if let args = call.arguments as? [String: Any],
         let callId = args["callId"] as? String,
         let callerName = args["callerName"] as? String {
        reportIncomingCall(callId: callId, callerName: callerName) { error in
          if let error = error {
            result(FlutterError(code: "CALL_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(nil)
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func reportIncomingCall(
    callId: String,
    callerName: String,
    completion: @escaping (Error?) -> Void
  ) {
    let update = CXCallUpdate()
    update.remoteHandle = CXHandle(type: .generic, value: callId)
    update.localizedCallerName = callerName
    update.hasVideo = true

    let uuid = UUID(uuidString: callId) ?? UUID()
    provider.reportNewIncomingCall(with: uuid, update: update) { error in
      completion(error)
    }
  }

  // CXProviderDelegate methods
  public func providerDidReset(_ provider: CXProvider) {
    // Handle provider reset
  }
}
```

---

## Testing Strategy

### Unit Tests

```dart
// test/unit/jitsi_adapter_test.dart

void main() {
  group('JitsiCallAdapter', () {
    late MockHttpClient mockClient;
    late JitsiCallAdapter adapter;

    setUp(() {
      mockClient = MockHttpClient();
      adapter = JitsiCallAdapter(
        serverUrl: 'https://meet.jit.si',
        apiEndpoint: 'https://api.example.com',
        httpClient: mockClient,
      );
    });

    test('createCall returns CallSession', () async {
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({
          'id': 'call-123',
          'initiatorId': 'user-1',
          'recipientId': 'user-2',
          'type': 'video',
          'status': 'created',
          'createdAt': DateTime.now().toIso8601String(),
        }),
        200,
      ));

      final session = await adapter.createCall(
        initiator: const CallParticipant(
          id: 'user-1',
          displayName: 'John',
        ),
        recipient: const CallParticipant(
          id: 'user-2',
          displayName: 'Jane',
        ),
        type: CallType.video,
      );

      expect(session.call.id, 'call-123');
      expect(session.call.type, CallType.video);
      expect(session.meetingUrl, contains('meet.jit.si'));
    });

    test('acceptCall sends correct API request', () async {
      when(() => mockClient.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response('{}', 200));

      await adapter.acceptCall(
        callId: 'call-123',
        participant: const CallParticipant(id: 'user-2', displayName: 'Jane'),
      );

      verify(() => mockClient.post(
        Uri.parse('https://api.example.com/calls/call-123/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'participantId': 'user-2'}),
      )).called(1);
    });
  });
}
```

### Widget Tests

```dart
// test/widget/call_wakeup_screen_test.dart

void main() {
  testWidgets('CallWakeUpScreen displays caller info', (tester) async {
    final call = Call(
      id: 'test-call',
      initiatorId: 'user-1',
      recipientId: 'user-2',
      type: CallType.video,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
    );

    final initiator = const CallParticipant(
      id: 'user-1',
      displayName: 'John Doe',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CallWakeUpScreen(
          call: call,
          initiator: initiator,
        ),
      ),
    );

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Incoming video call'), findsOneWidget);
    expect(find.byIcon(Icons.call), findsOneWidget);
    expect(find.byIcon(Icons.call_end), findsOneWidget);
  });

  testWidgets('Accept button triggers callback', (tester) async {
    bool acceptCalled = false;

    final call = Call(
      id: 'test-call',
      initiatorId: 'user-1',
      recipientId: 'user-2',
      type: CallType.video,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CallWakeUpScreen(
          call: call,
          initiator: const CallParticipant(id: 'user-1', displayName: 'John'),
          onAccept: () => acceptCalled = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.call));
    await tester.pump();

    expect(acceptCalled, true);
  });
}
```

---

## Publishing and Distribution

### 1. Prepare for Publishing

```yaml
# pubspec.yaml
name: flutter_video_call_kit
description: A comprehensive Flutter plugin for video/audio calling with customizable UI and multiple backend support.
version: 1.0.0
homepage: https://github.com/your-org/flutter_video_call_kit
repository: https://github.com/your-org/flutter_video_call_kit
issue_tracker: https://github.com/your-org/flutter_video_call_kit/issues

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.10.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  jitsi_meet_flutter_sdk: ^10.2.0
  audioplayers: ^6.1.0
  permission_handler: ^11.3.1
  uuid: ^4.0.0
  http: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  bloc_test: ^9.1.4
  mocktail: ^1.0.0
  flutter_lints: ^3.0.0

flutter:
  plugin:
    platforms:
      android:
        package: com.example.flutter_video_call_kit
        pluginClass: FlutterVideoCallKitPlugin
      ios:
        pluginClass: FlutterVideoCallKitPlugin
      web:
        pluginClass: FlutterVideoCallKitWeb
        fileName: flutter_video_call_kit_web.dart
```

### 2. Write Documentation

```markdown
# README.md

# Flutter Video Call Kit

A comprehensive Flutter plugin for implementing video/audio calling with customizable UI and support for multiple WebRTC backends.

## Features

- 🎥 **Video & Audio Calls** - Support for both video and audio-only calls
- 🔌 **Multiple Backends** - Works with Jitsi, Twilio, Agora, or custom backends
- 🎨 **Fully Customizable** - Theme and customize all UI components
- 📱 **Cross-Platform** - Android, iOS, and Web support
- 🔔 **Native Notifications** - Full-screen incoming call notifications
- 🎯 **Type Safe** - Full type safety with null-safety support
- 🧪 **Well Tested** - Comprehensive test coverage
- 📚 **Well Documented** - Extensive documentation and examples

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_video_call_kit: ^1.0.0
```

## Quick Start

```dart
import 'package:flutter_video_call_kit/flutter_video_call_kit.dart';

// Initialize
final callKit = CallKitService(
  adapter: JitsiCallAdapter(serverUrl: 'https://meet.jit.si'),
  config: CallKitConfiguration(
    appName: 'MyApp',
    currentUser: CallParticipant(
      id: 'user-123',
      displayName: 'John Doe',
    ),
  ),
);

await callKit.initialize();

// Start a call
final session = await callKit.startCall(
  recipient: CallParticipant(
    id: 'user-456',
    displayName: 'Jane Smith',
  ),
  type: CallType.video,
);
```

## Documentation

- [Getting Started Guide](docs/getting-started.md)
- [API Reference](docs/api-reference.md)
- [Custom Backend Integration](docs/custom-backend.md)
- [Theming Guide](docs/theming.md)
- [Platform Setup](docs/platform-setup.md)

## Examples

See the [example](example/) directory for complete examples:
- Basic usage
- Custom theme
- Custom backend adapter
- Advanced features

## License

MIT License - see [LICENSE](LICENSE) file
```

### 3. Publish to pub.dev

```bash
# Run checks
flutter pub publish --dry-run

# Publish
flutter pub publish
```

---

## Migration Roadmap

### Phase 1: Extract Core (2 weeks)

**Week 1: Setup**
1. Create plugin structure
2. Define API contracts
3. Implement models
4. Setup testing infrastructure

**Week 2: Core Logic**
1. Implement adapters
2. Implement BLoC
3. Write unit tests
4. Document API

### Phase 2: UI Components (2 weeks)

**Week 1: Screens**
1. Extract CallWakeUpScreen
2. Extract CallDialingScreen
3. Extract ActiveCallScreen
4. Add theming support

**Week 2: Widgets**
1. Extract reusable widgets
2. Add customization options
3. Write widget tests
4. Create example app

### Phase 3: Platform Integration (2 weeks)

**Week 1: Android**
1. Extract notification code
2. Implement platform channel
3. Test on Android devices

**Week 2: iOS**
1. Extract CallKit code
2. Implement platform channel
3. Test on iOS devices

### Phase 4: Documentation & Publishing (1 week)

1. Write comprehensive README
2. Create API documentation
3. Add more examples
4. Publish to pub.dev

### Phase 5: Zulip Integration (1 week)

1. Create ZulipCallAdapter
2. Integrate plugin into Zulip app
3. Test end-to-end
4. Remove old call code from Zulip

**Total Timeline: 8 weeks**

---

## Best Practices

### 1. Dependency Injection

```dart
// Use dependency injection for testability
class CallKitService {
  CallKitService({
    required CallBackendAdapter adapter,
    CallBloc? callBloc, // Allow injection for testing
    NotificationService? notificationService,
    PermissionService? permissionService,
  });
}
```

### 2. Error Handling

```dart
// Define custom exceptions
class CallException implements Exception {
  const CallException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final dynamic details;

  @override
  String toString() => 'CallException: $message ${code != null ? '($code)' : ''}';
}

// Use specific error types
class CallPermissionDeniedException extends CallException {
  const CallPermissionDeniedException(String permission)
    : super('Permission denied: $permission', code: 'PERMISSION_DENIED');
}

class CallNetworkException extends CallException {
  const CallNetworkException()
    : super('Network error', code: 'NETWORK_ERROR');
}
```

### 3. Versioning

```dart
// Add version info to plugin
class CallKitVersion {
  static const String version = '1.0.0';
  static const int apiVersion = 1;
}

// Check API version in adapter
abstract class CallBackendAdapter {
  int get apiVersion => 1;

  bool isCompatible() => apiVersion == CallKitVersion.apiVersion;
}
```

### 4. Logging

```dart
// Add logging support
class CallLogger {
  static final _logger = Logger('CallKit');

  static void debug(String message) => _logger.fine(message);
  static void info(String message) => _logger.info(message);
  static void warning(String message) => _logger.warning(message);
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.severe(message, error, stackTrace);
  }
}
```

### 5. Analytics

```dart
// Add analytics hooks
typedef AnalyticsCallback = void Function(String event, Map<String, dynamic> params);

class CallKitConfiguration {
  const CallKitConfiguration({
    // ...
    this.onAnalyticsEvent,
  });

  final AnalyticsCallback? onAnalyticsEvent;
}

// Use in service
void _logAnalytics(String event, Map<String, dynamic> params) {
  _config.onAnalyticsEvent?.call(event, params);
}
```

---

## Conclusion

Creating `flutter_video_call_kit` as a standalone plugin provides:

### Benefits for Zulip
- **Cleaner architecture** - Separation of concerns
- **Easier maintenance** - Isolated feature development
- **Better testing** - Independent test suite
- **Reusability** - Use in other projects

### Benefits for Community
- **Save development time** - Don't build from scratch
- **Production-tested** - Battle-tested in Zulip
- **Open source** - Free to use and extend
- **Well-documented** - Easy to integrate

### Next Steps
1. Review and approve plugin design
2. Start Phase 1: Extract core functionality
3. Build example app alongside development
4. Test with real backends (Jitsi, Twilio)
5. Publish beta version for community feedback
6. Integrate back into Zulip
7. Publish stable v1.0.0

---

**Document Version:** 1.0
**Created:** 2025-10-14
**Author:** Claude Code Analysis
**Status:** Design Proposal
