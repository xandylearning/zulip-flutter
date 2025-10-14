import 'package:flutter/material.dart';

import '../api/model/call.dart';
import '../api/model/model.dart';
import '../api/route/calls.dart' as api;
import '../model/call_permissions.dart';
import '../model/store.dart';
import 'call_dialing_screen.dart';
import 'page.dart';
import 'store.dart';
import 'user.dart';
import 'theme.dart';

class CallsPageBody extends StatefulWidget {
  const CallsPageBody({super.key});

  @override
  State<CallsPageBody> createState() => _CallsPageBodyState();
}

class _CallsPageBodyState extends State<CallsPageBody>
    with PerAccountStoreAwareStateMixin<CallsPageBody> {
  PerAccountStore? _store;

  @override
  void onNewStore() {
    _store = PerAccountStoreWidget.of(context);
    _store!.callStore.addListener(_onCallStoreChange);
  }

  void _onCallStoreChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store?.callStore.removeListener(_onCallStoreChange);
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final store = PerAccountStoreWidget.of(context);
    await store.callStore.loadCallHistory();
  }

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final callHistory = store.callStore.callHistory;
    final isLoading = store.callStore.isLoadingHistory;

    // Show loading indicator if first load and no history yet
    if (isLoading && callHistory.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // Show empty state if no history
    if (callHistory.isEmpty) {
      return RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(
              child: PageBodyEmptyContentPlaceholder(
                message: 'No call history yet',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: callHistory.length,
        itemBuilder: (context, index) {
        final call = callHistory[index];
        final store = PerAccountStoreWidget.of(context);
        final userId = call.callerId == store.selfUserId ? call.recipientId : call.callerId;
        final user = store.getUser(userId);

        if (user == null) return const SizedBox.shrink();

        final callLogEntry = CallLogEntry(
          user: user,
          callType: _getCallLogType(call),
          timestamp: DateTime.fromMillisecondsSinceEpoch(call.timestamp! * 1000),
          duration: call.duration != null ? Duration(seconds: call.duration!) : null,
        );

        return _CallLogItem(
          entry: callLogEntry,
          selfUserId: store.selfUserId,
        );
        },
      ),
    );
  }

  CallLogType _getCallLogType(Call call) {
    final store = PerAccountStoreWidget.of(context);
    if (call.status == CallStatus.cancelled || call.status == CallStatus.declined) {
      return CallLogType.missed;
    } else if (call.callerId == store.selfUserId) {
      return CallLogType.outgoing;
    } else {
      return CallLogType.incoming;
    }
  }
}

enum CallLogType {
  incoming,
  outgoing,
  missed,
}

class CallLogEntry {
  const CallLogEntry({
    required this.user,
    required this.callType,
    required this.timestamp,
    this.duration,
  });

  final User user;
  final CallLogType callType;
  final DateTime timestamp;
  final Duration? duration;
}

class _CallLogItem extends StatelessWidget {
  const _CallLogItem({
    required this.entry,
    required this.selfUserId,
  });

  final CallLogEntry entry;
  final int selfUserId;

  IconData get _callIcon {
    switch (entry.callType) {
      case CallLogType.incoming:
        return Icons.call_received;
      case CallLogType.outgoing:
        return Icons.call_made;
      case CallLogType.missed:
        return Icons.call_received;
    }
  }

  Color _getCallIconColor(BuildContext context) {
    switch (entry.callType) {
      case CallLogType.incoming:
        return const Color(0xFF25D366);
      case CallLogType.outgoing:
        return const Color(0xFF808080);
      case CallLogType.missed:
        return Colors.red;
    }
  }

  String _formatTimestamp(BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(entry.timestamp);

    if (difference.inDays == 0) {
      return '${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${entry.timestamp.day}/${entry.timestamp.month}/${entry.timestamp.year}';
    }
  }

  String? _formatDuration() {
    if (entry.duration == null) return null;
    final minutes = entry.duration!.inMinutes;
    final seconds = entry.duration!.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);

    return ListTile(
      leading: Avatar(
        userId: entry.user.userId,
        size: 40,
        borderRadius: 20,
      ),
      title: Text(
        entry.user.fullName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          Icon(
            _callIcon,
            size: 16,
            color: _getCallIconColor(context),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(_formatTimestamp(context)),
          ),
          if (entry.duration != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text('(${_formatDuration()})',
                style: TextStyle(
                  color: designVariables.labelMenuButton.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.phone, color: const Color(0xFF25D366)),
            iconSize: 24,
            onPressed: () => _initiateCall(context, entry.user, isVideo: false),
          ),
          IconButton(
            icon: Icon(Icons.videocam, color: const Color(0xFF25D366)),
            iconSize: 24,
            onPressed: () => _initiateCall(context, entry.user, isVideo: true),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateCall(BuildContext context, User user, {required bool isVideo}) async {
    final store = PerAccountStoreWidget.of(context);
    String? callId;

    // Check permissions first
    final hasPermission = isVideo
        ? await CallPermissions.requestVideoCallPermissions(context)
        : await CallPermissions.requestAudioCallPermissions(context);

    if (!hasPermission) {
      return;
    }

    try {
      debugPrint('Calls: Starting call creation for user ${user.userId}, isVideo: $isVideo');

      // Create the call
      final response = await api.createCall(
        store.connection,
        userId: user.userId,
        isVideoCall: isVideo,
      );

      debugPrint('Calls: Call created successfully, callId: ${response.callId}');
      callId = response.callId;

      if (!context.mounted) {
        debugPrint('Calls: Context not mounted, aborting');
        return;
      }

      // Create Call object from response
      final call = Call(
        callId: response.callId,
        callerId: store.selfUserId,
        recipientId: user.userId,
        callType: response.callType == 'video' ? CallType.video : CallType.audio,
        status: CallStatus.created,
        jitsiUrl: response.callUrl,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      debugPrint('Calls: Call object created: ${call.callId}');
      debugPrint('Calls: Call callerId: ${call.callerId}, selfUserId: ${store.selfUserId}');

      // Manually add to pending calls since CallCreatedEvent might not be received
      debugPrint('Calls: Manually adding call to pending outgoing calls: ${call.callId}');
      store.callStore.addPendingOutgoingCall(call);
      debugPrint('Calls: Call added to pending calls successfully');

      // Navigate to dialing screen first
      await Navigator.of(context).push(
        CallDialingScreen.buildRoute(
          accountId: PerAccountStoreWidget.accountIdOf(context),
          call: call,
          recipient: user,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      // Cancel the call if it was created but navigation failed
      if (callId != null) {
        try {
          await api.cancelCall(store.connection, callId: callId);
        } catch (cancelError) {
          debugPrint('Failed to cancel call after navigation error: $cancelError');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initiate call: $e')),
      );
    }
  }
}