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
  return _orThrow(
    await ref.watch(manufacturingApiProvider).expiringLots(before),
  );
});

/// [state] filter: null = all, else one of DRAFT/CONFIRMED/PROGRESS/DONE/CANCEL.
final moListProvider = FutureProvider.autoDispose
    .family<List<MfgOrderSummary>, String?>((ref, state) async {
  return _orThrow(
    await ref.watch(manufacturingApiProvider).listOrders(state: state),
  );
});

final moDetailProvider =
    FutureProvider.autoDispose.family<MfgOrderDetail, String>((ref, id) async {
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
  return _orThrow(
    await ref.watch(manufacturingApiProvider).listAlerts(stage: 'NEW'),
  );
});

// ── planning ──
final scheduleProvider =
    FutureProvider.autoDispose<List<MfgScheduleItem>>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).schedule());
});

final staffProvider = FutureProvider.autoDispose<List<MfgStaff>>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).listStaff());
});

// ── reports + replenishment ──
/// Date-range key for the report providers: (from, to), either nullable.
/// A record has value equality, so the family caches per distinct range.
typedef MfgReportRange = (DateTime? from, DateTime? to);

final productionReportProvider = FutureProvider.autoDispose
    .family<MfgProductionReport, MfgReportRange>((ref, range) async {
  return _orThrow(
    await ref
        .watch(manufacturingApiProvider)
        .productionReport(from: range.$1, to: range.$2),
  );
});

final scrapReportProvider = FutureProvider.autoDispose
    .family<MfgScrapReport, MfgReportRange>((ref, range) async {
  return _orThrow(
    await ref
        .watch(manufacturingApiProvider)
        .scrapReport(from: range.$1, to: range.$2),
  );
});

final costReportProvider = FutureProvider.autoDispose
    .family<MfgCostReport, MfgReportRange>((ref, range) async {
  return _orThrow(
    await ref
        .watch(manufacturingApiProvider)
        .costReport(from: range.$1, to: range.$2),
  );
});

final replenishmentProvider =
    FutureProvider.autoDispose<MfgReplenishment>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).replenishment());
});

// ── master data + quality alerts (increment 7 forms) ──
/// `type` filters RAW/SEMI/FINISHED/PACKAGING; null = all active products.
final productsProvider = FutureProvider.autoDispose
    .family<List<MfgProduct>, String?>((ref, type) async {
  return _orThrow(
    await ref.watch(manufacturingApiProvider).listProducts(type: type),
  );
});

/// `stage` filters NEW/CONFIRMED/SOLVED; null = all.
final alertsProvider = FutureProvider.autoDispose
    .family<List<MfgQualityAlert>, String?>((ref, stage) async {
  return _orThrow(
    await ref.watch(manufacturingApiProvider).listAlerts(stage: stage),
  );
});

// ── product management (create/edit/archive master data) ──
/// Management list — includes archived products so they can be reactivated.
final adminProductsProvider =
    FutureProvider.autoDispose<List<MfgProduct>>((ref) async {
  return _orThrow(
    await ref
        .watch(manufacturingApiProvider)
        .listProducts(includeInactive: true),
  );
});

final mfgUomsProvider =
    FutureProvider.autoDispose<List<MfgUomOption>>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).listUoms());
});

// "mfg" prefix: banan_data already exports a categoriesProvider (menu
// categories) — an unprefixed name here is ambiguous at the import site.
final mfgCategoriesProvider =
    FutureProvider.autoDispose<List<MfgCategoryOption>>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).listCategories());
});

// ── maintenance + OEE (increment 8) ──
final oeeReportProvider = FutureProvider.autoDispose
    .family<List<MfgOeeRow>, MfgReportRange>((ref, range) async {
  return _orThrow(
    await ref
        .watch(manufacturingApiProvider)
        .oeeReport(from: range.$1, to: range.$2),
  );
});

/// `state` filters PLANNED/DONE; null = all.
final maintenanceProvider = FutureProvider.autoDispose
    .family<List<MfgMaintenance>, String?>((ref, state) async {
  return _orThrow(
    await ref.watch(manufacturingApiProvider).listMaintenance(state: state),
  );
});

// ── BoM editor (increment 7) ──
final workCentersProvider =
    FutureProvider.autoDispose<List<MfgWorkCenter>>((ref) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).listWorkCenters());
});

/// Full BoM for editing an existing recipe.
final bomDetailProvider =
    FutureProvider.autoDispose.family<MfgBomDetail, String>((ref, id) async {
  return _orThrow(await ref.watch(manufacturingApiProvider).getBom(id));
});
