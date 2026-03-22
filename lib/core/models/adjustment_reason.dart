// ─────────────────────────────────────────────────────────────────────────────
// ADJUSTMENT REASON MODEL
// ─────────────────────────────────────────────────────────────────────────────

class AdjustmentReason {
  final String id;
  final String tenantId;
  final String label;
  final DateTime? createdAt;

  const AdjustmentReason({
    required this.id,
    required this.tenantId,
    required this.label,
    this.createdAt,
  });

  factory AdjustmentReason.fromMap(Map<String, dynamic> map) {
    return AdjustmentReason(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      label: map['label'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'tenant_id': tenantId,
    'label': label,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}
