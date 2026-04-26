# Clean Architecture Migration

## Current State (March 14, 2026)
The repository is now organized by feature and layer under `lib/features/*`:

- `presentation`: screens/providers.
- `domain`: repository contracts + use-cases.
- `data`: repository implementations + data sources/models.
- `core`: shared DI/services/providers.

The project composes dependencies from a single composition root:
- `lib/core/di/app_dependencies.dart`

All broken post-refactor imports were fixed and the project now analyzes/tests successfully.

## What Is Already Enforced

### 1. Layered Dependency Flow
Main flow used in runtime:

`presentation -> domain(use-cases) -> domain(repository contracts) -> data(repository impl) -> core/services`

### 2. Architecture Guard Script
A repository guard is available at:

- `tool/check_architecture.ps1`

It fails if presentation/domain code directly uses:
- `DatabaseService`
- `sqflite`
- `SharedPreferences`

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tool/check_architecture.ps1
```

### 3. Import Stability
Legacy broken import paths were normalized, which removed major compile failures caused by mixed old/new folder structures.

## Remaining Gaps To Reach “Strict” Clean Architecture

1. Domain still depends on some data models (e.g. `WaridModel`, `SadirModel`, `UserModel`) in multiple features.
2. `DatabaseService` is still a large monolithic infrastructure service.
3. Error handling mainly throws generic exceptions instead of typed domain failures.

## Recommended Next Iteration Plan

1. Introduce pure domain entities per feature (`domain/entities`) and mapping in data layer.
2. Split `DatabaseService` into bounded data sources:
   - auth/user datasource
   - warid/sadir datasource
   - ocr datasource
   - audit/history datasource
3. Add `Result/Failure` domain primitives and replace ad-hoc exception strings.
4. Add unit tests for use-cases and repository adapters with fake repositories.
5. Add CI step to run:
   - `dart analyze`
   - `flutter test`
   - `tool/check_architecture.ps1`

## Definition of Done for Full Migration
Project is considered fully migrated when:

- no domain file imports any `data/*` model/type.
- presentation only talks to use-cases/entities (no infrastructure leakage).
- infrastructure split into feature-scoped data sources.
- architecture guard and tests run clean in CI.
