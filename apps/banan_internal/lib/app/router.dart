import 'package:banan_data/banan_data.dart';
import 'package:banan_domain/banan_domain.dart';
import 'package:banan_features_shared/banan_features_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';
import '../features/ms/ms_detail_screen.dart';
import '../features/ms/ms_list_screen.dart';
import '../features/ms_create/ms_create_screen.dart';
import '../features/public_form/ms_form_screen.dart';
import '../features/qc/qc_compare_screen.dart';
import '../features/qc/qc_detail_screen.dart';
import '../features/qc/qc_list_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/survey/admin/survey_cases_screen.dart';
import '../features/survey/admin/survey_editor_screen.dart';
import '../features/survey/admin/survey_link_screen.dart';
import '../features/survey/admin/survey_reports_screen.dart';
import '../features/survey/admin/survey_rewards_screen.dart';
import '../features/training/trainee_training_screen.dart';
import '../features/training/training_screen.dart';
import '../shared/save_file.dart';

/// The Mystery Shopper token never stays in the address bar: `/f/:token`
/// stashes it (memory + per-tab sessionStorage for refresh) and replaces the
/// URL with `/f`, so it can't leak via history, screenshots or referrers.
/// Every API call already carries it in the POST body only.
const _msTokenKey = 'banan_ms_token';
String? _msTokenMemory;

/// Per-GROUP access rules (deliberately not one "everything is ADMIN" rule):
///   /qc, /schedule, /ms, /survey* (admin area) → ADMIN
///   /training                                  → ADMIN or TRAINEE
///   /, /ms/create, /f, /f/:token               → public
/// The guest survey does NOT live here — it is served on the customer
/// domain (`<customerAppUrl>/survey`); Caddy 308-redirects the old
/// internal /survey link there. Every /survey* path in THIS app is admin.
/// Pure so tests can exercise the whole matrix without a widget tree.
/// Returns the location to redirect to, or null to stay.
String? internalRedirect({required Uri uri, required Role? role}) {
  final loc = uri.path;
  final loggedIn = role != null;

  if (loc == '/f' || loc.startsWith('/f/')) return null;
  if (loc == '/ms/create') return null;
  if (loc == '/' || loc == '') return null;

  if (loc == '/login') {
    if (!loggedIn) return null;
    // Back to what the user was heading for — same-app paths only, so a
    // crafted link can never bounce the session to a foreign domain.
    return sanitizeReturnTo(uri.queryParameters['returnTo']) ?? '/';
  }
  if (loc == '/wrong-app') return loggedIn ? null : '/';

  // Everything below requires a session.
  final requiredRoles = _requiredRolesFor(loc);
  if (!loggedIn) {
    return '/login?returnTo=${Uri.encodeComponent(loc)}';
  }
  if (!requiredRoles.contains(role)) return '/wrong-app';
  return null;
}

Set<Role> _requiredRolesFor(String loc) {
  if (loc == '/training' || loc.startsWith('/training/')) {
    return const {Role.admin, Role.trainee};
  }
  // /qc, /schedule, /ms and anything unlisted: admin only.
  return const {Role.admin};
}

/// Only same-app absolute paths survive: must start with a single '/'
/// (never '//host' protocol-relative) and carry no scheme.
String? sanitizeReturnTo(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (!raw.startsWith('/') || raw.startsWith('//')) return null;
  if (raw.contains('://')) return null;
  return raw;
}

final internalRouterProvider = Provider<GoRouter>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final refresh = GoRouterRefreshStream(repo.watchSession());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) =>
        internalRedirect(uri: state.uri, role: repo.currentSession?.user.role),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/qc', builder: (_, __) => const QcListScreen()),
      GoRoute(path: '/qc/compare', builder: (_, __) => const QcCompareScreen()),
      GoRoute(
        path: '/qc/:id',
        builder: (_, state) => QcDetailScreen(inspectionId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/ms', builder: (_, __) => const MsListScreen()),
      // Public employee link generator — must sit before /ms/:id.
      GoRoute(path: '/ms/create', builder: (_, __) => const MsCreateScreen()),
      GoRoute(
        path: '/ms/:id',
        builder: (_, state) => MsDetailScreen(assignmentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/training',
        builder: (context, _) {
          final repo = ref.read(authRepositoryProvider);
          final role = repo.currentSession?.user.role;
          return role == Role.trainee
              ? const TraineeTrainingScreen()
              : const TrainingScreen();
        },
      ),
      GoRoute(path: '/schedule', builder: (_, __) => const ScheduleScreen()),
      // The guest survey moved to the customer domain; a bare /survey here
      // (old bookmark that slipped past Caddy's 308) lands on the admin
      // reports — the redirect above has already demanded an ADMIN session.
      GoRoute(path: '/survey', redirect: (_, __) => '/survey/reports'),
      GoRoute(path: '/survey/reports', builder: (_, __) => const SurveyReportsScreen()),
      GoRoute(path: '/survey/editor', builder: (_, __) => const SurveyEditorScreen()),
      GoRoute(path: '/survey/link', builder: (_, __) => const SurveyLinkScreen()),
      GoRoute(path: '/survey/rewards', builder: (_, __) => const SurveyRewardsScreen()),
      GoRoute(path: '/survey/cases', builder: (_, __) => const SurveyCasesScreen()),
      // Secret-link entry: stash the token, strip it from the URL.
      GoRoute(
        path: '/f/:token',
        redirect: (_, state) {
          final token = state.pathParameters['token']!;
          _msTokenMemory = token;
          writeSessionValue(_msTokenKey, token);
          return '/f';
        },
      ),
      GoRoute(
        path: '/f',
        builder: (_, __) =>
            MsFormScreen(token: _msTokenMemory ?? readSessionValue(_msTokenKey) ?? ''),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(
          title: 'Banan · Nội bộ',
          subtitle: 'Đăng nhập bằng tài khoản được cấp (Admin hoặc Trainee).',
        ),
      ),
      GoRoute(
        path: '/wrong-app',
        builder: (_, __) => const WrongAppScreen(
          expected: 'Quản trị viên (ADMIN) — hoặc Trainee cho mục Đào tạo',
          actual: 'Tài khoản của bạn không có quyền vào khu vực này',
        ),
      ),
    ],
  );
});
