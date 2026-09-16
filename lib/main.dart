import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'data/firebase_auth_client.dart';
import 'data/firebase_bootstrap.dart';
import 'data/firebase_image_access.dart';
import 'data/firestore_company_access.dart';
import 'data/firestore_customer_access.dart';
import 'data/firestore_order_access.dart';
import 'data/firestore_product_access.dart';
import 'data/session_store.dart';
import 'features/auth/loading_page.dart';
import 'firebase_options.dart';
import 'models/company.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  runApp(const ModaStockApp());
}

class ModaStockApp extends StatefulWidget {
  const ModaStockApp({super.key});

  @override
  State<ModaStockApp> createState() => _ModaStockAppState();
}

class _ModaStockAppState extends State<ModaStockApp> {
  AppStore? _store;
  SessionStore? _session;
  GoRouter? _router;
  var _bootFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    try {
      await initializeDateFormatting('es_AR');
      Intl.defaultLocale = 'es_AR';
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await configureFirebaseForPlatform();
      final store = AppStore(
        products: FirestoreProductAccess(),
        customers: FirestoreCustomerAccess(),
        orderAccess: FirestoreOrderAccess(),
        images: FirebaseImageAccess(),
      );
      final session = SessionStore(
        auth: FirebaseAuthClient(),
        access: FirestoreCompanyAccess(),
      );
      session.addListener(_bindCatalog);
      session.start();
      final router = createRouter(session);
      if (!mounted) {
        session.removeListener(_bindCatalog);
        session.dispose();
        store.dispose();
        return;
      }
      setState(() {
        _store = store;
        _session = session;
        _router = router;
        _bootFailed = false;
      });
      _bindCatalog();
    } catch (_) {
      if (mounted) setState(() => _bootFailed = true);
    }
  }

  void _bindCatalog() {
    final store = _store;
    final session = _session;
    if (store == null || session == null) return;
    store.bindCompany(session.isSignedIn ? session.companyId : null);
    store.setRubro(session.company?.rubro ?? CompanyRubro.ambos);
  }

  @override
  void dispose() {
    _session?.removeListener(_bindCatalog);
    _session?.dispose();
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final session = _session;
    final router = _router;
    if (store == null || session == null || router == null) {
      return MaterialApp(
        title: 'Moda Stock',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _bootFailed
            ? _BootErrorPage(
                onRetry: () {
                  setState(() => _bootFailed = false);
                  unawaited(_boot());
                },
              )
            : const LoadingPage(),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: session),
      ],
      child: Consumer<AppStore>(
        builder: (context, appStore, _) {
          return MaterialApp.router(
            title: 'Moda Stock',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: appStore.themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}

class _BootErrorPage extends StatelessWidget {
  const _BootErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(),
            const SizedBox(height: 16),
            const Text('No se pudo iniciar la app.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
