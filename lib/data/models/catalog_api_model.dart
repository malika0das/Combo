// Raw API models barrel: currently the bundled catalog JSON schema matches
// the domain 1:1, so parsing is delegated to Domain Models.
// If the server schema ever diverges, add diverging DTO fields here and keep
// lib/models/catalog.dart clean.
export '../../models/catalog.dart';
export '../services/catalog_api_service.dart';
