import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/features/sales/providers/sales_providers.dart';

Profile _profile(UserRole role) =>
    Profile(id: 'p', userId: 'u', tenantId: 't', role: role, displayName: 'x');

void main() {
  // ── P0-7: userRoleProvider must fail CLOSED (least privilege), never to owner.
  group('userRoleProvider fail-closed', () {
    test('returns cashier while the profile is still loading', () {
      final never = StreamController<Profile?>();
      addTearDown(never.close);
      final c = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWith((ref) => never.stream),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(c.listen(userRoleProvider, (_, __) {}).close);

      expect(c.read(userRoleProvider), UserRole.cashier);
    });

    test('returns cashier on profile error', () async {
      final c = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream<Profile?>.error('boom'),
          ),
        ],
      );
      addTearDown(c.dispose);
      // Observe via userRoleProvider (which maps the error to cashier) and
      // swallow the underlying error so it isn't reported as uncaught.
      addTearDown(
        c
            .listen(currentUserProfileProvider, (_, __) {}, onError: (_, __) {})
            .close,
      );
      addTearDown(c.listen(userRoleProvider, (_, __) {}).close);

      await Future<void>.delayed(Duration.zero); // let the error propagate
      expect(c.read(userRoleProvider), UserRole.cashier);
    });

    test('returns the real role once the profile resolves', () async {
      final c = ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(_profile(UserRole.owner)),
          ),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(c.listen(userRoleProvider, (_, __) {}).close);

      await c.read(currentUserProfileProvider.future);
      expect(c.read(userRoleProvider), UserRole.owner);
    });
  });

  // ── P2-8: approval eligibility derived in a provider (was inline in build()).
  group('saleApprovalEligibilityProvider', () {
    ProviderContainer containerWith({
      required UserRole role,
      required List<SaleApproval> approvals,
      required Sale sale,
    }) {
      return ProviderContainer(
        overrides: [
          currentUserProfileProvider.overrideWith(
            (ref) => Stream.value(_profile(role)),
          ),
          saleApprovalsProvider(
            's',
          ).overrideWith((ref) => Stream.value(approvals)),
          saleDetailProvider('s').overrideWith((ref) => Stream.value(sale)),
        ],
      );
    }

    Sale pendingSale({int required = 2, int count = 0}) => Sale(
      id: 's',
      tenantId: 't',
      branchId: 'b',
      status: InvoiceStatus.pendingApproval,
      requiredApprovals: required,
      approvalCount: count,
    );

    Future<SaleApprovalEligibility> evaluate(ProviderContainer c) async {
      addTearDown(c.dispose);
      addTearDown(
        c.listen(saleApprovalEligibilityProvider('s'), (_, __) {}).close,
      );
      // Resolve every dependency the eligibility computation reads.
      await c.read(currentUserProfileProvider.future);
      await c.read(saleDetailProvider('s').future);
      await c.read(saleApprovalsProvider('s').future);
      return c.read(saleApprovalEligibilityProvider('s'));
    }

    test('owner with no prior approval can submit', () async {
      final e = await evaluate(
        containerWith(
          role: UserRole.owner,
          approvals: const [],
          sale: pendingSale(),
        ),
      );
      expect(e.canSubmitApproval, isTrue);
      expect(e.hasCurrentUserApproved, isFalse);
    });

    test('cannot submit once required approvals are met', () async {
      final e = await evaluate(
        containerWith(
          role: UserRole.owner,
          approvals: const [],
          sale: pendingSale(required: 2, count: 2),
        ),
      );
      expect(e.canSubmitApproval, isFalse);
    });

    test('cannot submit twice as the same user', () async {
      final e = await evaluate(
        containerWith(
          role: UserRole.owner,
          approvals: [
            SaleApproval(
              id: 'a',
              saleId: 's',
              tenantId: 't',
              approverUserId: 'u', // same as _profile().userId
              approverRole: 'owner',
            ),
          ],
          sale: pendingSale(),
        ),
      );
      expect(e.hasCurrentUserApproved, isTrue);
      expect(e.canSubmitApproval, isFalse);
    });

    test('cashier without approve permission cannot submit', () async {
      final e = await evaluate(
        containerWith(
          role: UserRole.cashier,
          approvals: const [],
          sale: pendingSale(),
        ),
      );
      expect(e.canSubmitApproval, isFalse);
    });
  });
}
