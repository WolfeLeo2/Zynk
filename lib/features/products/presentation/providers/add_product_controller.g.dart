// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_product_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AddProductController)
final addProductControllerProvider = AddProductControllerProvider._();

final class AddProductControllerProvider
    extends $AsyncNotifierProvider<AddProductController, void> {
  AddProductControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'addProductControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$addProductControllerHash();

  @$internal
  @override
  AddProductController create() => AddProductController();
}

String _$addProductControllerHash() =>
    r'ed6a4e5900bd1dc9bddb088585d9ead478360646';

abstract class _$AddProductController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
