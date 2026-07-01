import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns backend/SDK errors into a single user-facing sentence — never a raw
/// HTTP status like 401/403. Edge Functions here return `{ "error": "<msg>" }`,
/// so we surface that; otherwise we map the status/type to something readable.
String friendlyError(Object error) {
  if (error is FunctionException) {
    final details = error.details;
    final msg = details is Map ? details['error'] : null;
    if (msg is String && msg.trim().isNotEmpty) return msg;
    switch (error.status) {
      case 400:
        return 'That request was invalid. Please check and try again.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return "You don't have permission to do that.";
      case 404:
        return 'We couldn’t find that.';
      case 409:
        return 'That conflicts with existing data.';
      case 429:
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
  if (error is AuthException) {
    final m = error.message.toLowerCase();
    if (m.contains('invalid login') || m.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    return error.message;
  }
  if (error is PostgrestException) return error.message;

  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('Failed host lookup') ||
      text.contains('ClientException') ||
      text.contains('Connection')) {
    return 'No internet connection. Please check your network and try again.';
  }
  final cleaned = text.replaceFirst('Exception: ', '').trim();
  return cleaned.isEmpty ? 'Something went wrong. Please try again.' : cleaned;
}
