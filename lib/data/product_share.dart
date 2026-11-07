import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'clipboard_copy.dart';

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
