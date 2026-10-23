import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class AppSnackBar {
  AppSnackBar._();

  static OverlayEntry? _entry;

  static void hide() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }

  static void show(
    BuildContext context, {
    required Widget content,
    Key? key,
    Duration duration = AppDurations.snackBar,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    present(overlay, content: content, key: key, duration: duration);
  }

  static void present(
    OverlayState overlay, {
    required Widget content,
    Key? key,
    Duration duration = AppDurations.snackBar,
  }) {
    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final fill = (isDark ? AppColors.darkElevated : AppColors.charcoal)
            .withValues(alpha: 0.55);
        return IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _AppToast(
                  duration: duration,
                  onDone: hide,
                  child: Material(
                    key: key,
                    color: fill,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        child: _whiteText(content),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    _entry = entry;
    overlay.insert(entry);
  }
}

class _AppToast extends StatefulWidget {
  const _AppToast({
    required this.duration,
    required this.onDone,
    required this.child,
  });

  final Duration duration;
  final VoidCallback onDone;
  final Widget child;

  @override
  State<_AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<_AppToast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onDone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Widget _whiteText(Widget content) {
  if (content is Text) {
    final data = content.data;
    if (data != null) {
      return Text(
        data,
        key: content.key,
        textAlign: content.textAlign,
        maxLines: content.maxLines,
        overflow: content.overflow,
        softWrap: content.softWrap,
        style: const TextStyle(
          color: Colors.white,
        ).merge(content.style).copyWith(color: Colors.white),
      );
    }
  }
  return content;
}
