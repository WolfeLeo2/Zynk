import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/utils/error_messages.dart';
import 'package:zynk/core/services/app_logger.dart';

final _log = AppLogger('CommissionService');

final commissionServiceProvider = Provider<CommissionService>((ref) {
  return CommissionService(Supabase.instance.client);
});

/// Service to handle commission-related operations via Edge Functions.
class CommissionService {
  final SupabaseClient _supabase;

  CommissionService(this._supabase);

  Future<void> _ensureSession() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('Not authenticated. Please sign in again.');
    }

    // Check if session is expired or expiring soon (within 60s)
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (expiryTime.difference(DateTime.now()).inSeconds < 60) {
        await _supabase.auth.refreshSession();
      }
    }
  }

  Future<dynamic> _invoke(
    String action,
    String tenantId,
    Map<String, dynamic> params,
  ) async {
    await _ensureSession();

    try {
      final response = await _supabase.functions.invoke(
        'manage-commissions',
        body: {'action': action, 'tenant_id': tenantId, ...params},
      );
      return response.data;
    } on FunctionException catch (e) {
      _log.e('Commission action "$action" failed: ${e.status}');
      throw Exception(friendlyError(e));
    }
  }

  /// Marks a specific commission as paid.
  Future<void> markPaid({
    required String tenantId,
    required String commissionId,
  }) async {
    _log.i('Marking commission $commissionId as paid');
    await _invoke('mark_paid', tenantId, {'commission_id': commissionId});
  }

  /// Marks all pending commissions for a salesperson as paid for a specific month.
  Future<void> markAllPaid({
    required String tenantId,
    required String salespersonId,
    String? branchId,
    DateTime? month,
  }) async {
    _log.i('Marking all commissions for salesperson $salespersonId as paid');

    // Format month as yyyy-MM
    String? monthStr;
    if (month != null) {
      monthStr = "${month.year}-${month.month.toString().padLeft(2, '0')}";
    }

    await _invoke('mark_all_paid', tenantId, {
      'salesperson_id': salespersonId,
      'branch_id': ?branchId,
      'month': ?monthStr,
    });
  }
}
