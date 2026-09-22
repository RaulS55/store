import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'data/local/hive_catalog_cache.dart';
import 'data/session_cache.dart';
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
  final imageCache = PaintingBinding.instance.imageCache;
  imageCache.maximumSize = 250;
  imageCache.maximumSizeBytes = 120 << 20;
  final entryLocation = appEntryLocation();
  usePathUrlStrategy();
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  runApp(ModaStockApp(entryLocation: entryLocation));
}

const _localizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

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
  var _booting = false;
  final _bootStatus = ValueNotifier<_BootStatus>(const _BootStatus.loading());

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
      final cacheFuture = openEncryptedCatalogCache();
      unawaited(_showCachedCatalogBrand(cacheFuture));
      step = 'firebase';
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await configureFirebaseForPlatform();
      step = 'cache';
      final cache = await cacheFuture;
      if (!cache.persistent) {
        debugPrint('Catalog cache is in-memory; reload will hit the API');
      }
      final imageCache = await openProductImageCache();
      final cartCache = HiveCatalogCartCache();
      await cartCache.ensureOpen();
      step = 'tienda';
      final companyAccess = FirestoreCompanyAccess();
      await _primeCatalogBrand(companyAccess, cache);
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
      session = SessionStore(
        auth: FirebaseAuthClient(),
        access: companyAccess,
        cache: HiveSessionCache(cache),
      );
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
        local: cache,
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
        _bootStatus.value = _BootStatus.failed('$step: $error');
      }
    } finally {
      _booting = false;
    }
  }

  Future<void> _showCachedCatalogBrand(
    Future<HiveCatalogCache> cacheFuture,
  ) async {
    final companyId = catalogCompanyIdFromLocation(widget.entryLocation);
    if (companyId == null) return;
    try {
      final cache = await cacheFuture;
      if (!mounted || _router != null) return;
      _showCatalogBrand(cache.loadCompany(companyId));
    } catch (error, stack) {
      debugPrint('Catalog brand cache failed: $error');
      debugPrint('$stack');
    }
  }

  Future<void> _primeCatalogBrand(
    FirestoreCompanyAccess companies,
    HiveCatalogCache cache,
  ) async {
    final companyId = catalogCompanyIdFromLocation(widget.entryLocation);
    if (companyId == null) return;
    final cached = cache.loadCompany(companyId);
    _showCatalogBrand(cached);
    if (cached != null) return;
    try {
      final remote = await companies
          .getCompany(companyId)
          .timeout(const Duration(seconds: 8));
      if (remote == null) return;
      await cache.saveCompany(remote);
      _showCatalogBrand(remote);
    } catch (error, stack) {
      debugPrint('Catalog brand prefetch failed: $error');
      debugPrint('$stack');
    }
  }

  void _showCatalogBrand(Company? company) {
    if (company == null || !mounted || _router != null) return;
    final logo = blankToNull(company.logoUrl);
    final name = blankToNull(company.name);
    if (logo == null && name == null) return;
    _bootStatus.value = _BootStatus.loading(logoUrl: logo, companyName: name);
  }

  void _retryBoot() {
    if (_booting) return;
    _bootStatus.value = const _BootStatus.loading();
    unawaited(_boot());
  }

  Route<void> _bootRoute(String? name) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: name),
      builder: (_) => _BootScreen(status: _bootStatus, onRetry: _retryBoot),
    );
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
    _bootStatus.dispose();
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
        locale: const Locale('es', 'AR'),
        supportedLocales: const [Locale('es', 'AR'), Locale('es')],
        localizationsDelegates: _localizationsDelegates,
        theme: AppTheme.light(),
        onGenerateRoute: (settings) => _bootRoute(settings.name),
        onGenerateInitialRoutes: (initialRoute) => [_bootRoute(initialRoute)],
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
            locale: const Locale('es', 'AR'),
            supportedLocales: const [Locale('es', 'AR'), Locale('es')],
            localizationsDelegates: _localizationsDelegates,
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

class _BootStatus {
  const _BootStatus.loading({this.logoUrl, this.companyName})
    : detail = null,
      failed = false;

  const _BootStatus.failed(this.detail)
    : failed = true,
      logoUrl = null,
      companyName = null;

  final bool failed;
  final String? detail;
  final String? logoUrl;
  final String? companyName;
}

class _BootScreen extends StatelessWidget {
  const _BootScreen({required this.status, required this.onRetry});

  final ValueListenable<_BootStatus> status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_BootStatus>(
      valueListenable: status,
      builder: (context, view, _) {
        if (!view.failed) {
          return LoadingPage(
            logoUrl: view.logoUrl,
            companyName: view.companyName,
          );
        }
        return _BootErrorPage(detail: view.detail, onRetry: onRetry);
      },
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
