import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:web/web.dart' as web;

bool Function()? _onBack;

void configureWebHistory() {
  if (defaultTargetPlatform != TargetPlatform.android) {
    usePathUrlStrategy();
    return;
  }
  setUrlStrategy(AndroidWebHistoryStrategy());
}

void bindWebBackHandler(bool Function()? onBack) {
  _onBack = onBack;
}

/// Keeps the installed Android web app on one document.
///
/// Chrome reloads that app when the back button walks a path-URL history
/// entry. Route changes stay in Flutter and the system back pops them here.
class AndroidWebHistoryStrategy extends PathUrlStrategy {
  AndroidWebHistoryStrategy() {
    _lockedPath = getPath();
    _pushSameDocument();
    web.window.addEventListener('popstate', _onPopState.toJS);
  }

  late final String _lockedPath;
  var _handlingPop = false;

  void _pushSameDocument() {
    final location = web.window.location;
    web.window.history.pushState(
      null,
      '',
      '${location.pathname}${location.search}${location.hash}',
    );
  }

  void _onPopState(web.Event _) {
    if (_handlingPop) return;
    _handlingPop = true;
    final popped = _onBack?.call() ?? false;
    if (popped) _pushSameDocument();
    _handlingPop = false;
  }

  @override
  void pushState(Object? state, String title, String url) {
    super.replaceState(state, title, _lockedPath);
  }

  @override
  void replaceState(Object? state, String title, String url) {
    super.replaceState(state, title, _lockedPath);
  }

  @override
  Future<void> go(int count) async {}

  @override
  VoidCallback addPopStateListener(ui_web.PopStateListener fn) {
    return () {};
  }
}
