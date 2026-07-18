import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Providers for the "Sản xuất" (manufacturing) section. Each unwraps the
/// Result and rethrows on failure so screens can use AsyncValue.when's error
/// branch — the same shape the rest of the kitchen app uses.

T _orThrow<T>(Result<T, AppFailure> res) => res.when(
      success: (v) => v,
      failure: (f) => throw Exception(f.message ?? f.code),
    );

final moCountsProvider =
    FutureProvider.autoDispose<List<MfgStateCount>>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).moCounts());
});

final expiringLotsProvider =
    FutureProvider.autoDispose<List<MfgExpiringLot>>((ref) async {
  // Anything expiring within 3 days is worth surfacing on the dashboard.
  final before = DateTime.now().add(const Duration(days: 3));
  return _orThrow(await ref.watch(manufacturingApiProvider).expiringLots(before));
});

/// [state] filter: null = all, else one of DRAFT/CONFIRMED/PROGRESS/DONE/CANCEL.
final moListProvider = FutureProvider.autoDispose
    .family<List<MfgOrderSummary>, String?>((ref, state) async {
  return _orThrow(
    await ref.watch(manufacturingApiProvider).listOrders(state: state),
  );
});

final moDetailProvider = FutureProvider.autoDispose
    .family<MfgOrderDetail, String>((ref, id) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).getOrder(id));
});

final bomListProvider =
    FutureProvider.autoDispose<List<MfgBomSummary>>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).listBoms());
});

final onHandProvider = FutureProvider.autoDispose<List<MfgOnHand>>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).onHand());
});

/// Only a kitchen manager (or admin) may move stock/cost — writes are gated in
/// the backend too, this just keeps the buttons honest.
final canProduceProvider = Provider.autoDispose<bool>((ref) {
  final role = ref.watch(authSessionProvider).valueOrNull?.user.role;
  return role != null && (role.isAdmin || role == Role.kitchenManager);
});

/// Any kitchen role runs the shop floor (baker/QC start/done + record checks).
final canRunFloorProvider = Provider.autoDispose<bool>((ref) {
  final role = ref.watch(authSessionProvider).valueOrNull?.user.role;
  return role != null && (role.isKitchen || role.isAdmin);
});

final shopFloorProvider =
    FutureProvider.autoDispose<List<MfgWorkOrderCard>>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).shopFloor());
});

final qualityAlertsProvider =
    FutureProvider.autoDispose<List<MfgQualityAlert>>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).listAlerts(stage: 'NEW'));
});
