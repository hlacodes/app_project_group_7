import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/admin_screens.dart';
import 'screens/alerts_screen.dart';
import 'screens/auth_screens.dart';
import 'screens/report_screens.dart';
import 'screens/settings_screen.dart';
import 'screens/utility_screens.dart';
import 'services/safepark_store.dart';
import 'utils/theme_constants.dart';
import 'widgets/shared_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await SafeParkStore.load();
  runApp(SafeParkApp(store: store));
}

class SafeParkApp extends StatefulWidget {
  final SafeParkStore store;
  const SafeParkApp({super.key, required this.store});

  @override
  State<SafeParkApp> createState() => _SafeParkAppState();
}

class _SafeParkAppState extends State<SafeParkApp> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => widget.store.runEscalationTick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final pal = kPalettes[widget.store.paletteIndex];
        final isDark = widget.store.darkMode;
        final bg = isDark ? const Color(0xFF1B1715) : const Color(0xFFEBE3D8);
        final surface = isDark ? const Color(0xFF26201D) : const Color(0xFFFAF6F1);
        final card = isDark ? const Color(0xFF2F2825) : const Color(0xFFFFFDFA);
        final ink = isDark ? const Color(0xFFF3ECE4) : const Color(0xFF3A2F2B);
        final line = isDark ? const Color(0xFF433A35) : const Color(0xFFE6DCCF);

        return Directionality(
          textDirection: widget.store.arabic ? TextDirection.rtl : TextDirection.ltr,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: widget.store.appName,
            theme: ThemeData(
              useMaterial3: true,
              brightness: isDark ? Brightness.dark : Brightness.light,
              colorScheme: ColorScheme(
                brightness: isDark ? Brightness.dark : Brightness.light,
                primary: pal.pri,
                onPrimary: Colors.white,
                secondary: pal.priDark,
                onSecondary: Colors.white,
                error: const Color(0xFFB5574D),
                onError: Colors.white,
                surface: surface,
                onSurface: ink,
              ),
              scaffoldBackgroundColor: bg,
              cardColor: card,
              dividerColor: line,
            ),
            home: MainShell(store: widget.store),
          ),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  final SafeParkStore store;
  const MainShell({super.key, required this.store});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  String _route = 'welcome';
  String _problemCarCode = 'CAR-1234';
  bool _aiOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.store.currentUser != null) _route = 'report';
  }

  void _go(String r, {String? carCode}) {
    if (carCode != null) _problemCarCode = carCode;
    setState(() {
      _route = r;
      if (const ['admin', 'adminlogin', 'welcome', 'login', 'signup'].contains(r)) _aiOpen = false;
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }

  bool get _showMainTabs => const ['report', 'alerts', 'emergency', 'nearby', 'pricing'].contains(_route);
  bool get _showGear => const ['report', 'alerts', 'emergency', 'nearby', 'pricing', 'settings'].contains(_route);
  bool get _showAiFab => _showGear;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final pal = kPalettes[s.paletteIndex];
    final screenBg = s.darkMode ? const Color(0xFF26201D) : const Color(0xFFFAF6F1);

    return Scaffold(
      backgroundColor: screenBg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildCurrentView(pal)),
            if (_showGear)
              Positioned(
                top: 10,
                right: s.arabic ? null : 14,
                left: s.arabic ? 14 : null,
                child: Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 2,
                  child: IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 20),
                    tooltip: tr('settings', s.arabic, 'Settings'),
                    onPressed: () => _go('settings'),
                  ),
                ),
              ),
            if (_showAiFab)
              Positioned(
                right: s.arabic ? null : 16,
                left: s.arabic ? 16 : null,
                bottom: 84,
                child: FloatingActionButton(
                  heroTag: 'safepark_ai_fab',
                  backgroundColor: pal.pri,
                  foregroundColor: Colors.white,
                  onPressed: () => setState(() => _aiOpen = !_aiOpen),
                  child: Icon(_aiOpen ? Icons.close : Icons.smart_toy_outlined),
                ),
              ),
            if (_aiOpen && _showAiFab)
              Positioned(
                left: 12,
                right: 12,
                top: 56,
                bottom: 80,
                child: AiAssistantPanel(store: s, onClose: () => setState(() => _aiOpen = false)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _showMainTabs
          ? Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: NavigationBar(
                  height: 62,
                  backgroundColor: const Color(0xF028221F),
                  indicatorColor: Colors.white.withValues(alpha: 0.2),
                  selectedIndex: const ['report', 'alerts', 'emergency', 'nearby', 'pricing'].indexOf(_route).clamp(0, 4),
                  onDestinationSelected: (idx) => _go(const ['report', 'alerts', 'emergency', 'nearby', 'pricing'][idx]),
                  destinations: [
                    NavigationDestination(icon: const Icon(Icons.qr_code_scanner, color: Colors.white70), selectedIcon: const Icon(Icons.qr_code_scanner, color: Colors.white), label: tr('report_car', s.arabic, 'Report')),
                    NavigationDestination(icon: AlertsNavIcon(count: s.unreadAlertsCount, selected: false), selectedIcon: AlertsNavIcon(count: s.unreadAlertsCount, selected: true), label: tr('alerts', s.arabic, 'Alerts')),
                    NavigationDestination(icon: const Icon(Icons.emergency_outlined, color: Colors.white70), selectedIcon: const Icon(Icons.emergency, color: Colors.white), label: tr('emergency', s.arabic, 'Emergency')),
                    NavigationDestination(icon: const Icon(Icons.explore_outlined, color: Colors.white70), selectedIcon: const Icon(Icons.explore, color: Colors.white), label: tr('nearby', s.arabic, 'Nearby')),
                    NavigationDestination(icon: const Icon(Icons.sell_outlined, color: Colors.white70), selectedIcon: const Icon(Icons.sell, color: Colors.white), label: tr('pricing', s.arabic, 'Pricing')),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildCurrentView(PaletteOption pal) {
    switch (_route) {
      case 'welcome':
        return WelcomeView(
          store: widget.store,
          pal: pal,
          onPickRole: (role) {
            widget.store.selectedRole = role;
            widget.store.persist();
            _toast(role == 'student' ? 'Student mode' : 'Guest mode');
            _go('login');
          },
          onAdminLogin: () => _go('adminlogin'),
        );
      case 'login':
        return LoginView(
          store: widget.store,
          pal: pal,
          onBack: () => _go('welcome'),
          onGoSignup: () => _go('signup'),
          onSuccess: (name) { _toast('Welcome, $name'); _go('report'); },
          onToast: _toast,
        );
      case 'signup':
        return SignupView(
          store: widget.store,
          pal: pal,
          onBack: () => _go('login'),
          onSuccess: () { _toast('Account created'); _go('report'); },
        );
      case 'adminlogin':
        return AdminLoginView(
          store: widget.store,
          pal: pal,
          onBackToDriver: () => _go('login'),
          onSuccess: () { _toast('Welcome, admin'); _go('admin'); },
        );
      case 'admin':
        return AdminDashboardView(store: widget.store, pal: pal, onLeave: () => _go('welcome'), onToast: _toast);
      case 'problem':
        return ProblemView(
          store: widget.store,
          pal: pal,
          carCode: _problemCarCode,
          onBack: () => _go('report'),
          onSent: (notified) { _toast(notified ? 'Owner notified' : 'Report sent (no registered owner yet)'); _go('alerts'); },
          onToast: _toast,
        );
      case 'alerts':
        return AlertsView(store: widget.store, pal: pal, onToast: _toast);
      case 'emergency':
        return EmergencyView(store: widget.store, pal: pal, onToast: _toast);
      case 'nearby':
        return NearbyView(store: widget.store, pal: pal, onToast: _toast);
      case 'pricing':
        return PricingView(store: widget.store, pal: pal, onToast: _toast);
      case 'settings':
        return SettingsView(
          store: widget.store,
          pal: pal,
          onBackToApp: () => _go('report'),
          onLoggedOut: () { _toast('You are logged out'); _go('welcome'); },
          onToast: _toast,
        );
      case 'report':
      default:
        return ReportView(store: widget.store, pal: pal, onContinueCode: (code) => _go('problem', carCode: code), onToast: _toast);
    }
  }
}
