import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/basket_provider.dart';
import 'services/store_settings_provider.dart';
import 'screens/scanner_screen.dart';
import 'screens/search_screen.dart';
import 'screens/basket_screen.dart';
import 'screens/stores_screen.dart';
import 'screens/about_github_screen.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/kupa_logo.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BasketProvider()),
        ChangeNotifierProvider(create: (_) => StoreSettingsProvider()),
      ],
      child: const KupaApp(),
    ),
  );
}

class KupaApp extends StatelessWidget {
  const KupaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<StoreSettingsProvider>();

    return MaterialApp(
      title: 'קופה • Kupa',
      debugShowCheckedModeBanner: false,
      themeMode: settings.flutterThemeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: const Color(0xFF2563EB),
        fontFamily: 'Rubik',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF2563EB),
        fontFamily: 'Rubik',
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: settings.isLoaded
          ? (settings.isOnboardingCompleted && settings.hasConfiguredChains
              ? const MainNavigationScreen()
              : const OnboardingScreen())
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ScannerScreen(),
    SearchScreen(),
    BasketScreen(),
    StoresScreen(),
    AboutGithubScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final basketCount = context.watch<BasketProvider>().count;
    final settings = context.watch<StoreSettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            KupaLogo(size: 32),
            SizedBox(width: 10),
            Text('קופה • Kupa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              settings.themeMode == AppThemeMode.system
                  ? Icons.brightness_auto
                  : (settings.themeMode == AppThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
              color: settings.themeMode == AppThemeMode.system ? Colors.blueAccent : null,
            ),
            tooltip: 'החלף מצב תצוגה',
            onPressed: () => settings.cycleThemeMode(),
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            selectedIcon: Icon(Icons.qr_code_scanner, color: Color(0xFF2563EB)),
            label: 'סורק',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search, color: Color(0xFF2563EB)),
            label: 'חיפוש',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: basketCount > 0,
              label: Text('$basketCount'),
              child: const Icon(Icons.shopping_basket_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: basketCount > 0,
              label: Text('$basketCount'),
              child: const Icon(Icons.shopping_basket, color: Color(0xFF2563EB)),
            ),
            label: 'סל',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: settings.myChains.isNotEmpty,
              label: Text('${settings.myChains.length}'),
              child: const Icon(Icons.storefront_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: settings.myChains.isNotEmpty,
              label: Text('${settings.myChains.length}'),
              child: const Icon(Icons.storefront, color: Color(0xFF2563EB)),
            ),
            label: 'הרשתות שלי',
          ),
          const NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info, color: Color(0xFF2563EB)),
            label: 'קוד פתוח',
          ),
        ],
      ),
    );
  }
}
