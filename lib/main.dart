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
import 'data/firestore_lot_access.dart';
import 'data/firestore_order_access.dart';
import 'data/firestore_product_access.dart';
import 'data/local/cached_customer_access.dart';
import 'data/local/cached_lot_access.dart';
import 'data/local/cached_order_access.dart';
import 'data/local/cached_product_access.dart';
import 'data/local/hive_bootstrap.dart';
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
  var _booting = false;
  String? _bootError;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    if (_booting) return;
    _booting = true;
    AppStore? store;
    SessionStore? session;
    var step = 'inicio';
    try {
      step = 'idioma';
      await initializeDateFormatting('es_AR');
      Intl.defaultLocale = 'es_AR';
      step = 'firebase';
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await configureFirebaseForPlatform();
      step = 'cache';
      final cache = await openEncryptedCatalogCache();
      step = 'tienda';
      store = AppStore(
        products: CachedProductAccess(
          remote: FirestoreProductAccess(),
          cache: cache,
        ),
        customers: CachedCustomerAccess(
          remote: FirestoreCustomerAccess(),
          cache: cache,
        ),
        orderAccess: CachedOrderAccess(
          remote: FirestoreOrderAccess(),
          cache: cache,
        ),
        lotAccess: CachedLotAccess(remote: FirestoreLotAccess(), cache: cache),
        images: FirebaseImageAccess(),
      );
      session = SessionStore(
        auth: FirebaseAuthClient(),
        access: FirestoreCompanyAccess(),
      );
      session.addListener(_bindCatalog);
      session.start();
      step = 'navegación';
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
        _bootError = null;
      });
      try {
        _bindCatalog();
      } catch (error, stack) {
        debugPrint('Catalog bind failed: $error');
        debugPrint('$stack');
      }
    } catch (error, stack) {
      debugPrint('Boot failed at $step: $error');
      debugPrint('$stack');
      if (!identical(_store, store)) {
        session?.removeListener(_bindCatalog);
        session?.dispose();
        store?.dispose();
      }
      if (mounted && _store == null) {
        setState(() {
          _bootFailed = true;
          _bootError = '$step: $error';
        });
      }
    } finally {
      _booting = false;
    }
  }

  void _retryBoot() {
    if (_booting) return;
    setState(() {
      _bootFailed = false;
      _bootError = null;
    });
    unawaited(_boot());
  }

  void _bindCatalog() {
    final store = _store;
    final session = _session;
    if (store == null || session == null) return;
    store.bindCompany(
      session.isSignedIn ? session.companyId : null,
      watchLots: session.canManageLots,
    );
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
      // Web uses the URL as initialRoute; this boot app has no named routes.
      return MaterialApp(
        title: 'Moda Stock',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (context, child) {
          if (_bootFailed) {
            return _BootErrorPage(detail: _bootError, onRetry: _retryBoot);
          }
          return const LoadingPage();
        },
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const SizedBox.shrink(),
          );
        },
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: session),
      ],
      child: Selector<AppStore, ThemeMode>(
        selector: (_, store) => store.themeMode,
        builder: (context, themeMode, _) {
          return MaterialApp.router(
            title: 'Moda Stock',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode,
            routerConfig: router,
          );
        },
      ),
    );
  }
}

class _BootErrorPage extends StatelessWidget {
  const _BootErrorPage({required this.onRetry, this.detail});

  final VoidCallback onRetry;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final detailText = detail?.trim();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandLogo(),
              const SizedBox(height: 16),
              const Text('No se pudo iniciar la app.'),
              if (detailText != null && detailText.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  detailText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}
