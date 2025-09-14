import 'package:intl/intl.dart';

/// X&Y Learning Platform text formatting utilities.
///
/// Provides consistent text formatting throughout the app for
/// dates, numbers, currencies, and other common formats.
class XYFormatters {
  XYFormatters._(); // Private constructor to prevent instantiation

  // Date formatters
  static final DateFormat _shortDate = DateFormat.yMd();
  static final DateFormat _longDate = DateFormat.yMMMMd();
  static final DateFormat _timeOnly = DateFormat.Hm();
  static final DateFormat _dateTime = DateFormat.yMd().add_Hm();
  static final DateFormat _monthDay = DateFormat.MMMd();
  static final DateFormat _fullDateTime = DateFormat.yMMMMd().add_Hms();

  /// Formats a date to short format (e.g., "12/31/2023")
  static String shortDate(DateTime date) => _shortDate.format(date);

  /// Formats a date to long format (e.g., "December 31, 2023")
  static String longDate(DateTime date) => _longDate.format(date);

  /// Formats time only (e.g., "14:30")
  static String timeOnly(DateTime date) => _timeOnly.format(date);

  /// Formats date and time (e.g., "12/31/2023 14:30")
  static String dateTime(DateTime date) => _dateTime.format(date);

  /// Formats month and day (e.g., "Dec 31")
  static String monthDay(DateTime date) => _monthDay.format(date);

  /// Formats full date and time (e.g., "December 31, 2023 2:30:45 PM")
  static String fullDateTime(DateTime date) => _fullDateTime.format(date);

  /// Formats relative time (e.g., "2 hours ago", "Just now")
  static String relativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return shortDate(date);
    }
  }

  /// Formats file size in human readable format
  static String fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Formats duration in human readable format
  static String duration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '0:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Formats number with thousand separators
  static String number(num value) {
    final formatter = NumberFormat('#,###');
    return formatter.format(value);
  }

  /// Formats percentage
  static String percentage(double value, {int decimals = 1}) {
    final formatter = NumberFormat.percentPattern();
    formatter.minimumFractionDigits = decimals;
    formatter.maximumFractionDigits = decimals;
    return formatter.format(value / 100);
  }

  /// Formats currency (USD by default)
  static String currency(double amount, {String symbol = '\$', int decimals = 2}) {
    return '$symbol${amount.toStringAsFixed(decimals)}';
  }

  /// Capitalizes the first letter of a string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  /// Converts to title case (each word capitalized)
  static String titleCase(String text) {
    return text.split(' ').map(capitalize).join(' ');
  }

  /// Truncates text with ellipsis
  static String truncate(String text, int maxLength, {String ellipsis = '...'}) {
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - ellipsis.length) + ellipsis;
  }

  /// Formats initials from a name
  static String initials(String name, {int maxInitials = 2}) {
    final words = name.trim().split(RegExp(r'\s+'));
    final initialsCount = maxInitials.clamp(1, words.length);

    return words
        .take(initialsCount)
        .map((word) => word.isEmpty ? '' : word[0].toUpperCase())
        .join();
  }

  /// Formats phone number to (XXX) XXX-XXXX format
  static String phoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    }

    return phone; // Return original if format is unknown
  }

  /// Formats message timestamp for chat bubbles
  static String messageTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (messageDate == today) {
      return timeOnly(timestamp);
    } else if (messageDate == yesterday) {
      return 'Yesterday ${timeOnly(timestamp)}';
    } else if (now.difference(timestamp).inDays < 7) {
      return '${DateFormat.E().format(timestamp)} ${timeOnly(timestamp)}';
    } else {
      return '${shortDate(timestamp)} ${timeOnly(timestamp)}';
    }
  }

  /// Formats online status
  static String onlineStatus(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';

    final difference = DateTime.now().difference(lastSeen);

    if (difference.inMinutes < 5) return 'Online';
    if (difference.inMinutes < 60) return 'Last seen ${difference.inMinutes}m ago';
    if (difference.inHours < 24) return 'Last seen ${difference.inHours}h ago';
    if (difference.inDays < 7) return 'Last seen ${difference.inDays}d ago';

    return 'Last seen ${shortDate(lastSeen)}';
  }
}