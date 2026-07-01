import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/utils/error_messages.dart';

class InventoryService {
  final SupabaseClient _supabase;

  InventoryService(this._supabase);

  Future<void> _ensureSession() async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (expiryTime.difference(DateTime.now()).inSeconds < 60) {
        await _supabase.auth.refreshSession();
      }
    }
  }

  Future<dynamic> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    await _ensureSession();
    try {
      final response = await _supabase.functions.invoke(
        functionName,
        body: body,
      );
      return response.data;
    } on FunctionException catch (e) {
      throw Exception(friendlyError(e));
    }
  }

  Future<void> approveAdjustment({
    required String tenantId,
    String? bundleId,
    String? adjustmentId,
  }) async {
    await _invoke('manage-stock-adjustment', {
      'action': 'approve_adjustment',
      'tenant_id': tenantId,
      'bundle_id': bundleId,
      'adjustment_id': adjustmentId,
    });
  }

  Future<void> rejectAdjustment({
    required String tenantId,
    String? bundleId,
    String? adjustmentId,
    required String reason,
  }) async {
    await _invoke('manage-stock-adjustment', {
      'action': 'reject_adjustment',
      'tenant_id': tenantId,
      'bundle_id': bundleId,
      'adjustment_id': adjustmentId,
      'reason': reason,
    });
  }

  Future<void> deleteAdjustment({
    required String tenantId,
    String? bundleId,
    String? adjustmentId,
  }) async {
    await _invoke('manage-stock-adjustment', {
      'action': 'delete_adjustment',
      'tenant_id': tenantId,
      'bundle_id': bundleId,
      'adjustment_id': adjustmentId,
    });
  }

  Future<void> unapproveAdjustment({
    required String tenantId,
    String? bundleId,
    String? adjustmentId,
  }) async {
    await _invoke('manage-stock-adjustment', {
      'action': 'unapprove_adjustment',
      'tenant_id': tenantId,
      'bundle_id': bundleId,
      'adjustment_id': adjustmentId,
    });
  }
}
