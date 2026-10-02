import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/session_store.dart';

bool canViewBusinessStats(BuildContext context) {
  return context.watch<SessionStore?>()?.canViewBusinessStats ?? false;
}
