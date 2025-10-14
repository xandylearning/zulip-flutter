import 'dart:developer' as developer;

import '../core.dart';
import '../model/call.dart';

/// https://zulip.com/api/calls/create (hypothetical endpoint)
Future<CreateCallResponse> createCall(ApiConnection connection, {
  required int userId,
  required bool isVideoCall,
}) {
  developer.log(
    'Creating call: userId=$userId, isVideoCall=$isVideoCall',
    name: 'CallAPI',
  );

  try {
    developer.log('Sending call creation request with userId=$userId, isVideoCall=$isVideoCall', name: 'CallAPI');

    final response = connection.post('createCall', CreateCallResponse.fromJson, 'calls/create', {
      'user_id': userId,
      'is_video_call': isVideoCall.toString(),
    });

    developer.log('Call creation initiated successfully', name: 'CallAPI');
    return response;
  } catch (e) {
    developer.log('Call creation failed: $e', name: 'CallAPI');
    developer.log('Error type: ${e.runtimeType}', name: 'CallAPI');
    if (e.toString().contains('malformed response')) {
      developer.log('Server returned malformed response - likely null body', name: 'CallAPI');
      developer.log('This suggests the /api/v1/calls/create endpoint may not be implemented on the server', name: 'CallAPI');
    }
    rethrow;
  }
}

/// https://zulip.com/api/calls/acknowledge (hypothetical endpoint)
Future<CallActionResponse> acknowledgeCall(ApiConnection connection, {
  required String callId,
}) {
  developer.log(
    'Acknowledging call: callId=$callId',
    name: 'CallAPI',
  );

  try {
    developer.log('Sending acknowledge call request for callId=$callId', name: 'CallAPI');
    developer.log('Request payload: call_id=$callId', name: 'CallAPI');

    final response = connection.post('acknowledgeCall', CallActionResponse.fromJson, 'calls/acknowledge', {
      'call_id': callId,
    });

    developer.log('Call acknowledge request sent successfully for callId=$callId', name: 'CallAPI');
    developer.log('Response received: $response', name: 'CallAPI');
    return response;
  } catch (e) {
    developer.log('Failed to acknowledge call callId=$callId: $e', name: 'CallAPI');
    developer.log('Error type: ${e.runtimeType}', name: 'CallAPI');
    developer.log('Full error details: ${e.toString()}', name: 'CallAPI');
    rethrow;
  }
}

/// https://zulip.com/api/calls/{callId}/respond (hypothetical endpoint)
Future<CallActionResponse> acceptCall(ApiConnection connection, {
  required String callId,
}) async {
  developer.log(
    'Accepting call: callId=$callId',
    name: 'CallAPI',
  );

  try {
    // Validate call state before attempting to accept
    developer.log('Validating call state before accepting callId=$callId', name: 'CallAPI');
    final isValid = await validateCallState(connection, callId: callId);

    if (!isValid) {
      developer.log('Call state validation failed for callId=$callId - call may be in invalid state', name: 'CallAPI');
      throw Exception('Cannot accept call - call is not in a valid state for accepting');
    }

    developer.log('Call state validation passed for callId=$callId', name: 'CallAPI');
    developer.log('Sending accept call request for callId=$callId', name: 'CallAPI');
    developer.log('Request URL: calls/$callId/respond', name: 'CallAPI');
    developer.log('Request payload: response=accept', name: 'CallAPI');

    final response = connection.post('acceptCall', CallActionResponse.fromJson, 'calls/$callId/respond', {
      'response': RawParameter('accept'),
    });

    developer.log('Call accept request sent successfully for callId=$callId', name: 'CallAPI');
    developer.log('Response received: $response', name: 'CallAPI');
    developer.log('Response type: ${response.runtimeType}', name: 'CallAPI');
    return response;
  } catch (e) {
    developer.log('Failed to accept call callId=$callId: $e', name: 'CallAPI');
    developer.log('Error type: ${e.runtimeType}', name: 'CallAPI');
    developer.log('Full error details: ${e.toString()}', name: 'CallAPI');

    // Log specific error details for debugging
    if (e.toString().contains('400')) {
      developer.log('HTTP 400 Bad Request detected - likely invalid call state or parameters', name: 'CallAPI');
    }
    if (e.toString().contains('network_failure')) {
      developer.log('Network failure detected - call may be in invalid state', name: 'CallAPI');
    }

    rethrow;
  }
}

