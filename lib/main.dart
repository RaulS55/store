import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_AR');
  Intl.defaultLocale = 'es_AR';
  runApp(const ModaStockApp());
}

class ModaStockApp extends StatefulWidget {
  const ModaStockApp({super.key});

  @override
  State<ModaStockApp> createState() => _ModaStockAppState();
}

class _ModaStockAppState extends State<ModaStockApp> {
  late final AppStore _store;
  late final router = createRouter();

  @override
  void initState() {
    super.initState();
    _store = AppStore();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _store,
      child: Consumer<AppStore>(
        builder: (context, store, _) {
          return MaterialApp.router(
            title: 'Moda Stock',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: store.themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
