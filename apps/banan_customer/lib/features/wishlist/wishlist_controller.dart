import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set of product ids the current user has wishlisted. Returns an empty set
/// when not logged in — guests don't have a wishlist (they need an account
/// to persist favorites across devices).
final wishlistIdsProvider =
    AsyncNotifierProvider<WishlistIdsController, Set<String>>(
  WishlistIdsController.new,
);

class WishlistIdsController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null) return <String>{};
    final api = ref.watch(wishlistApiProvider);
    final res = await api.ids();
    return res.when(
      success: (ids) => ids,
      failure: (_) => <String>{},
    );
  }

  /// Toggles the heart on a product. Optimistic — flips the set immediately,
  /// then issues the API call. On failure the set is reverted and the error
  /// surfaces via [state].
  Future<void> toggle(String productId) async {
    final current = state.valueOrNull ?? <String>{};
    final wasIn = current.contains(productId);
    final next = {...current};
    if (wasIn) {
      next.remove(productId);
    } else {
      next.add(productId);
    }
    state = AsyncData(next);

    final api = ref.read(wishlistApiProvider);
    final res = wasIn ? await api.remove(productId) : await api.add(productId);
    res.when(
      success: (_) {},
      failure: (f) {
        // Roll back and bubble up.
        state = AsyncData(current);
        state = AsyncError(
          Exception(f.message ?? f.code),
          StackTrace.current,
        );
      },
    );
  }
}

/// Helper — true when [productId] is currently in the wishlist (or false
/// while loading / for guests).
bool isWishlisted(AsyncValue<Set<String>> async, String productId) {
  return async.valueOrNull?.contains(productId) ?? false;
}

/// Full wishlist page — used by the "Yêu thích" tab in profile.
final wishlistProvider = FutureProvider.autoDispose<List<WishlistItem>>(
  (ref) async {
    final session = await ref.watch(authSessionProvider.future);
    if (session == null) return const [];
    final api = ref.watch(wishlistApiProvider);
    final res = await api.list();
    return res.when(
      success: (items) => items,
      failure: (f) => throw Exception(f.message ?? f.code),
    );
  },
);
