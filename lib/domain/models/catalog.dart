// Canonical Domain Models entry point.
//
// The clean, immutable catalog models live in lib/models/catalog.dart
// (Catalog, Category, Brand, ComboGroup, SearchHit). Per the
// flutter-apply-architecture-best-practices skill, Views and ViewModels must
// depend on domain models rather than raw API maps, so new layered code
// imports this barrel file. It re-exports the models so there is exactly
// one class definition (no duplication, no type conflicts) while the
// codebase migrates toward domain/ imports.
export '../../models/catalog.dart';
