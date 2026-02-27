import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/core/providers/app_providers.dart';

/// Stream of all customers for the current tenant.
final allCustomersProvider = StreamProvider<List<Customer>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchCustomers();
});
