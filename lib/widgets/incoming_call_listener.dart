import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zulip_call_kit/zulip_call_kit.dart';

import '../api/model/call.dart';
import 'incoming_call_card.dart';
import 'persistent_call_indicator.dart';
import 'store.dart';

/// Widget that listens for incoming calls across all accounts
/// and shows either a call card (when app is open) or CallWakeUpScreen (when app is closed).
class IncomingCallListener extends StatefulWidget {
  const IncomingCallListener({super.key, required this.child});

  final Widget child;

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  final Map<int, StreamSubscription<Call>> _subscriptions = {};
  final Map<int, StreamSubscription<bool>> _callStateSubscriptions = {};
  Call? _currentIncomingCall;
  int? _currentCallAccountId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set up listeners for all accounts
    final globalStore = GlobalStoreWidget.of(context);
    for (final account in globalStore.accounts) {
      if (!_subscriptions.containsKey(account.id)) {
        _setupListenerForAccount(account.id);
      }
    }

    // Clean up subscriptions for accounts that no longer exist
    final currentAccountIds = globalStore.accounts.map((a) => a.id).toSet();
    _subscriptions.keys.toList().forEach((accountId) {
      if (!currentAccountIds.contains(accountId)) {
        debugPrint('IncomingCallListener: Removing subscription for account $accountId');
        _subscriptions.remove(accountId)?.cancel();
        _callStateSubscriptions.remove(accountId)?.cancel();
      }
    });
  }

  Future<void> _setupListenerForAccount(int accountId) async {
    try {
      debugPrint('IncomingCallListener: Setting up listener for account $accountId');
      final globalStore = GlobalStoreWidget.of(context);
      final perAccountStore = await globalStore.perAccount(accountId);

      debugPrint('IncomingCallListener: Got perAccountStore for account $accountId');

      // Listen to incoming call stream
      final subscription = perAccountStore.callStore.incomingCallStream.listen((call) {
        debugPrint('IncomingCallListener: Received incoming call ${call.callId}');
        _showCallScreen(accountId, call);
      });

      // Listen to call state changes to detect cancellations
      final callStateSubscription = perAccountStore.callStore.hasActiveCallStream.listen((hasActiveCall) {
        debugPrint('IncomingCallListener: Call state changed for account $accountId: hasActiveCall=$hasActiveCall');
        if (!hasActiveCall && _currentIncomingCall != null && _currentCallAccountId == accountId) {
          debugPrint('IncomingCallListener: Call was cancelled/ended, dismissing card for call ${_currentIncomingCall!.callId}');
          _dismissCallCardDueToCancellation();
        }
      });

      _subscriptions[accountId] = subscription;
      _callStateSubscriptions[accountId] = callStateSubscription;
      debugPrint('IncomingCallListener: Successfully subscribed to streams for account $accountId');
    } catch (e) {
      debugPrint('IncomingCallListener: Failed to setup listener for account $accountId: $e');
    }
  }

  void _showCallScreen(int accountId, Call call) {
    if (!mounted) return;

    // Check if we're already showing a call for this call ID
    if (_currentIncomingCall?.callId == call.callId) {
      debugPrint('IncomingCallListener: Already showing call ${call.callId}, ignoring duplicate');
      return;
    }

    debugPrint('IncomingCallListener: Showing incoming call ${call.callId}');

    // Show the call card overlay instead of navigating to a full screen
    setState(() {
      _currentIncomingCall = call;
      _currentCallAccountId = accountId;
    });
  }

  void _dismissCallCard() {
    if (mounted) {
      debugPrint('IncomingCallListener: Dismissing call card, but keeping call active in store');
      setState(() {
        _currentIncomingCall = null;
        _currentCallAccountId = null;
      });

      // Force a check for persistent indicator after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          debugPrint('IncomingCallListener: Triggering persistent indicator check after card dismiss');
          // The persistent indicator should automatically detect the active call
          // We can trigger a rebuild by calling setState on the parent widget
          if (context.mounted) {
            // Find the PersistentCallIndicator and force a check
            final persistentIndicator = context.findAncestorStateOfType<PersistentCallIndicatorState>();
            if (persistentIndicator != null) {
              persistentIndicator.forceCheck();
            }
          }
        }
      });
    }
  }

  void _dismissCallCardDueToCancellation() {
    if (mounted) {
      debugPrint('IncomingCallListener: Call was cancelled by initiator, dismissing card');
      setState(() {
        _currentIncomingCall = null;
        _currentCallAccountId = null;
      });

      // Show a brief message to the user that the call was cancelled
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call was cancelled by the caller'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _callStateSubscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _callStateSubscriptions.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentIncomingCall != null && _currentCallAccountId != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PerAccountStoreWidget(
              accountId: _currentCallAccountId!,
              child: IncomingCallCard(
                call: _currentIncomingCall!,
                onDismiss: _dismissCallCard,
              ),
            ),
          ),
      ],
    );
  }
}
