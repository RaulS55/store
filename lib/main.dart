import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'data/firebase_auth_client.dart';
import 'data/firestore_company_access.dart';
import 'data/session_store.dart';
import 'firebase_options.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_AR');
  Intl.defaultLocale = 'es_AR';
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ModaStockApp());
}

class ModaStockApp extends StatefulWidget {
  const ModaStockApp({super.key});

  @override
  State<ModaStockApp> createState() => _ModaStockAppState();
}

class _ModaStockAppState extends State<ModaStockApp> {
  late final AppStore _store;
  late final SessionStore _session;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _store = AppStore();
    _session = SessionStore(
      auth: FirebaseAuthClient(),
      access: FirestoreCompanyAccess(),
    )..start();
    _router = createRouter(_session);
  }

  @override
  void dispose() {
    _session.dispose();
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _store),
        ChangeNotifierProvider.value(value: _session),
      ],
      child: Consumer<AppStore>(
        builder: (context, store, _) {
          return MaterialApp.router(
            title: 'Moda Stock',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: store.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
