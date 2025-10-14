# Zulip Flutter Call Implementation Sequence Diagram

## Complete Call Flow with APIs and Server Heartbeat Events

```mermaid
sequenceDiagram
    participant User as User
    participant App as Flutter App
    participant CallStore as CallStore
    participant API as Call APIs
    participant Server as Zulip Server
    participant FCM as Firebase Cloud Messaging
    participant Jitsi as Jitsi Meet
    participant WebSocket as WebSocket Events
    participant Heartbeat as Heartbeat System

    Note over User, Heartbeat: Outgoing Call Flow

    User->>App: Click call button (audio/video)
    App->>App: Check permissions
    App->>API: POST /api/v1/calls/create
    Note right of API: {user_id, is_video_call}
    API->>Server: Create call request
    Server-->>API: CreateCallResponse
    Note left of Server: {callId, callUrl, callType, roomName, recipient}
    API-->>App: Call created successfully
    Server-->>WebSocket: call_event: initiated
    WebSocket->>CallStore: CallCreatedEvent
    CallStore->>App: Store call in pendingOutgoingCalls
    App->>App: Navigate to CallDialingScreen
    Note right of App: Call state: calling → ringing

    Note over User, Heartbeat: Incoming Call Flow (FCM Path)

    Server->>FCM: Send call notification
    Note right of FCM: {event: 'call', call_id, sender_id, call_type, jitsi_url}
    FCM->>App: Firebase message received
    App->>App: Parse CallFcmMessage
    App->>App: Create deep link URL
    Note right of App: zulip://call/{callId}?realm_url&user_id&call_type&jitsi_url&sender_id&sender_name
    App->>App: Show full-screen notification
    User->>App: Tap notification
    App->>App: Handle deep link
    App->>App: Navigate to CallWakeUpScreen
    App->>Server: GET /api/v1/calls/{callId}/status
    Server-->>App: Call status response
    App->>Server: POST /api/v1/calls/acknowledge
    Note right of Server: ONLY recipient acknowledges incoming call
    Server-->>WebSocket: call_event: acknowledged
    WebSocket->>CallStore: CallAcknowledgedEvent
    CallStore->>App: Update call state
    Note right of App: Call state: ringing → acknowledged

    Note over User, Heartbeat: Call Response Flow

    User->>App: Accept/Decline call
    App->>Server: POST /api/v1/calls/{callId}/respond
    Note right of Server: {response: 'accepted'/'declined'}
    Server-->>WebSocket: call_event: accepted/declined
    WebSocket->>CallStore: CallAcceptedEvent/CallDeclinedEvent
    CallStore->>App: Update call state
    Note right of App: Call state: acknowledged → accepted/declined

    Note over User, Heartbeat: Active Call Flow

    App->>App: Navigate to JitsiCallScreen
    App->>Jitsi: Load Jitsi Meet URL
    Note right of Jitsi: {jitsi_url with config parameters}
    Jitsi-->>App: Call connected
    Note right of App: Call state: accepted → active

    Note over User, Heartbeat: Client Heartbeat System

    loop Every 30 seconds during active call
        App->>Server: POST /api/v1/calls/heartbeat
        Note right of Server: {call_id, is_backgrounded}
        Server-->>App: Heartbeat response
        Note left of Server: Server tracks app state for call management
    end

    Note over User, Heartbeat: Network Failure Detection

    App->>App: Start 30-second heartbeat timeout
    alt Heartbeat timeout
        App->>App: Detect network failure
        App->>Server: POST /api/v1/calls/{callId}/end
        Note right of Server: Auto-end call on network failure
        Server-->>WebSocket: call_event: ended
        WebSocket->>CallStore: CallEndedEvent
        CallStore->>App: Update call state
    end

    Note over User, Heartbeat: Call End Flow

    User->>App: End call
    App->>Server: POST /api/v1/calls/{callId}/end
    Note right of Server: {duration}
    Server-->>WebSocket: call_event: ended
    WebSocket->>CallStore: CallEndedEvent
    CallStore->>App: Update call state
    App->>App: Navigate back to previous screen

    Note over User, Heartbeat: Call Cancel Flow

    User->>App: Cancel call (before answer)
    App->>Server: POST /api/v1/calls/{callId}/cancel
    Server-->>WebSocket: call_event: cancelled
    WebSocket->>CallStore: CallCancelledEvent
    CallStore->>App: Update call state
    App->>App: Navigate back to previous screen

    Note over User, Heartbeat: Call Timeout Scenarios

    Note over User, Heartbeat: 90s Call Timeout (Unanswered)
    App->>App: Start 90-second timeout timer
    App->>Server: POST /api/v1/calls/{callId}/cancel
    Note right of Server: Auto-cancel unanswered calls after 90s
    Server-->>WebSocket: call_event: timeout
    WebSocket->>CallStore: CallTimeoutEvent
    CallStore->>App: Update call state
    App->>App: Navigate back to previous screen

    Note over User, Heartbeat: 30s Network Timeout
    App->>App: Start 30-second network timeout
    alt Network failure detected
        App->>Server: POST /api/v1/calls/{callId}/end
        Note right of Server: Auto-end call on network timeout
        Server-->>WebSocket: call_event: ended
        WebSocket->>CallStore: CallEndedEvent
        CallStore->>App: Update call state
    end

    Note over User, Heartbeat: 10min Call Duration Limit
    App->>App: Start 10-minute call duration timer
    App->>Server: POST /api/v1/calls/{callId}/end
    Note right of Server: Auto-end long calls after 10 minutes
    Server-->>WebSocket: call_event: ended
    WebSocket->>CallStore: CallEndedEvent
    CallStore->>App: Update call state
    App->>App: Navigate back to previous screen

    Note over User, Heartbeat: Server Heartbeat Events

    loop Every 30 seconds
        Server->>WebSocket: heartbeat event
        WebSocket->>App: HeartbeatEvent
        App->>Heartbeat: Process heartbeat
        Note right of Heartbeat: Maintains WebSocket connection health
    end
```

