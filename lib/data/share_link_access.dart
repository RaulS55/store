import '../models/share_code.dart';

class ProductShareLink {
  const ProductShareLink({
    required this.code,
    required this.companyId,
    required this.productId,
  });

  final String code;
  final String companyId;
  final String productId;

  bool matches(String companyId, String productId) {
    return this.companyId == companyId && this.productId == productId;
  }

  factory ProductShareLink.fromMap(String code, Map<String, dynamic> map) {
    return ProductShareLink(
      code: code,
      companyId: (map['companyId'] as String? ?? '').trim(),
      productId: (map['productId'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'companyId': companyId, 'productId': productId};
  }
}

abstract class ShareLinkAccess {
  Future<ProductShareLink?> find(String code);

  /// Returns false when [link.code] is already taken or is not a share code.
  Future<bool> create(ProductShareLink link);
}

bool _usable(ProductShareLink link) {
  return isShareCode(link.code) &&
      link.companyId.isNotEmpty &&
      link.productId.isNotEmpty;
}

ProductShareLink? usableShareLink(ProductShareLink? link) {
  if (link == null || !_usable(link)) return null;
  return link;
}
