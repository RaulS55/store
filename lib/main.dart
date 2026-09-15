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
import 'data/firestore_product_access.dart';
import 'data/session_store.dart';
import 'firebase_options.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_AR');
  Intl.defaultLocale = 'es_AR';
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  configureFirebaseForPlatform();
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
    _store = AppStore(
      products: FirestoreProductAccess(),
      images: FirebaseImageAccess(),
    );
    _session = SessionStore(
      auth: FirebaseAuthClient(),
      access: FirestoreCompanyAccess(),
    );
    _session.addListener(_bindCatalog);
    _session.start();
    _bindCatalog();
    _router = createRouter(_session);
  }

  void _bindCatalog() {
    _store.bindCompany(_session.companyId);
  }

  @override
  void dispose() {
    _session.removeListener(_bindCatalog);
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
