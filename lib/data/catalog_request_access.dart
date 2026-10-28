import '../models/catalog_request.dart';

abstract class CatalogRequestAccess {
  String nextRequestId(String companyId);

  Stream<List<CatalogRequest>> watchRequests(String companyId);

  Stream<CatalogRequest?> watchRequest(String companyId, String requestId);

  Future<CatalogRequest?> readRequest(String companyId, String requestId);

  Future<void> saveRequest(String companyId, CatalogRequest request);

  /// Writes only the given fields. Resolving a request must not replace the
  /// document: rewriting lines or dates fails the security rules, so the
  /// request stays pending and shows up again after a reload.
  Future<void> updateRequest(
    String companyId,
    String requestId,
    Map<String, Object?> data,
  );
}
