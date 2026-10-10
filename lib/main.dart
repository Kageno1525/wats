import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WatsApp());
}

class WatsApp extends StatefulWidget {
  const WatsApp({super.key});
  @override
  State<WatsApp> createState() => _WatsAppState();
}

class _WatsAppState extends State<WatsApp> {
  ThemeMode _mode = ThemeMode.dark;

  void _toggle() => setState(
      () => _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wats',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomePage(
        isDark: _mode == ThemeMode.dark,
        onToggleTheme: _toggle,
      ),
      builder: (context, child) {
        return DefaultTextStyle(
          style: const TextStyle(
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
          ),
          child: child!,
        );
      },
    );
  }
}

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF25D366),
    brightness: b,
  );
  final base =
      ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  final clean = base.textTheme.apply(
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  return base.copyWith(
    scaffoldBackgroundColor:
        b == Brightness.dark ? const Color(0xFF0B0B14) : const Color(0xFFF5F6FB),
    textTheme: clean,
    primaryTextTheme: clean,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: b == Brightness.dark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.03),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      labelStyle: TextStyle(
        color: scheme.onSurface.withOpacity(0.6),
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
      hintStyle: TextStyle(
        color: scheme.onSurface.withOpacity(0.4),
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
    ),
  );
}