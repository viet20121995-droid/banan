import 'package:banan_data/banan_data.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ms/ms_detail_screen.dart';
import '../features/ms/ms_list_screen.dart';
import '../features/public_form/ms_form_screen.dart';
import '../features/qc/qc_compare_screen.dart';
import '../features/qc/qc_detail_screen.dart';
import '../features/qc/qc_list_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/training/training_screen.dart';

/// Router for the internal ops app.
///
/// Authorization is enforced in the GLOBAL redirect for EVERY route (unlike
/// the merchant app, where hiding sidebar links does most of the work):
/// anything that is not the public MS form requires a session AND the ADMIN
/// role — deep links included. The backend enforces the same rule again on
/// every API call.
final internalRouterProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final refresh = GoRouterRefreshStream(repo.watchSession());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/qc',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      // The Mystery Shopper fills the form via a secret link, no account.
      if (loc.startsWith('/f/')) return null;
      final session = repo.currentSession;
      if (session == null) return loc == '/login' ? null : '/login';
      if (!session.user.role.isAdmin) {
        return loc == '/wrong-app' ? null : '/wrong-app';
      }
      if (loc == '/login' || loc == '/wrong-app' || loc == '/') return '/qc';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, __) => '/qc'),
      GoRoute(path: '/qc', builder: (_, __) => const QcListScreen()),
      GoRoute(path: '/qc/compare', builder: (_, __) => const QcCompareScreen()),
      GoRoute(
        path: '/qc/:id',
        builder: (_, state) => QcDetailScreen(inspectionId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/ms', builder: (_, __) => const MsListScreen()),
      GoRoute(
        path: '/ms/:id',
        builder: (_, state) => MsDetailScreen(assignmentId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/training', builder: (_, __) => const TrainingScreen()),
      GoRoute(path: '/schedule', builder: (_, __) => const ScheduleScreen()),
      GoRoute(
        path: '/f/:token',
        builder: (_, state) => MsFormScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(
          title: 'Banan · Nội bộ',
          subtitle: 'Đăng nhập bằng tài khoản quản trị (ADMIN).',
        ),
      ),
      GoRoute(
        path: '/wrong-app',
        builder: (_, __) => const WrongAppScreen(
          expected: 'Quản trị viên (ADMIN)',
          actual: 'Tài khoản của bạn không có quyền dùng ứng dụng nội bộ',
        ),
      ),
    ],
  );
});
