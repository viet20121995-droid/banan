# 04 — Packages

Pin to latest stable on `pub.dev` / npm at scaffold time. Versions below are floors, not ceilings.

## Flutter — root tooling

| Tool | Why |
|---|---|
| Flutter `>= 3.22` (stable) | Material 3, RecordTypes, dart_define_from_file. |
| Dart `>= 3.4` | Records + patterns + sealed classes for `Result`. |
| `melos` | Monorepo orchestration. |
| `very_good_analysis` | Strong, opinionated lint set. |
| `build_runner` | Code generation host. |

## Per-package — runtime

| Package | Where | Why |
|---|---|---|
| `flutter_riverpod`, `riverpod_annotation` | apps + features_shared | State management. |
| `go_router` | apps | Declarative routing + deep links. |
| `freezed_annotation`, `json_annotation` | domain, data, features | Immutable models + JSON. |
| `dio` | data | HTTP. Interceptors are critical for auth. |
| `socket_io_client` | data | WebSocket transport (matches NestJS gateway). |
| `flutter_secure_storage` | data | Token storage in Keychain / Keystore / Web Crypto. |
| `hive_ce`, `hive_ce_flutter` | data | Local cache (offline mode for customer app). |
| `cached_network_image` | design_system | Image cache, placeholder, retry. |
| `intl` | core, design_system, apps | i18n + currency formatting. |
| `google_fonts` | design_system | (Or self-host Cormorant + Inter for web perf.) |
| `fl_chart` | design_system | Dashboard charts. |
| `flutter_form_builder`, `form_builder_validators` | design_system | Form scaffolding. |
| `responsive_framework` *or* hand-rolled | design_system | We use hand-rolled `BreakpointBuilder` to keep control. |
| `firebase_core`, `firebase_messaging` | features_shared | Push only — no Auth, no Firestore. |
| `flutter_stripe` | features_shared (customer-only) | Stripe payment sheet on mobile; on web we use Stripe.js via JS interop. |
| `url_launcher` | features_shared | VNPay / MoMo redirect flow on web. |
| `app_links` | features_shared | Deep-link callbacks from VNPay / MoMo on mobile. |
| `equatable` | domain | Value-object equality (alternative to freezed for tiny VOs). |
| `collection`, `rxdart` | data | List utilities + reactive streams (WS multiplex). |
| `logging` | core | Logger interface; sinks per environment. |
| `sentry_flutter` *(optional)* | apps | Crash + perf in production. |

## Per-package — dev

| Package | Why |
|---|---|
| `build_runner` | Codegen runner. |
| `freezed`, `json_serializable`, `riverpod_generator` | Generators. |
| `mocktail` | Test doubles for repository / use case tests. |
| `golden_toolkit` *(optional)* | Visual regression for design_system widgets. |
| `flutter_test`, `integration_test` | Tests. |

## Backend — NestJS

| Package | Why |
|---|---|
| `@nestjs/core`, `@nestjs/common`, `@nestjs/platform-express` | Framework. |
| `@nestjs/config` | Strongly-typed env. |
| `@nestjs/jwt`, `@nestjs/passport`, `passport`, `passport-jwt`, `bcrypt` | Auth. |
| `@nestjs/websockets`, `@nestjs/platform-socket.io`, `socket.io` | Realtime. |
| `@nestjs/swagger` | API docs. |
| `@nestjs/throttler` | Rate limiting. |
| `@nestjs/schedule` | Cron jobs (scheduled-order release, loyalty expiry). |
| `@nestjs/terminus` | Health checks. |
| `prisma`, `@prisma/client` | DB. |
| `class-validator`, `class-transformer` | DTO validation. |
| `bullmq`, `ioredis`, `@nestjs/bullmq` | Queues — payments retry, kitchen routing, push fan-out. |
| `nestjs-pino`, `pino`, `pino-pretty` | Logging. |
| `stripe` | Stripe SDK. |
| `firebase-admin` | FCM push from server. |
| `aws-sdk` (`@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`) | Pre-signed image uploads. |
| `helmet`, `compression`, `cookie-parser` | Hardening + perf. |
| `argon2` *(optional alt to bcrypt)* | Stronger password hashing. |
| `nanoid` | Order code generation. |

### Backend dev

| Package | Why |
|---|---|
| `typescript`, `ts-node`, `tsx` | TS toolchain. |
| `eslint`, `prettier`, `@typescript-eslint/*` | Lint + format. |
| `jest`, `@nestjs/testing`, `supertest` | Tests. |
| `prisma`'s built-in seed runner | DB seeding. |

## What we explicitly chose **not** to use

| Rejected | Why |
|---|---|
| Firebase Auth | Conflicts with our role/JWT design and adds vendor lock-in across 3 apps. |
| Firestore | Bad fit for relational orders/refunds/loyalty. |
| GetX / Provider | Riverpod 2 is the modern, type-safe choice; mixing state libs adds friction. |
| auto_route | go_router is now the official-blessed router; integrates with web URLs cleanly. |
| Bloc | Valid but heavier boilerplate. Riverpod controllers cover the same ground for this app. |