## Call API Endpoints

### Core Call APIs
- `POST /api/v1/calls/create` - Create new call
- `POST /api/v1/calls/acknowledge` - Acknowledge call (caller/receiver)
- `POST /api/v1/calls/{callId}/respond` - Accept/decline call
- `POST /api/v1/calls/{callId}/cancel` - Cancel call
- `POST /api/v1/calls/{callId}/end` - End active call
- `GET /api/v1/calls/{callId}/status` - Get call status
- `POST /api/v1/calls/heartbeat` - Send heartbeat
- `POST /api/v1/calls/end-all` - End all calls
- `GET /api/v1/calls/active` - Get active calls
- `GET /api/v1/calls/history` - Get call history

### WebSocket Events
- `call_event: initiated` - New call created (caller side)
- `call_event: acknowledged` - Call acknowledged by recipient
- `call_event: accepted` - Call accepted by recipient
- `call_event: declined` - Call declined by recipient
- `call_event: ended` - Call ended normally
- `call_event: cancelled` - Call cancelled by caller
- `call_event: timeout` - Call timed out (unanswered)
- `heartbeat` - Server heartbeat (every 30 seconds)

### FCM Message Types
- `CallFcmMessage` - Incoming call notification
- `MessageFcmMessage` - Regular message notification
- `RemoveFcmMessage` - Remove notification

## Call States and Transitions

### Call Status Enum
- `created` - Call created, waiting for acknowledgment
- `ringing` - Call is ringing (acknowledged by recipient)
- `accepted` - Call accepted by receiver
- `declined` - Call declined by receiver
- `ended` - Call ended normally
- `cancelled` - Call cancelled by caller
- `timeout` - Call timed out (unanswered)

### Call State Transitions
1. **Outgoing Call**: `calling` → `ringing` → `accepted`/`declined`/`timeout`
2. **Incoming Call**: `ringing` → `acknowledged` → `accepted`/`declined`
3. **Active Call**: `accepted` → `active` (Jitsi connected)
4. **Call End**: `active` → `ended` (normal termination)
5. **Call Cancel**: `ringing` → `cancelled` (caller cancels)
6. **Call Timeout**: `ringing` → `timeout` (90s unanswered)

### Call Type Enum
- `audio` - Audio-only call
- `video` - Video call

## Key Components

### CallStore
- Manages active calls and call history
- Handles WebSocket events
- Provides call state to UI components
- Manages call timeouts

### NotificationDisplayManager
- Handles FCM messages
- Creates call notifications
- Manages deep links for incoming calls

### Call Screens
- `CallDialingScreen` - Outgoing call waiting
- `CallWakeUpScreen` - Incoming call response
- `JitsiCallScreen` - Active call interface

### Deep Link Format
```
zulip://call/{callId}?realm_url={url}&user_id={id}&call_type={type}&jitsi_url={url}&sender_id={id}&sender_name={name}
```

## Error Handling

### Common Error Scenarios
1. **FCM Parsing Errors** - Null values in FCM data
2. **Call Event Parsing** - Field mapping issues (receiver_id → user_id)
3. **Permission Denied** - Audio/video permissions
4. **Network Failures** - API request failures
5. **Call Timeouts** - Unanswered calls after 90 seconds
6. **Network Timeouts** - 30-second heartbeat timeout
7. **Call Duration Limits** - 10-minute call duration limit
8. **Invalid Call States** - API calls on wrong call state

### Recovery Mechanisms
- **90s Call Timeout** - Automatic call cancellation on unanswered calls
- **30s Network Timeout** - Auto-end calls on network failure detection
- **10min Duration Limit** - Auto-end long calls to prevent resource exhaustion
- **Heartbeat Monitoring** - Client sends heartbeats every 30 seconds during active calls
- **Graceful Error Handling** - UI handles all error states gracefully
- **Fallback Navigation** - Automatic navigation back on errors
- **Comprehensive Logging** - Debug information for all call events and errors
