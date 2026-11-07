import 'package:store_app/data/share_link_access.dart';

class FakeShareLinkAccess implements ShareLinkAccess {
  final links = <String, ProductShareLink>{};

  @override
  Future<ProductShareLink?> find(String code) async {
    return usableShareLink(links[code]);
  }

  @override
  Future<bool> create(ProductShareLink link) async {
    if (usableShareLink(link) == null || links.containsKey(link.code)) {
      return false;
    }
    links[link.code] = link;
    return true;
  }
}
