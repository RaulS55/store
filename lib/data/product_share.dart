import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../models/product.dart';
import '../models/share_code.dart';
import 'clipboard_copy.dart';
import 'firebase_bootstrap.dart';
import 'share_link_access.dart';

const _shareAttempts = 8;

String productShareUrl(String code) => 'https://$customAppHost/p/$code';

String productShareText({required String name, required String url}) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return url;
  return '$trimmed\n$url';
}

enum ProductShareOutcome { shared, copied, failed }

typedef ProductLinkSharer =
    Future<ProductShareOutcome> Function({
      required String text,
      required String url,
      required String title,
      Rect? sharePositionOrigin,
    });

Future<String?> ensureProductShareCode({
  required String companyId,
  required Product product,
  required ShareLinkAccess links,
  required Future<void> Function(Product product) saveProduct,
  Random? random,
  String Function()? nextCode,
}) async {
  final company = companyId.trim();
  final productId = product.id.trim();
  if (company.isEmpty || productId.isEmpty) return null;

  final existing = product.shareCode;
  if (existing != null && isShareCode(existing)) {
    final found = await links.find(existing);
    if (found == null) {
      final created = await links.create(
        ProductShareLink(
          code: existing,
          companyId: company,
          productId: productId,
        ),
      );
      if (created) return existing;
      final winner = await links.find(existing);
      if (winner != null && winner.matches(company, productId)) {
        return existing;
      }
    } else if (found.matches(company, productId)) {
      return existing;
    }
  }

  final randomCode = random ?? Random.secure();
  for (var attempt = 0; attempt < _shareAttempts; attempt++) {
    final code = nextCode?.call() ?? generateShareCode(randomCode);
    if (!isShareCode(code)) continue;
    if (await links.find(code) != null) continue;
    final created = await links.create(
      ProductShareLink(code: code, companyId: company, productId: productId),
    );
    if (!created) {
      final winner = await links.find(code);
      if (winner == null || !winner.matches(company, productId)) continue;
    }
    await saveProduct(product.copyWith(shareCode: code));
    return code;
  }
  return null;
}

/// Phones and tablets get the system share sheet. Desktop, including the
/// Mac browser, copies the link. Text sharing on desktop web opens Mail.
bool productLinkUsesShareSheet({TargetPlatform? platform}) {
  switch (platform ?? defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.android:
      return true;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}

Future<ProductShareOutcome> shareProductLink({
  required String text,
  required String url,
  required String title,
  Rect? sharePositionOrigin,
  bool? useShareSheet,
  Future<bool> Function(String url)? copy,
  Future<void> Function(ShareParams params)? share,
}) async {
  final write = copy ?? copyToClipboard;
  final sheet = useShareSheet ?? productLinkUsesShareSheet();
  if (!sheet) {
    final copied = await write(url);
    return copied ? ProductShareOutcome.copied : ProductShareOutcome.failed;
  }
  try {
    final params = ShareParams(
      text: text,
      title: title,
      sharePositionOrigin: sharePositionOrigin,
      mailToFallbackEnabled: false,
    );
    await (share ?? _shareSheet)(params);
    return ProductShareOutcome.shared;
  } catch (_) {
    final copied = await write(url);
    return copied ? ProductShareOutcome.copied : ProductShareOutcome.failed;
  }
}

Future<void> _shareSheet(ShareParams params) {
  return SharePlus.instance.share(params);
}
