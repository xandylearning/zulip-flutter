import 'package:flutter/material.dart';

import '../api/model/model.dart';
import '../generated/l10n/zulip_localizations.dart';
import 'icons.dart';
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

  @override
  void onNewStore() {
    // TODO: Listen to call-related models when implemented
  }

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);

    // Mock call log data - in a real app, this would come from a database or API
    final callLogEntries = _getMockCallLog();

    if (callLogEntries.isEmpty) {
      return Center(
        child: PageBodyEmptyContentPlaceholder(
          message: 'No call history yet',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: callLogEntries.length,
      itemBuilder: (context, index) {
        final entry = callLogEntries[index];
        return _CallLogItem(entry: entry);
      },
    );
  }

  List<CallLogEntry> _getMockCallLog() {
    final store = PerAccountStoreWidget.of(context);
    final allUsers = store.allUsers.where((user) => user.userId != store.selfUserId).toList();

    if (allUsers.isEmpty) return [];

    // Create mock call log entries
    return [
      CallLogEntry(
        user: allUsers[0],
        callType: CallType.outgoing,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        duration: const Duration(minutes: 15, seconds: 30),
      ),
      CallLogEntry(
        user: allUsers.length > 1 ? allUsers[1] : allUsers[0],
        callType: CallType.incoming,
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        duration: const Duration(minutes: 8, seconds: 45),
      ),
      CallLogEntry(
        user: allUsers.length > 2 ? allUsers[2] : allUsers[0],
        callType: CallType.missed,
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        duration: null,
      ),
      CallLogEntry(
        user: allUsers.length > 1 ? allUsers[1] : allUsers[0],
        callType: CallType.incoming,
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        duration: const Duration(minutes: 22, seconds: 10),
      ),
    ];
  }
}

enum CallType {
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
  final CallType callType;
  final DateTime timestamp;
  final Duration? duration;
}

class _CallLogItem extends StatelessWidget {
  const _CallLogItem({required this.entry});

  final CallLogEntry entry;

  IconData get _callIcon {
    switch (entry.callType) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_received;
    }
  }

  Color _getCallIconColor(BuildContext context) {
    switch (entry.callType) {
      case CallType.incoming:
        return const Color(0xFF25D366);
      case CallType.outgoing:
        return const Color(0xFF808080);
      case CallType.missed:
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
          Text(_formatTimestamp(context)),
          if (entry.duration != null) ...[
            const SizedBox(width: 8),
            Text('(${_formatDuration()})',
              style: TextStyle(
                color: designVariables.labelMenuButton.withOpacity(0.7),
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling ${entry.user.fullName}...')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.videocam, color: const Color(0xFF25D366)),
            iconSize: 24,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Video calling ${entry.user.fullName}...')),
              );
            },
          ),
        ],
      ),
    );
  }
}