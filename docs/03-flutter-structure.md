# 03 — Flutter Project Structure

Monorepo managed by [Melos](https://melos.invertase.dev/). Three apps share four packages.

```
banan/
├── melos.yaml
├── apps/
│   ├── banan_customer/
│   ├── banan_merchant/
│   └── banan_kitchen/
└── packages/
    ├── core/
    ├── design_system/
    ├── domain/
    ├── data/
    └── features_shared/
```

## Per-app layout (Clean Architecture, feature-first)

```
apps/banan_customer/
├── pubspec.yaml
├── lib/
│   ├── main.dart                  # bootstrap → runApp(BananCustomerApp())
│   ├── app/
│   │   ├── banan_customer_app.dart
│   │   ├── router.dart            # go_router config
│   │   ├── theme.dart             # passes design_system tokens to MaterialApp
│   │   └── env.dart               # build-time config (--dart-define)
│   └── features/
│       ├── home/
│       │   ├── domain/
│       │   │   ├── entities/
│       │   │   ├── repositories/   # abstract
│       │   │   └── usecases/
│       │   ├── data/
│       │   │   ├── dtos/
│       │   │   ├── mappers/
│       │   │   └── repositories/   # impl
│       │   └── presentation/
│       │       ├── controllers/    # Riverpod notifiers
│       │       ├── widgets/
│       │       └── home_screen.dart
│       ├── menu/
│       ├── product_detail/
│       ├── cart/
│       ├── checkout/
│       ├── orders/
│       ├── tracking/
│       ├── membership/
│       └── profile/
├── ios/  android/  web/  windows/  macos/  linux/
└── test/
```

> The same shape applies to `banan_merchant` (features: `dashboard`, `menu_mgmt`, `orders_mgmt`, `refunds`, `kitchen_transfer`, `analytics`) and `banan_kitchen` (features: `queue`, `production_board`, `dispatch`, `analytics`).

## Shared packages

### `packages/core`

```
lib/
└── src/
    ├── env/                # Env class with all dart-define keys
    ├── result/result.dart  # sealed Result<T, F> (Success | Failure)
    ├── failures/           # AuthFailure, NetworkFailure, ValidationFailure, ...
    ├── extensions/         # context, num, datetime, string
    ├── logger/             # `package:logging` setup + Sentry sink
    └── ids.dart            # OrderCode, Money value objects
```

### `packages/design_system`

```
lib/
└── src/
    ├── tokens/
    │   ├── colors.dart      # luxury pastel palette (primary cream, accent rose, deep cocoa)
    │   ├── spacing.dart     # 4-pt scale
    │   ├── typography.dart  # display/serif (Cormorant) + UI sans (Inter)
    │   ├── radii.dart
    │   └── shadows.dart
    ├── theme/
    │   ├── light_theme.dart
    │   └── dark_theme.dart
    ├── responsive/
    │   ├── breakpoints.dart
    │   └── breakpoint_builder.dart
    └── widgets/
        ├── buttons/         # PrimaryButton, GhostButton, IconButton
        ├── inputs/          # AppTextField, AppDropdown, AppDatePicker
        ├── cards/           # ProductCard, OrderCard, StatCard
        ├── feedback/        # AppToast, EmptyState, ErrorState, Skeleton
        ├── dialogs/         # ConfirmDialog, BottomSheetX
        ├── data_table/      # AppDataTable (responsive, sortable)
        ├── kanban/          # KanbanBoard, KanbanColumn, KanbanCard
        ├── charts/          # RevenueChart, PeakHoursChart
        └── layout/          # AppScaffold, NavRail, BottomNav
```

### `packages/domain`

Pure Dart, no Flutter imports.

```
lib/
└── src/
    ├── entities/            # User, Product, Order, OrderItem, Refund, ...
    ├── value_objects/       # Money, Phone, EmailAddress, OrderCode
    ├── repositories/        # AuthRepository, ProductRepository, OrderRepository, ...
    └── usecases/            # PlaceOrderUseCase, CancelOrderUseCase, ...
```

Repositories return `Future<Result<T, Failure>>`. No exceptions cross the domain boundary.

### `packages/data`

```
lib/
└── src/
    ├── api/
    │   ├── dio_client.dart       # creates Dio with base URL + interceptors
    │   ├── interceptors/
    │   │   ├── auth_interceptor.dart   # attaches access token, refreshes on 401
    │   │   ├── logging_interceptor.dart
    │   │   └── error_mapper_interceptor.dart
    │   └── endpoints.dart        # const strings, single source of truth
    ├── ws/
    │   └── socket_client.dart    # socket_io_client wrapper, reconnect, room mgmt
    ├── dtos/                     # one per API entity, freezed + json_serializable
    ├── mappers/                  # DTO ↔ Domain Entity
    ├── repositories/             # impls of domain interfaces
    ├── local/
    │   ├── secure_storage.dart   # tokens
    │   └── cache.dart            # hive_ce wrapper
    └── di.dart                   # Riverpod providers wiring everything
```

### `packages/features_shared`

Auth, profile, notifications — used by all three apps with thin per-app skinning.

```
lib/
└── src/
    ├── auth/
    │   ├── login_screen.dart
    │   ├── register_screen.dart
    │   └── auth_controller.dart
    ├── notifications/
    │   ├── notifications_screen.dart
    │   └── push_handler.dart        # FCM init, foreground / background routing
    └── profile/
        ├── profile_screen.dart
        └── profile_controller.dart
```

## State management — Riverpod conventions

- Use `riverpod_generator` (`@riverpod` annotation) for type-safe providers.
- One **controller** per screen (`AsyncNotifier`) holding the page's view-state as a freezed class.
- Data flows: **UseCase ← Repository ← API/WS** (DI'd as Riverpod providers).
- Side-effects (snackbars, navigation) are listened to with `ref.listen`, not embedded in the controller.
- Never call repositories from widgets directly — always through a controller or use case.

## Routing — go_router conventions

- One `GoRouter` per app, defined in `app/router.dart`.
- Nested `ShellRoute` for the bottom nav (customer) or nav rail (dashboards).
- Auth redirect logic centralized in a `redirect:` callback that reads the auth provider.
- Deep-link paths: `/order/:id` (customer tracking), `/payments/return/vnpay`, `/payments/return/momo`.

## Responsiveness

- `BreakpointBuilder(builder: (ctx, bp) { ... })` for major layout switches.
- Customer app: phone-first; on web/tablet, content max-width 720 with side gutters.
- Merchant/Kitchen: dashboard expects ≥ `md`; on phones we render a "Use a tablet or larger" splash with the same data in a stripped read-only view.

## Localization

- `flutter_localizations` + `intl`.
- `lib/l10n/app_en.arb`, `app_vi.arb` per app.
- Money formatted with `NumberFormat.currency(locale: 'vi_VN', symbol: '₫')`.
- All user-facing strings go through `AppLocalizations.of(context)` — **no string literals in widgets**.

## Theming — light + dark + brand

- Single source of truth in `design_system/tokens`.
- `MaterialApp.themeMode = ThemeMode.system` by default; user can override in profile.
- Brand: cream background `#FAF6F1`, primary rose `#C9405C`, deep cocoa `#3B2A22`, gold accent `#C7A24A`.
- Display font: **Cormorant Garamond** (serif, premium feel). UI font: **Inter**.
