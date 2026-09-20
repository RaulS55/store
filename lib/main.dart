import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'data/catalog_bindings.dart';
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
import 'data/local/catalog_cart_cache.dart';
import 'data/local/hive_bootstrap.dart';
import 'data/session_store.dart';
import 'features/auth/loading_page.dart';
import 'firebase_options.dart';
import 'models/company.dart';
import 'routing/app_entry.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_logo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final entryLocation = appEntryLocation();
  usePathUrlStrategy();
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  runApp(ModaStockApp(entryLocation: entryLocation));
}

class ModaStockApp extends StatefulWidget {
  const ModaStockApp({super.key, this.entryLocation = '/'});

  final String entryLocation;

  @override
  State<ModaStockApp> createState() => _ModaStockAppState();
}

class _ModaStockAppState extends State<ModaStockApp> {
  AppStore? _store;
  SessionStore? _session;
  CatalogBindings? _catalog;
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
    CatalogBindings? catalog;
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
      final imageCache = await openProductImageCache();
      final cartCache = HiveCatalogCartCache();
      await cartCache.ensureOpen();
      step = 'tienda';
      final companyAccess = FirestoreCompanyAccess();
      final productAccess = FirestoreProductAccess();
      final customerAccess = FirestoreCustomerAccess();
      final orderAccess = FirestoreOrderAccess();
      store = AppStore(
        products: CachedProductAccess(remote: productAccess, cache: cache),
        customers: CachedCustomerAccess(remote: customerAccess, cache: cache),
        orderAccess: CachedOrderAccess(remote: orderAccess, cache: cache),
        lotAccess: CachedLotAccess(remote: FirestoreLotAccess(), cache: cache),
        images: FirebaseImageAccess(),
        imageCache: imageCache,
      );
      session = SessionStore(auth: FirebaseAuthClient(), access: companyAccess);
      catalog = CatalogBindings(
        companies: companyAccess,
        products: CachedProductAccess(
          remote: productAccess,
          cache: cache,
          publicSafe: true,
        ),
        customers: customerAccess,
        orders: orderAccess,
        cart: cartCache,
        images: imageCache,
      );
      session.addListener(_bindCatalog);
      session.start();
      step = 'navegación';
      final entry = widget.entryLocation.trim().isEmpty
          ? '/'
          : widget.entryLocation;
      final router = createRouter(
        session,
        initialLocation: entry,
        overridePlatformDefaultLocation: entry != '/',
      );
      if (!mounted) {
        session.removeListener(_bindCatalog);
        session.dispose();
        catalog.dispose();
        store.dispose();
        return;
      }
      setState(() {
        _store = store;
        _session = session;
        _catalog = catalog;
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
        catalog?.dispose();
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
    _catalog?.dispose();
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    final session = _session;
    final catalog = _catalog;
    final router = _router;
    if (store == null || session == null || catalog == null || router == null) {
      return MaterialApp(
        title: 'Moda Stock',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _bootFailed
            ? _BootErrorPage(detail: _bootError, onRetry: _retryBoot)
            : const LoadingPage(),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: session),
        Provider.value(value: catalog),
        Provider.value(value: store.imageCache),
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
