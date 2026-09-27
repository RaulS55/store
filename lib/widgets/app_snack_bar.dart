import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class AppSnackBar extends SnackBar {
  const AppSnackBar({
    super.key,
    required super.content,
    super.behavior,
    super.duration = AppDurations.snackBar,
  });
}
