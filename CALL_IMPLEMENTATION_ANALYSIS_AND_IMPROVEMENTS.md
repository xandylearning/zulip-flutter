# Call Implementation Analysis and Recommended Improvements

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current Implementation Analysis](#current-implementation-analysis)
3. [Identified Drawbacks and Issues](#identified-drawbacks-and-issues)
4. [Recommended Solutions](#recommended-solutions)
5. [BLoC Pattern Implementation](#bloc-pattern-implementation)
6. [Riverpod Pattern Implementation](#riverpod-pattern-implementation)
7. [Migration Roadmap](#migration-roadmap)
8. [Testing Strategy](#testing-strategy)
9. [Best Practices and Guidelines](#best-practices-and-guidelines)

---

## Executive Summary

### Current State
The call feature implementation (commit `5b88d3a6`) uses a **ChangeNotifier-based state management** pattern integrated directly into the existing `PerAccountStore` architecture. While functional, this approach has several architectural and maintainability issues.

### Key Problems
- **Tight coupling** between UI and business logic
- **Manual listener management** prone to memory leaks
- **State synchronization issues** across multiple sources (WebSocket, API, local)
- **Difficult to test** due to coupling with Flutter framework
- **Race conditions** in state updates
- **Scalability concerns** as call features grow

### Recommended Solution
Migrate to **BLoC (Business Logic Component) pattern** using the `flutter_bloc` package, which provides:
- Clear separation of concerns
- Reactive state management
- Built-in testing utilities
- Better error handling
- Reduced boilerplate compared to manual ChangeNotifier

**Alternative**: Riverpod for simpler architecture with less boilerplate.

---

## Current Implementation Analysis

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     PerAccountStore                          │
│  (Main state container - ChangeNotifier)                    │
│  ┌────────────────────────────────────────────────────┐    │
│  │              CallStore                              │    │
│  │  (Call-specific state - ChangeNotifier)            │    │
│  │  - activeCall: Call?                               │    │
│  │  - callHistory: List<Call>                         │    │
│  │  - pendingOutgoingCalls: Map<String, Call>         │    │
│  │  - StreamControllers (3)                           │    │
│  │  - Manual Timers                                   │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↓                                   │
│                   notifyListeners()                          │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────┐    │
│  │           WebSocket Event Handling                  │    │
│  │  handleCallCreatedEvent()                          │    │
│  │  handleCallAcknowledgedEvent()                     │    │
│  │  handleCallAcceptedEvent()                         │    │
│  │  handleCallDeclinedEvent()                         │    │
│  │  handleCallEndedEvent()                            │    │
│  │  handleCallCancelledEvent()                        │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                    UI Layer (Widgets)                        │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │CallWakeUpScreen│  │JitsiCallScreen │  │CallsPageBody │  │
│  │- Manual addL.. │  │- Manual addL.. │  │- Manual addL.│  │
│  │- Direct API .. │  │- Direct API .. │  │- setState()  │  │
│  │- Timer mgmt    │  │- Timer mgmt    │  │              │  │
│  └────────────────┘  └────────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Current State Management Pattern

#### CallStore Implementation (`lib/model/call_store.dart`)

```dart
class CallStore extends PerAccountStoreBase with ChangeNotifier {
  // State fields
  Call? _activeCall;
  final List<Call> _callHistory = [];
  final Map<String, Call> _pendingOutgoingCalls = {};

  // StreamControllers for different aspects
  late final StreamController<List<Call>> _callHistoryController;
  late final StreamController<Call> _incomingCallController;
  late final StreamController<bool> _hasActiveCallController;

  // Timers for timeout management
  final Map<String, Timer> _callTimeoutTimers = {};

  // Manual notification method
  void _notifyCallStateChange() {
    notifyListeners();
    _hasActiveCallController.add(hasActiveCall);
  }
}
```

**Issues Identified:**
1. **Mixed responsibilities**: State management + business logic + event handling
2. **Three different notification mechanisms**: ChangeNotifier, Streams, and getters
3. **Manual resource management**: StreamControllers, Timers need manual cleanup
4. **No state immutability**: Mutable state can cause bugs

#### UI Layer Implementation

```dart
class _CallWakeUpScreenState extends State<CallWakeUpScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = PerAccountStoreWidget.of(context);
      store.callStore.addListener(_onCallStateChanged); // Manual listener
    });
  }

  void _onCallStateChanged() {
    // Manual state checking
    final store = PerAccountStoreWidget.of(context);
    final currentCall = store.callStore.getCall(widget.call.callId);
    if (currentCall == null || currentCall.status == CallStatus.ended) {
      if (mounted) _closeScreenSafely();
    }
  }

  @override
  void dispose() {
    // Manual cleanup - easy to forget!
    store.callStore.removeListener(_onCallStateChanged);
    super.dispose();
  }
}
```

**Issues Identified:**
1. **Manual listener management**: Easy to create memory leaks
2. **Context access in callbacks**: Can cause crashes if widget unmounted
3. **No type safety**: Generic `notifyListeners()` doesn't specify what changed
4. **Difficult to test**: Tightly coupled to Flutter widgets

---

## Identified Drawbacks and Issues

### 1. State Management Issues

#### 1.1 Manual Listener Management
**Problem:**
```dart
// In CallWakeUpScreen
void initState() {
  store.callStore.addListener(_onCallStateChanged);
}

void dispose() {
  store.callStore.removeListener(_onCallStateChanged); // Must remember!
}
```

**Drawbacks:**
- Memory leaks if `removeListener` is forgotten
- No compile-time guarantees
- Boilerplate in every widget
- Error-prone in complex widget trees

#### 1.2 Mixed Notification Mechanisms
**Problem:** CallStore uses 3 different ways to notify changes:
1. `ChangeNotifier.notifyListeners()` - global notification
2. `StreamController.add()` - specific data streams
3. Direct getters - no notifications

**Drawbacks:**
- Confusing API surface
- Over-notification (widgets rebuild unnecessarily)
- Under-notification (missed updates)
- Difficult to track data flow

#### 1.3 Mutable State
**Problem:**
```dart
Call? _activeCall; // Can be modified anywhere
final List<Call> _callHistory = []; // Mutable list
final Map<String, Call> _pendingOutgoingCalls = {}; // Mutable map
```

**Drawbacks:**
- State can be modified from multiple places
- Race conditions in async operations
- Difficult to debug state changes
- No time-travel debugging

### 2. Tight Coupling Issues

#### 2.1 UI-Business Logic Coupling
**Problem:**
```dart
// In CallWakeUpScreen - business logic mixed with UI
Future<void> _acknowledgeCall() async {
  try {
    await acknowledgeCall(store.connection, callId: widget.call.callId);
  } catch (e) {
    // Error handling in UI layer
  }
}

void _acceptCall() async {
  await acceptCall(store.connection, callId: widget.call.callId);
  // Navigation logic mixed with call logic
  await Navigator.of(context).pushReplacement(...);
}
```

**Drawbacks:**
- Cannot test business logic without Flutter
- Difficult to reuse logic across screens
- Navigation mixed with business logic
- Hard to mock for testing

#### 2.2 Direct API Access from UI
**Problem:**
```dart
// UI directly calls API methods
final response = await api.createCall(store.connection, ...);
await api.acknowledgeCall(store.connection, ...);
await api.acceptCall(store.connection, ...);
```

**Drawbacks:**
- API logic scattered across UI
- No centralized error handling
- Difficult to add retry logic
- Cannot intercept/log API calls easily

### 3. State Synchronization Issues

#### 3.1 Multiple Sources of Truth
**Problem:** Call state comes from 3 sources:
1. **WebSocket events** → `handleCallCreatedEvent()`
2. **API responses** → Direct in UI
3. **Local state** → `addPendingOutgoingCall()`

**Drawbacks:**
```dart
// Race condition example:
// 1. UI creates call via API
final response = await api.createCall(...);

// 2. Manually add to pending
store.callStore.addPendingOutgoingCall(call);

// 3. WebSocket event arrives (might be earlier or later!)
// handleCallCreatedEvent() - might create duplicate or conflict
```

#### 3.2 Event Ordering Issues
**Problem:**
```dart
void handleCallAcceptedEvent(CallAcceptedEvent event) {
  if (_activeCall?.callId == event.callId) {
    // Update existing
  } else if (_pendingOutgoingCalls.containsKey(event.callId)) {
    // Move from pending to active
  }
}
```

**Drawbacks:**
- Events can arrive out of order
- No event queue or buffering
- Missed events cause state inconsistency
- No way to replay events

### 4. Resource Management Issues

#### 4.1 Manual Timer Management
**Problem:**
```dart
final Map<String, Timer> _callTimeoutTimers = {};

void _startCallTimeout(String callId) {
  _callTimeoutTimers[callId] = Timer(...);
}

void _cancelCallTimeout(String callId) {
  _callTimeoutTimers[callId]?.cancel(); // Must remember to call!
  _callTimeoutTimers.remove(callId);
}
```

**Drawbacks:**
- Timers can leak if not cancelled
- No automatic cleanup
- Complex state with multiple timers
- Hard to test timeout logic

#### 4.2 StreamController Lifecycle
**Problem:**
```dart
late final StreamController<List<Call>> _callHistoryController;
late final StreamController<Call> _incomingCallController;
late final StreamController<bool> _hasActiveCallController;

@override
void dispose() {
  _callHistoryController.close(); // Must remember all 3!
  _incomingCallController.close();
  _hasActiveCallController.close();
  super.dispose();
}
```

**Drawbacks:**
- Memory leaks if not closed
- Streams can emit after disposal
- Complex cleanup logic
- No compile-time guarantees

### 5. Testing Difficulties

#### 5.1 Tight Widget Coupling
**Problem:** Cannot test business logic without Flutter TestWidgets:
```dart
testWidgets('accept call works', (tester) async {
  await tester.pumpWidget(
    MaterialApp(home: CallWakeUpScreen(call: testCall))
  );
  await tester.tap(find.byIcon(Icons.call));
  await tester.pump();
  // Complex setup just to test call acceptance logic
});
```

**Drawbacks:**
- Slow tests (requires widget pump)
- Difficult to test edge cases
- Cannot unit test business logic
- Mock complexity

#### 5.2 No State History
**Problem:**
```dart
// Cannot test state transitions
expect(callStore.activeCall?.status, CallStatus.accepted);
// But how did we get here? What was the previous state?
```

**Drawbacks:**
- Cannot verify state transitions
- No time-travel debugging
- Hard to reproduce bugs
- No audit trail

### 6. Scalability Concerns

#### 6.1 Growing Complexity
**Current CallStore:** ~580 lines with basic features
- Adding features increases complexity exponentially
- No clear separation of concerns
- Difficult to understand data flow

#### 6.2 Code Duplication
**Problem:** Similar patterns repeated in UI:
```dart
// CallWakeUpScreen
store.callStore.addListener(_onCallStateChanged);

// JitsiCallScreen
store.callStore.addListener(_callStoreListener!);

// CallsPageBody
_store!.callStore.addListener(_onCallStoreChange);
```

---

## Recommended Solutions

### Solution Comparison Matrix

| Aspect | Current (ChangeNotifier) | BLoC Pattern | Riverpod |
|--------|-------------------------|--------------|----------|
| **Boilerplate** | Medium | Medium-High | Low |
| **Type Safety** | Low | High | High |
| **Testability** | Low | High | High |
| **Learning Curve** | Low | Medium | Low-Medium |
| **Error Handling** | Manual | Built-in | Built-in |
| **Async Support** | Manual Futures | Built-in Streams | Built-in Futures |
| **State Immutability** | No | Yes | Yes |
| **Developer Tools** | Basic | Excellent | Excellent |
| **Community Support** | Large | Large | Growing |
| **Integration Effort** | N/A | Medium | Low |

### Recommendation: BLoC Pattern

**Why BLoC?**
1. **Industry standard** for Flutter state management
2. **Clear separation** between UI and business logic
3. **Built-in testing support** without Flutter dependencies
4. **Excellent developer tools** (time-travel debugging, state inspection)
5. **Proven at scale** (used by Google in production apps)
6. **Reactive by design** (perfect for real-time call events)

**Why not just Riverpod?**
- BLoC provides more structure for complex state machines (call lifecycle)
- Better for event-driven architectures (WebSocket events)
- Explicit state transitions are valuable for call flows
- More established for large teams

---

## BLoC Pattern Implementation

### Architecture with BLoC

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  (Widgets - Presentation Only)                              │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │CallWakeUpScreen│  │JitsiCallScreen │  │CallsPageBody │  │
│  │- BlocBuilder   │  │- BlocListener  │  │- BlocBuilder │  │
│  │- BlocConsumer  │  │- BlocConsumer  │  │              │  │
│  └────────────────┘  └────────────────┘  └──────────────┘  │
│              ↓                  ↓                ↓           │
│         BlocProvider      BlocProvider     BlocProvider      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                     BLoC Layer                               │
│  (Business Logic - No UI Dependencies)                      │
│  ┌────────────────────────────────────────────────────┐    │
│  │                   CallBloc                          │    │
│  │  Events:                      States:               │    │
│  │  - CallStarted               - CallInitial          │    │
│  │  - CallCreated               - CallCreating         │    │
│  │  - CallAcknowledged          - CallRinging          │    │
│  │  - CallAccepted              - CallAccepted         │    │
│  │  - CallDeclined              - CallEnded            │    │
│  │  - CallEnded                 - CallError            │    │
│  └────────────────────────────────────────────────────┘    │
│                          ↓                                   │
│                   Emit State Changes                         │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                   Repository Layer                           │
│  (Data Sources - API, WebSocket, Local)                    │
│  ┌────────────────────────────────────────────────────┐    │
│  │              CallRepository                         │    │
│  │  - createCall()                                     │    │
│  │  - acknowledgeCall()                                │    │
│  │  - acceptCall()                                     │    │
│  │  - declineCall()                                    │    │
│  │  - endCall()                                        │    │
│  │  - watchCallEvents() → Stream<CallEvent>           │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 1. Define Events (User Actions)

```dart
// lib/model/call_bloc/call_event.dart

abstract class CallEvent {
  const CallEvent();
}

/// User wants to start a call
class CallStarted extends CallEvent {
  const CallStarted({
    required this.recipientUserId,
    required this.callType,
  });

  final int recipientUserId;
  final CallType callType;
}

/// Call created on server (from API or WebSocket)
class CallCreated extends CallEvent {
  const CallCreated({required this.call});
  final Call call;
}

/// Call acknowledged by recipient
class CallAcknowledged extends CallEvent {
  const CallAcknowledged({required this.callId});
  final String callId;
}

/// User accepts incoming call
class CallAccepted extends CallEvent {
  const CallAccepted({required this.callId});
  final String callId;
}

/// User declines incoming call
class CallDeclined extends CallEvent {
  const CallDeclined({required this.callId});
  final String callId;
}

/// Call ended
class CallEnded extends CallEvent {
  const CallEnded({
    required this.callId,
    this.duration,
  });
  final String callId;
  final int? duration;
}

/// Call cancelled by caller
class CallCancelled extends CallEvent {
  const CallCancelled({required this.callId});
  final String callId;
}

/// Server event received
class CallServerEventReceived extends CallEvent {
  const CallServerEventReceived({required this.event});
  final dynamic event; // CallCreatedEvent, CallAcceptedEvent, etc.
}
```

### 2. Define States (UI Representation)

```dart
// lib/model/call_bloc/call_state.dart

abstract class CallState {
  const CallState();
}

/// Initial state - no active call
class CallInitial extends CallState {
  const CallInitial();
}

/// Creating a call (API request in progress)
class CallCreating extends CallState {
  const CallCreating({
    required this.recipientUserId,
    required this.callType,
  });

  final int recipientUserId;
  final CallType callType;
}

/// Call is ringing (waiting for answer)
class CallRinging extends CallState {
  const CallRinging({required this.call});
  final Call call;
}

/// Call accepted, connecting to Jitsi
class CallConnecting extends CallState {
  const CallConnecting({required this.call});
  final Call call;
}

/// Call is active (in Jitsi meeting)
class CallActive extends CallState {
  const CallActive({
    required this.call,
    required this.startTime,
  });

  final Call call;
  final DateTime startTime;
}

/// Call ended successfully
class CallEnded extends CallState {
  const CallEnded({
    required this.call,
    this.duration,
  });

  final Call call;
  final int? duration;
}

/// Call declined by recipient
class CallDeclinedState extends CallState {
  const CallDeclinedState({required this.call});
  final Call call;
}

/// Call cancelled by caller
class CallCancelledState extends CallState {
  const CallCancelledState({required this.call});
  final Call call;
}

/// Error occurred
class CallError extends CallState {
  const CallError({
    required this.message,
    this.error,
    this.stackTrace,
  });

  final String message;
  final Object? error;
  final StackTrace? stackTrace;
}
```

### 3. Implement Repository Layer

```dart
// lib/model/call_bloc/call_repository.dart

class CallRepository {
  CallRepository({
    required this.connection,
    required this.callStore,
  });

  final ApiConnection connection;
  final CallStore callStore; // Still use existing store for now

  /// Create a new call
  Future<Call> createCall({
    required int recipientUserId,
    required CallType callType,
  }) async {
    final response = await api.createCall(
      connection,
      userId: recipientUserId,
      isVideoCall: callType == CallType.video,
    );

    return Call(
      callId: response.callId,
      callerId: connection.userId, // Assume we have this
      recipientId: recipientUserId,
      callType: callType,
      status: CallStatus.created,
      jitsiUrl: response.callUrl,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Acknowledge an incoming call
  Future<void> acknowledgeCall(String callId) async {
    await api.acknowledgeCall(connection, callId: callId);
  }

  /// Accept a call
  Future<void> acceptCall(String callId) async {
    await api.acceptCall(connection, callId: callId);
  }

  /// Decline a call
  Future<void> declineCall(String callId) async {
    await api.declineCall(connection, callId: callId);
  }

  /// End a call
  Future<void> endCall(String callId, {int? duration}) async {
    await api.endCall(connection, callId: callId, duration: duration);
  }

  /// Cancel a call
  Future<void> cancelCall(String callId) async {
    await api.cancelCall(connection, callId: callId);
  }

  /// Watch for call events from WebSocket
  Stream<CallEvent> watchCallEvents() {
    // Convert CallStore streams to CallEvent stream
    return callStore.incomingCallStream.map(
      (call) => CallCreated(call: call),
    );
  }

  /// Get call history
  Future<List<Call>> getCallHistory() async {
    await callStore.loadCallHistory();
    return callStore.callHistory;
  }
}
```

### 4. Implement BLoC

```dart
// lib/model/call_bloc/call_bloc.dart

class CallBloc extends Bloc<CallEvent, CallState> {
  CallBloc({required this.repository}) : super(const CallInitial()) {
    // Register event handlers
    on<CallStarted>(_onCallStarted);
    on<CallCreated>(_onCallCreated);
    on<CallAcknowledged>(_onCallAcknowledged);
    on<CallAccepted>(_onCallAccepted);
    on<CallDeclined>(_onCallDeclined);
    on<CallEnded>(_onCallEnded);
    on<CallCancelled>(_onCallCancelled);
    on<CallServerEventReceived>(_onServerEventReceived);

    // Listen to WebSocket events
    _eventSubscription = repository.watchCallEvents().listen(
      (event) => add(CallServerEventReceived(event: event)),
    );
  }

  final CallRepository repository;
  StreamSubscription? _eventSubscription;

  /// Handle user starting a call
  Future<void> _onCallStarted(
    CallStarted event,
    Emitter<CallState> emit,
  ) async {
    try {
      emit(CallCreating(
        recipientUserId: event.recipientUserId,
        callType: event.callType,
      ));

      final call = await repository.createCall(
        recipientUserId: event.recipientUserId,
        callType: event.callType,
      );

      emit(CallRinging(call: call));
    } catch (error, stackTrace) {
      emit(CallError(
        message: 'Failed to create call',
        error: error,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Handle call created (from WebSocket or API response)
  Future<void> _onCallCreated(
    CallCreated event,
    Emitter<CallState> emit,
  ) async {
    // Only emit if this is an incoming call (not our outgoing call)
    if (state is! CallCreating && state is! CallRinging) {
      emit(CallRinging(call: event.call));
    }
  }

  /// Handle call acknowledged
  Future<void> _onCallAcknowledged(
    CallAcknowledged event,
    Emitter<CallState> emit,
  ) async {
    if (state is CallRinging) {
      final ringingState = state as CallRinging;
      if (ringingState.call.callId == event.callId) {
        // Update call status
        final updatedCall = ringingState.call.copyWith(
          status: CallStatus.ringing,
        );
        emit(CallRinging(call: updatedCall));
      }
    }
  }

  /// Handle user accepting call
  Future<void> _onCallAccepted(
    CallAccepted event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallRinging) return;

    final ringingState = state as CallRinging;
    if (ringingState.call.callId != event.callId) return;

    try {
      emit(CallConnecting(call: ringingState.call));

      await repository.acceptCall(event.callId);

      emit(CallActive(
        call: ringingState.call.copyWith(status: CallStatus.accepted),
        startTime: DateTime.now(),
      ));
    } catch (error, stackTrace) {
      emit(CallError(
        message: 'Failed to accept call',
        error: error,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Handle user declining call
  Future<void> _onCallDeclined(
    CallDeclined event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallRinging) return;

    final ringingState = state as CallRinging;
    if (ringingState.call.callId != event.callId) return;

    try {
      await repository.declineCall(event.callId);

      emit(CallDeclinedState(
        call: ringingState.call.copyWith(status: CallStatus.declined),
      ));

      // Return to initial state after a delay
      await Future.delayed(const Duration(seconds: 1));
      emit(const CallInitial());
    } catch (error, stackTrace) {
      emit(CallError(
        message: 'Failed to decline call',
        error: error,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Handle call ended
  Future<void> _onCallEnded(
    CallEnded event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallActive) return;

    final activeState = state as CallActive;
    if (activeState.call.callId != event.callId) return;

    try {
      await repository.endCall(event.callId, duration: event.duration);

      emit(CallEnded(
        call: activeState.call.copyWith(
          status: CallStatus.ended,
          duration: event.duration,
        ),
        duration: event.duration,
      ));

      // Return to initial state after a delay
      await Future.delayed(const Duration(seconds: 1));
      emit(const CallInitial());
    } catch (error, stackTrace) {
      emit(CallError(
        message: 'Failed to end call',
        error: error,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Handle call cancelled
  Future<void> _onCallCancelled(
    CallCancelled event,
    Emitter<CallState> emit,
  ) async {
    if (state is! CallRinging) return;

    final ringingState = state as CallRinging;
    if (ringingState.call.callId != event.callId) return;

    try {
      await repository.cancelCall(event.callId);

      emit(CallCancelledState(
        call: ringingState.call.copyWith(status: CallStatus.cancelled),
      ));

      // Return to initial state after a delay
      await Future.delayed(const Duration(seconds: 1));
      emit(const CallInitial());
    } catch (error, stackTrace) {
      emit(CallError(
        message: 'Failed to cancel call',
        error: error,
        stackTrace: stackTrace,
      ));
    }
  }

  /// Handle server events
  Future<void> _onServerEventReceived(
    CallServerEventReceived event,
    Emitter<CallState> emit,
  ) async {
    // Delegate to appropriate handler based on event type
    final serverEvent = event.event;

    if (serverEvent is CallCreatedEvent) {
      add(CallCreated(call: serverEvent.call));
    } else if (serverEvent is CallAcknowledgedEvent) {
      add(CallAcknowledged(callId: serverEvent.callId));
    } else if (serverEvent is CallAcceptedEvent) {
      // Update to active state
      if (state is CallRinging) {
        final ringingState = state as CallRinging;
        emit(CallActive(
          call: ringingState.call.copyWith(status: CallStatus.accepted),
          startTime: DateTime.now(),
        ));
      }
    } else if (serverEvent is CallDeclinedEvent) {
      add(CallDeclined(callId: serverEvent.callId));
    } else if (serverEvent is CallEndedEvent) {
      add(CallEnded(callId: serverEvent.callId, duration: serverEvent.duration));
    } else if (serverEvent is CallCancelledEvent) {
      add(CallCancelled(callId: serverEvent.callId));
    }
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    return super.close();
  }
}

// Extension for Call immutability
extension CallCopyWith on Call {
  Call copyWith({
    String? callId,
    int? callerId,
    int? recipientId,
    CallType? callType,
    CallStatus? status,
    String? jitsiUrl,
    int? timestamp,
    int? duration,
  }) {
    return Call(
      callId: callId ?? this.callId,
      callerId: callerId ?? this.callerId,
      recipientId: recipientId ?? this.recipientId,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      jitsiUrl: jitsiUrl ?? this.jitsiUrl,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
    );
  }
}
```

### 5. Update UI to Use BLoC

#### CallWakeUpScreen with BLoC

```dart
// lib/widgets/call_wakeup_screen.dart (refactored)

class CallWakeUpScreen extends StatelessWidget {
  const CallWakeUpScreen({
    super.key,
    required this.call,
  });

  final Call call;

  static Route<void> buildRoute({
    required int accountId,
    required Call call,
  }) {
    return MaterialAccountWidgetRoute(
      accountId: accountId,
      settings: const RouteSettings(name: 'CallWakeUpScreen'),
      page: BlocProvider(
        create: (context) {
          final store = PerAccountStoreWidget.of(context);
          return CallBloc(
            repository: CallRepository(
              connection: store.connection,
              callStore: store.callStore,
            ),
          );
        },
        child: CallWakeUpScreen(call: call),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallBloc, CallState>(
      // Listen for state changes that require actions
      listener: (context, state) {
        if (state is CallActive) {
          // Navigate to Jitsi screen
          Navigator.of(context).pushReplacement(
            JitsiCallScreen.buildRoute(
              accountId: PerAccountStoreWidget.accountIdOf(context),
              call: state.call,
            ),
          );
        } else if (state is CallEnded ||
                   state is CallDeclinedState ||
                   state is CallCancelledState) {
          // Close screen
          Navigator.of(context).pop();
        } else if (state is CallError) {
          // Show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      // Build UI based on state
      builder: (context, state) {
        if (state is CallError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(state.message),
                ],
              ),
            ),
          );
        }

        final store = PerAccountStoreWidget.of(context);
        final caller = store.getUser(call.callerId);
        final zulipLocalizations = ZulipLocalizations.of(context);

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (caller != null) ...[
                        Avatar(
                          userId: caller.userId,
                          size: 120,
                          borderRadius: 60,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          caller.fullName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        call.callType == CallType.video
                            ? zulipLocalizations.incomingVideoCall
                            : zulipLocalizations.incomingAudioCall,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline button
                      _CallActionButton(
                        onPressed: () {
                          context.read<CallBloc>().add(
                            CallDeclined(callId: call.callId),
                          );
                        },
                        backgroundColor: Colors.red,
                        icon: Icons.call_end,
                        label: zulipLocalizations.decline,
                      ),
                      const SizedBox(width: 48),
                      // Accept button
                      _CallActionButton(
                        onPressed: () {
                          context.read<CallBloc>().add(
                            CallAccepted(callId: call.callId),
                          );
                        },
                        backgroundColor: Colors.green,
                        icon: Icons.call,
                        label: zulipLocalizations.accept,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

**Benefits of BLoC Version:**
- ✅ No manual listener management
- ✅ No dispose logic needed
- ✅ Type-safe state handling
- ✅ Centralized business logic
- ✅ Easy to test (see below)

---

## Riverpod Pattern Implementation

### Architecture with Riverpod

```dart
// lib/model/call_providers.dart

// State class (immutable)
@freezed
class CallState with _$CallState {
  const factory CallState.initial() = CallInitial;
  const factory CallState.creating({
    required int recipientUserId,
    required CallType callType,
  }) = CallCreating;
  const factory CallState.ringing({
    required Call call,
  }) = CallRinging;
  const factory CallState.active({
    required Call call,
    required DateTime startTime,
  }) = CallActive;
  const factory CallState.ended({
    required Call call,
    int? duration,
  }) = CallEnded;
  const factory CallState.error({
    required String message,
    Object? error,
  }) = CallError;
}

// Repository provider
@riverpod
CallRepository callRepository(CallRepositoryRef ref) {
  final store = ref.watch(perAccountStoreProvider);
  return CallRepository(
    connection: store.connection,
    callStore: store.callStore,
  );
}

// Call state notifier
@riverpod
class CallNotifier extends _$CallNotifier {
  @override
  CallState build() {
    // Listen to WebSocket events
    ref.listen(callEventsProvider, (_, event) {
      _handleServerEvent(event);
    });

    return const CallState.initial();
  }

  Future<void> startCall({
    required int recipientUserId,
    required CallType callType,
  }) async {
    state = CallState.creating(
      recipientUserId: recipientUserId,
      callType: callType,
    );

    try {
      final repository = ref.read(callRepositoryProvider);
      final call = await repository.createCall(
        recipientUserId: recipientUserId,
        callType: callType,
      );

      state = CallState.ringing(call: call);
    } catch (error) {
      state = CallState.error(
        message: 'Failed to create call',
        error: error,
      );
    }
  }

  Future<void> acceptCall(String callId) async {
    final current = state;
    if (current is! CallRinging) return;

    try {
      final repository = ref.read(callRepositoryProvider);
      await repository.acceptCall(callId);

      state = CallState.active(
        call: current.call.copyWith(status: CallStatus.accepted),
        startTime: DateTime.now(),
      );
    } catch (error) {
      state = CallState.error(
        message: 'Failed to accept call',
        error: error,
      );
    }
  }

  Future<void> declineCall(String callId) async {
    final current = state;
    if (current is! CallRinging) return;

    try {
      final repository = ref.read(callRepositoryProvider);
      await repository.declineCall(callId);

      state = CallState.ended(
        call: current.call.copyWith(status: CallStatus.declined),
      );

      // Reset after delay
      await Future.delayed(const Duration(seconds: 1));
      state = const CallState.initial();
    } catch (error) {
      state = CallState.error(
        message: 'Failed to decline call',
        error: error,
      );
    }
  }

  void _handleServerEvent(dynamic event) {
    if (event is CallCreatedEvent) {
      state = CallState.ringing(call: event.call);
    } else if (event is CallAcceptedEvent) {
      final current = state;
      if (current is CallRinging) {
        state = CallState.active(
          call: current.call.copyWith(status: CallStatus.accepted),
          startTime: DateTime.now(),
        );
      }
    }
    // Handle other events...
  }
}

// Call events stream provider
@riverpod
Stream<dynamic> callEvents(CallEventsRef ref) {
  final store = ref.watch(perAccountStoreProvider);
  return store.callStore.incomingCallStream;
}
```

### UI with Riverpod

```dart
// lib/widgets/call_wakeup_screen.dart (Riverpod version)

class CallWakeUpScreen extends ConsumerWidget {
  const CallWakeUpScreen({
    super.key,
    required this.call,
  });

  final Call call;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callNotifierProvider);

    // Listen for navigation events
    ref.listen<CallState>(callNotifierProvider, (previous, next) {
      next.when(
        initial: () {},
        creating: (_, __) {},
        ringing: (_) {},
        active: (call, _) {
          Navigator.of(context).pushReplacement(
            JitsiCallScreen.buildRoute(
              accountId: PerAccountStoreWidget.accountIdOf(context),
              call: call,
            ),
          );
        },
        ended: (call, _) {
          Navigator.of(context).pop();
        },
        error: (message, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    });

    return Scaffold(
      body: SafeArea(
        child: callState.when(
          initial: () => const Center(child: Text('No call')),
          creating: (_, __) => const Center(child: CircularProgressIndicator()),
          ringing: (call) => _buildRingingUI(context, ref, call),
          active: (call, _) => const Center(child: Text('Connecting...')),
          ended: (_, __) => const Center(child: Text('Call ended')),
          error: (message, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRingingUI(BuildContext context, WidgetRef ref, Call call) {
    final store = PerAccountStoreWidget.of(context);
    final caller = store.getUser(call.callerId);

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (caller != null) ...[
                Avatar(
                  userId: caller.userId,
                  size: 120,
                  borderRadius: 60,
                ),
                const SizedBox(height: 32),
                Text(
                  caller.fullName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(48),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CallActionButton(
                onPressed: () {
                  ref.read(callNotifierProvider.notifier).declineCall(call.callId);
                },
                backgroundColor: Colors.red,
                icon: Icons.call_end,
                label: 'Decline',
              ),
              const SizedBox(width: 48),
              _CallActionButton(
                onPressed: () {
                  ref.read(callNotifierProvider.notifier).acceptCall(call.callId);
                },
                backgroundColor: Colors.green,
                icon: Icons.call,
                label: 'Accept',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

**Benefits of Riverpod Version:**
- ✅ Less boilerplate than BLoC
- ✅ Built-in dependency injection
- ✅ Easy to compose providers
- ✅ Great for simpler state machines

---

## Migration Roadmap

### Phase 1: Preparation (1-2 weeks)

#### Week 1: Setup and Architecture
1. **Add dependencies**
   ```yaml
   # pubspec.yaml
   dependencies:
     flutter_bloc: ^8.1.3
     equatable: ^2.0.5  # For value equality

   dev_dependencies:
     bloc_test: ^9.1.4  # For testing BLoCs
   ```

2. **Create directory structure**
   ```
   lib/model/call_bloc/
   ├── call_bloc.dart
   ├── call_event.dart
   ├── call_state.dart
   ├── call_repository.dart
   └── call_history_bloc.dart (separate for history)

   test/model/call_bloc/
   ├── call_bloc_test.dart
   ├── call_repository_test.dart
   └── call_state_test.dart
   ```

3. **Document migration strategy**
   - Create this document
   - Get team buy-in
   - Plan timeline

### Phase 2: Repository Layer (1 week)

1. **Create CallRepository**
   - Extract all API calls from UI
   - Add proper error handling
   - Add logging and monitoring
   - Write unit tests

2. **Test repository thoroughly**
   ```dart
   test('createCall returns Call object', () async {
     final repository = CallRepository(
       connection: mockConnection,
       callStore: mockCallStore,
     );

     final call = await repository.createCall(
       recipientUserId: 123,
       callType: CallType.video,
     );

     expect(call.callType, CallType.video);
     expect(call.recipientId, 123);
   });
   ```

### Phase 3: BLoC Implementation (2 weeks)

#### Week 1: Core BLoC
1. **Define events and states**
   - Create `call_event.dart`
   - Create `call_state.dart`
   - Add `equatable` for comparison

2. **Implement CallBloc**
   - Create `call_bloc.dart`
   - Implement event handlers
   - Add WebSocket integration
   - Write comprehensive tests

#### Week 2: Integration
1. **Connect to existing CallStore**
   - Bridge pattern: BLoC wraps CallStore
   - Gradually migrate functionality
   - Keep both working in parallel

2. **Test integration**
   ```dart
   blocTest<CallBloc, CallState>(
     'emits CallRinging when call created',
     build: () => CallBloc(repository: mockRepository),
     act: (bloc) => bloc.add(CallStarted(
       recipientUserId: 123,
       callType: CallType.video,
     )),
     expect: () => [
       CallCreating(recipientUserId: 123, callType: CallType.video),
       isA<CallRinging>(),
     ],
   );
   ```

### Phase 4: UI Migration (2-3 weeks)

#### Week 1: CallWakeUpScreen
1. **Migrate to BlocConsumer**
   - Remove manual listeners
   - Use BlocBuilder for UI
   - Use BlocListener for navigation
   - Test thoroughly

2. **A/B testing**
   - Feature flag for new implementation
   - Test with subset of users
   - Monitor for issues

#### Week 2: JitsiCallScreen
1. **Migrate to BLoC**
   - Similar pattern to CallWakeUpScreen
   - Handle active call state
   - Integrate heartbeat with BLoC

#### Week 3: CallsPageBody
1. **Create CallHistoryBloc** (separate)
   - Handle history loading
   - Handle pagination
   - Handle refresh

2. **Update UI**
   - Use BlocBuilder
   - Handle loading states
   - Handle error states

### Phase 5: Cleanup and Optimization (1 week)

1. **Remove old code**
   - Remove manual listeners from CallStore
   - Remove StreamControllers (use BLoC streams)
   - Remove timer management (use BLoC)

2. **Performance optimization**
   - Profile rebuild performance
   - Optimize state emissions
   - Add caching where needed

3. **Documentation**
   - Update architecture docs
   - Create developer guide
   - Document state transitions

### Phase 6: Testing and Rollout (1 week)

1. **Comprehensive testing**
   - Unit tests (95%+ coverage)
   - Widget tests
   - Integration tests
   - Manual testing

2. **Gradual rollout**
   - Internal testing
   - Beta testing
   - Production rollout (with monitoring)

### Total Timeline: 8-10 weeks

---

## Testing Strategy

### Unit Testing with BLoC

```dart
// test/model/call_bloc/call_bloc_test.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCallRepository extends Mock implements CallRepository {}

void main() {
  group('CallBloc', () {
    late CallRepository repository;

    setUp(() {
      repository = MockCallRepository();
    });

    test('initial state is CallInitial', () {
      final bloc = CallBloc(repository: repository);
      expect(bloc.state, equals(const CallInitial()));
    });

    blocTest<CallBloc, CallState>(
      'emits [CallCreating, CallRinging] when CallStarted is added',
      build: () {
        when(() => repository.createCall(
          recipientUserId: any(named: 'recipientUserId'),
          callType: any(named: 'callType'),
        )).thenAnswer((_) async => Call(
          callId: 'test-call-id',
          callerId: 1,
          recipientId: 2,
          callType: CallType.video,
          status: CallStatus.created,
          jitsiUrl: 'https://meet.jit.si/test',
          timestamp: 12345,
        ));

        return CallBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const CallStarted(
        recipientUserId: 2,
        callType: CallType.video,
      )),
      expect: () => [
        const CallCreating(
          recipientUserId: 2,
          callType: CallType.video,
        ),
        isA<CallRinging>()
          .having((s) => s.call.callId, 'callId', 'test-call-id')
          .having((s) => s.call.callType, 'callType', CallType.video),
      ],
      verify: (_) {
        verify(() => repository.createCall(
          recipientUserId: 2,
          callType: CallType.video,
        )).called(1);
      },
    );

    blocTest<CallBloc, CallState>(
      'emits [CallCreating, CallError] when createCall fails',
      build: () {
        when(() => repository.createCall(
          recipientUserId: any(named: 'recipientUserId'),
          callType: any(named: 'callType'),
        )).thenThrow(Exception('Network error'));

        return CallBloc(repository: repository);
      },
      act: (bloc) => bloc.add(const CallStarted(
        recipientUserId: 2,
        callType: CallType.video,
      )),
      expect: () => [
        const CallCreating(
          recipientUserId: 2,
          callType: CallType.video,
        ),
        isA<CallError>()
          .having((s) => s.message, 'message', contains('Failed to create')),
      ],
    );

    blocTest<CallBloc, CallState>(
      'emits [CallConnecting, CallActive] when CallAccepted is added',
      build: () {
        when(() => repository.acceptCall(any()))
          .thenAnswer((_) async => {});

        return CallBloc(repository: repository);
      },
      seed: () => CallRinging(
        call: Call(
          callId: 'test-call-id',
          callerId: 2,
          recipientId: 1,
          callType: CallType.audio,
          status: CallStatus.ringing,
          jitsiUrl: 'https://meet.jit.si/test',
          timestamp: 12345,
        ),
      ),
      act: (bloc) => bloc.add(const CallAccepted(callId: 'test-call-id')),
      expect: () => [
        isA<CallConnecting>(),
        isA<CallActive>()
          .having((s) => s.call.status, 'status', CallStatus.accepted),
      ],
    );

    blocTest<CallBloc, CallState>(
      'transitions from CallRinging to CallDeclined when declined',
      build: () {
        when(() => repository.declineCall(any()))
          .thenAnswer((_) async => {});

        return CallBloc(repository: repository);
      },
      seed: () => CallRinging(
        call: Call(
          callId: 'test-call-id',
          callerId: 2,
          recipientId: 1,
          callType: CallType.audio,
          status: CallStatus.ringing,
          jitsiUrl: 'https://meet.jit.si/test',
          timestamp: 12345,
        ),
      ),
      act: (bloc) => bloc.add(const CallDeclined(callId: 'test-call-id')),
      expect: () => [
        isA<CallDeclinedState>()
          .having((s) => s.call.status, 'status', CallStatus.declined),
        const CallInitial(), // After delay
      ],
      wait: const Duration(seconds: 2), // Wait for auto-reset
    );
  });
}
```

### Widget Testing with BLoC

```dart
// test/widgets/call_wakeup_screen_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';

class MockCallBloc extends MockBloc<CallEvent, CallState> implements CallBloc {}

void main() {
  group('CallWakeUpScreen', () {
    late CallBloc callBloc;

    setUp(() {
      callBloc = MockCallBloc();
    });

    testWidgets('displays caller info when in ringing state', (tester) async {
      final call = Call(
        callId: 'test-id',
        callerId: 123,
        recipientId: 456,
        callType: CallType.video,
        status: CallStatus.ringing,
        jitsiUrl: 'https://meet.jit.si/test',
        timestamp: 12345,
      );

      when(() => callBloc.state).thenReturn(CallRinging(call: call));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: callBloc,
            child: CallWakeUpScreen(call: call),
          ),
        ),
      );

      expect(find.text('Incoming video call'), findsOneWidget);
      expect(find.byIcon(Icons.call), findsOneWidget);
      expect(find.byIcon(Icons.call_end), findsOneWidget);
    });

    testWidgets('accept button triggers CallAccepted event', (tester) async {
      final call = Call(
        callId: 'test-id',
        callerId: 123,
        recipientId: 456,
        callType: CallType.video,
        status: CallStatus.ringing,
        jitsiUrl: 'https://meet.jit.si/test',
        timestamp: 12345,
      );

      when(() => callBloc.state).thenReturn(CallRinging(call: call));
      when(() => callBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: callBloc,
            child: CallWakeUpScreen(call: call),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.call));
      await tester.pump();

      verify(() => callBloc.add(CallAccepted(callId: 'test-id'))).called(1);
    });

    testWidgets('navigates to Jitsi screen when call accepted', (tester) async {
      final call = Call(
        callId: 'test-id',
        callerId: 123,
        recipientId: 456,
        callType: CallType.video,
        status: CallStatus.ringing,
        jitsiUrl: 'https://meet.jit.si/test',
        timestamp: 12345,
      );

      whenListen(
        callBloc,
        Stream.fromIterable([
          CallRinging(call: call),
          CallActive(call: call, startTime: DateTime.now()),
        ]),
        initialState: CallRinging(call: call),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: callBloc,
            child: CallWakeUpScreen(call: call),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify navigation occurred (would need navigation observer in real test)
      expect(find.byType(JitsiCallScreen), findsOneWidget);
    });
  });
}
```

---

## Best Practices and Guidelines

### 1. State Immutability

**Always use immutable state objects:**

```dart
// ❌ BAD - Mutable state
class CallState {
  Call? activeCall;
  List<Call> history = [];
}

// ✅ GOOD - Immutable state
abstract class CallState {
  const CallState();
}

class CallRinging extends CallState {
  const CallRinging({required this.call});
  final Call call; // final = immutable
}
```

**Use `equatable` for value equality:**

```dart
abstract class CallState extends Equatable {
  const CallState();
}

class CallRinging extends CallState {
  const CallRinging({required this.call});
  final Call call;

  @override
  List<Object?> get props => [call];
}
```

### 2. Single Responsibility

**One BLoC per feature:**

```dart
// ✅ GOOD - Separate concerns
CallBloc // Handles active call
CallHistoryBloc // Handles call history
CallSettingsBloc // Handles call settings

// ❌ BAD - God BLoC
CallBloc // Handles everything
```

### 3. Error Handling

**Always handle errors explicitly:**

```dart
Future<void> _onCallStarted(
  CallStarted event,
  Emitter<CallState> emit,
) async {
  try {
    emit(const CallCreating());
    final call = await repository.createCall(...);
    emit(CallRinging(call: call));
  } on NetworkException catch (e) {
    emit(CallError(message: 'Network error', error: e));
  } on ApiException catch (e) {
    emit(CallError(message: 'Server error', error: e));
  } catch (e, stackTrace) {
    emit(CallError(
      message: 'Unexpected error',
      error: e,
      stackTrace: stackTrace,
    ));
  }
}
```

### 4. Use BlocObserver for Logging

```dart
// lib/model/call_bloc/call_bloc_observer.dart

class CallBlocObserver extends BlocObserver {
  @override
  void onEvent(Bloc bloc, Object? event) {
    super.onEvent(bloc, event);
    debugPrint('CallBloc event: $event');
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    debugPrint('CallBloc transition: ${transition.currentState} → ${transition.nextState}');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    debugPrint('CallBloc error: $error\n$stackTrace');
    // Send to crash reporting
  }
}

// In main.dart
void main() {
  Bloc.observer = CallBlocObserver();
  runApp(MyApp());
}
```

### 5. Testing Best Practices

**Test state transitions, not implementation:**

```dart
// ✅ GOOD - Test behavior
blocTest<CallBloc, CallState>(
  'creates call when CallStarted is added',
  build: () => CallBloc(repository: mockRepository),
  act: (bloc) => bloc.add(CallStarted(...)),
  expect: () => [
    isA<CallCreating>(),
    isA<CallRinging>(),
  ],
);

// ❌ BAD - Test implementation details
test('createCall is called', () {
  // Don't test internal method calls
});
```

### 6. UI Guidelines

**Use BlocBuilder for UI updates:**

```dart
BlocBuilder<CallBloc, CallState>(
  builder: (context, state) {
    return state.when(
      initial: () => Text('No call'),
      ringing: (call) => CallRingingUI(call: call),
      active: (call, _) => CallActiveUI(call: call),
    );
  },
)
```

**Use BlocListener for side effects:**

```dart
BlocListener<CallBloc, CallState>(
  listener: (context, state) {
    if (state is CallActive) {
      Navigator.push(...); // Navigation
    } else if (state is CallError) {
      ScaffoldMessenger.of(context).showSnackBar(...); // Show error
    }
  },
  child: MyWidget(),
)
```

**Use BlocConsumer when you need both:**

```dart
BlocConsumer<CallBloc, CallState>(
  listener: (context, state) {
    // Handle side effects
  },
  builder: (context, state) {
    // Build UI
  },
)
```

---

## Conclusion

### Summary of Benefits

Moving from **ChangeNotifier** to **BLoC pattern** provides:

1. **Better Architecture**
   - Clear separation of concerns
   - Easier to understand data flow
   - More maintainable codebase

2. **Improved Testability**
   - Unit test business logic without Flutter
   - Mock dependencies easily
   - Test state transitions comprehensively

3. **Enhanced Developer Experience**
   - Type-safe state management
   - Excellent debugging tools
   - Clear state transitions

4. **Better Performance**
   - Reduced unnecessary rebuilds
   - More efficient state updates
   - Better resource management

5. **Scalability**
   - Easy to add new features
   - Handles complex state machines well
   - Supports team collaboration

### Next Steps

1. **Review and Approve** this document with the team
2. **Start with Phase 1** (preparation and setup)
3. **Create a test branch** for migration work
4. **Implement incrementally** following the roadmap
5. **Monitor and adjust** based on real-world usage

### Resources

- [BLoC Documentation](https://bloclibrary.dev/)
- [Flutter BLoC Package](https://pub.dev/packages/flutter_bloc)
- [BLoC Testing](https://bloclibrary.dev/#/coreconcepts?id=testing)
- [Riverpod Documentation](https://riverpod.dev/)
- [Flutter State Management Comparison](https://docs.flutter.dev/development/data-and-backend/state-mgmt/options)

---

**Document Version:** 1.0
**Created:** 2025-10-14
**Author:** Claude Code Analysis
**Status:** Draft for Review