/// https://zulip.com/api/calls/{callId}/respond (hypothetical endpoint)
Future<CallActionResponse> declineCall(ApiConnection connection, {
  required String callId,
}) async {
  developer.log(
    'Declining call: callId=$callId',
    name: 'CallAPI',
  );

  try {
    // Validate call state before attempting to decline
    developer.log('Validating call state before declining callId=$callId', name: 'CallAPI');
    final isValid = await validateCallState(connection, callId: callId);

    if (!isValid) {
      developer.log('Call state validation failed for callId=$callId - call may be in invalid state', name: 'CallAPI');
      throw Exception('Cannot decline call - call is not in a valid state for declining');
    }

    developer.log('Call state validation passed for callId=$callId', name: 'CallAPI');
    developer.log('Sending decline call request for callId=$callId', name: 'CallAPI');
    developer.log('Request URL: calls/$callId/respond', name: 'CallAPI');
    developer.log('Request payload: response=decline', name: 'CallAPI');

    final response = connection.post('declineCall', CallActionResponse.fromJson, 'calls/$callId/respond', {
      'response': RawParameter('decline'),
    });

    developer.log('Call decline request sent successfully for callId=$callId', name: 'CallAPI');
    developer.log('Response received: $response', name: 'CallAPI');
    developer.log('Response type: ${response.runtimeType}', name: 'CallAPI');
    return response;
  } catch (e) {
    developer.log('Failed to decline call callId=$callId: $e', name: 'CallAPI');
    developer.log('Error type: ${e.runtimeType}', name: 'CallAPI');
    developer.log('Full error details: ${e.toString()}', name: 'CallAPI');

    // Log specific error details for debugging
    if (e.toString().contains('400')) {
      developer.log('HTTP 400 Bad Request detected - likely invalid call state or parameters', name: 'CallAPI');
    }
    if (e.toString().contains('network_failure')) {
      developer.log('Network failure detected - call may be in invalid state', name: 'CallAPI');
    }

    rethrow;
  }
}

/// https://zulip.com/api/calls/{callId}/cancel (hypothetical endpoint)
Future<CallActionResponse> cancelCall(ApiConnection connection, {
  required String callId,
}) {
  developer.log(
    'Cancelling call: callId=$callId',
    name: 'CallAPI',
  );

  return connection.post('cancelCall', CallActionResponse.fromJson, 'calls/$callId/cancel', {});
}

/// https://zulip.com/api/calls/{callId}/end (hypothetical endpoint)
Future<CallActionResponse> endCall(ApiConnection connection, {
  required String callId,
  int? duration,
}) {
  developer.log(
    'Ending call: callId=$callId, duration=$duration',
    name: 'CallAPI',
  );

  return connection.post('endCall', CallActionResponse.fromJson, 'calls/$callId/end', {
    if (duration != null) 'duration': duration,
  });
}

/// https://zulip.com/api/calls/{callId}/status (hypothetical endpoint)
Future<CallStatusResponse> getCallStatus(ApiConnection connection, {
  required String callId,
}) {
  developer.log(
    'Getting call status: callId=$callId',
    name: 'CallAPI',
  );

  return connection.get('getCallStatus', CallStatusResponse.fromJson, 'calls/$callId/status', {});
}

/// https://zulip.com/api/calls/heartbeat (hypothetical endpoint)
Future<CallActionResponse> sendHeartbeat(ApiConnection connection, {
  required String callId,
  bool isBackgrounded = false,
}) {
  developer.log(
    'Sending heartbeat: callId=$callId, isBackgrounded=$isBackgrounded',
    name: 'CallAPI',
  );

  return connection.post('sendHeartbeat', CallActionResponse.fromJson, 'calls/heartbeat', {
    'call_id': callId,
    'is_backgrounded': isBackgrounded,
  });
}

/// https://zulip.com/api/calls/end-all (hypothetical endpoint)
Future<EndAllCallsResponse> endAllCalls(ApiConnection connection) {
  developer.log(
    'Ending all calls',
    name: 'CallAPI',
  );

  return connection.post('endAllCalls', EndAllCallsResponse.fromJson, 'calls/end-all', {});
}

/// https://zulip.com/api/calls/active (hypothetical endpoint)
Future<ActiveCallsResponse> getActiveCalls(ApiConnection connection) {
  developer.log(
    'Getting active calls',
    name: 'CallAPI',
  );

  return connection.get('getActiveCalls', ActiveCallsResponse.fromJson, 'calls/active', {});
}

/// https://zulip.com/api/calls/history (hypothetical endpoint)
Future<CallHistoryResponse> getCallHistory(ApiConnection connection, {
  int limit = 50,
  int offset = 0,
}) {
  developer.log(
    'Getting call history: limit=$limit, offset=$offset',
    name: 'CallAPI',
  );

  try {
    developer.log('Sending call history request with limit=$limit, offset=$offset', name: 'CallAPI');

    final response = connection.get('getCallHistory', CallHistoryResponse.fromJson, 'calls/history', {
      'limit': limit,
      'offset': offset,
    });

    developer.log('Call history request sent successfully', name: 'CallAPI');
    return response;
  } catch (e) {
    developer.log('Failed to get call history: $e', name: 'CallAPI');
    developer.log('Error type: ${e.runtimeType}', name: 'CallAPI');
    developer.log('Full error details: ${e.toString()}', name: 'CallAPI');

    // Check for specific malformed response errors
    if (e.toString().contains('malformed response')) {
      developer.log('Server returned malformed response for call history', name: 'CallAPI');
    }
    if (e.toString().contains('type \'Null\' is not a subtype of type \'num\'')) {
      developer.log('Type casting error in call history - server returned null where number expected', name: 'CallAPI');
    }

    rethrow;
  }
}

/// Validate call state before attempting to respond
/// Returns true if call is in a valid state for responding
Future<bool> validateCallState(ApiConnection connection, {
  required String callId,
}) async {
  try {
    final statusResponse = await getCallStatus(connection, callId: callId);
    final callStatus = statusResponse.call.status;

    // Check if call is in a valid state for responding
    return callStatus == CallStatus.ringing || callStatus == CallStatus.created;
  } catch (e) {
    developer.log('Failed to validate call state for callId=$callId: $e', name: 'CallAPI');
    return false;
  }
}


