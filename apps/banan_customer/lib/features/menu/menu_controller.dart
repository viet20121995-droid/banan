import 'package:banan_core/banan_core.dart';
import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Customer-side menu state.
@immutable
class MenuState {
  const MenuState({
    this.categoryId,
    this.query = '',
    this.products = const [],
    this.loading = false,
    this.failure,
    this.loaded = false,
    this.servedFromCache = false,
    this.cacheUpdatedAt,
  });

  final String? categoryId;
  final String query;
  final List<Product> products;
  final bool loading;
  final AppFailure? failure;
  final bool loaded;

  /// True when the products visible right now came from the local cache
  /// (the network was unreachable). UI surfaces a banner.
  final bool servedFromCache;
  final DateTime? cacheUpdatedAt;

  MenuState copyWith({
    Object? categoryId = _sentinel,
    String? query,
    List<Product>? products,
    bool? loading,
    Object? failure = _sentinel,
    bool? loaded,
    bool? servedFromCache,
    Object? cacheUpdatedAt = _sentinel,
  }) {
    return MenuState(
      categoryId:
          categoryId == _sentinel ? this.categoryId : categoryId as String?,
      query: query ?? this.query,
      products: products ?? this.products,
      loading: loading ?? this.loading,
      failure: failure == _sentinel ? this.failure : failure as AppFailure?,
      loaded: loaded ?? this.loaded,
      servedFromCache: servedFromCache ?? this.servedFromCache,
      cacheUpdatedAt: cacheUpdatedAt == _sentinel
          ? this.cacheUpdatedAt
          : cacheUpdatedAt as DateTime?,
    );
  }
}

const _sentinel = Object();

class MenuController extends StateNotifier<MenuState> {
  MenuController(this._repo, this._catalogApi) : super(const MenuState()) {
    refresh();
  }

  final CatalogRepository _repo;
  final CatalogApi _catalogApi;

  Future<void> selectCategory(String? id) async {
    if (state.categoryId == id) return;
    state = state.copyWith(categoryId: id);
    await refresh();
  }

  Future<void> setQuery(String q) async {
    if (state.query == q) return;
    state = state.copyWith(query: q);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, failure: null);
    final res = await _repo.products(
      categoryId: state.categoryId,
      q: state.query.trim().isEmpty ? null : state.query.trim(),
      perPage: 50,
    );
    res.when(
      success: (page) {
        state = state.copyWith(
          products: page.items,
          loading: false,
          loaded: true,
          servedFromCache: _catalogApi.lastWasCached,
          cacheUpdatedAt: _catalogApi.lastWasCached
              ? _catalogApi.lastCacheTimestamp
              : null,
        );
      },
      failure: (f) {
        state = state.copyWith(loading: false, failure: f, loaded: true);
      },
    );
  }
}

final menuControllerProvider =
    StateNotifierProvider.autoDispose<MenuController, MenuState>((ref) {
  return MenuController(
    ref.watch(catalogRepositoryProvider),
    ref.watch(catalogApiProvider),
  );
});
