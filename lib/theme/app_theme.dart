import 'package:flutter/material.dart';

class SGColor {
  SGColor._();
  static const primary = Color(0xFF1565C0);
  static const primaryDark = Color(0xFF003C8F);
  static const bg = Color(0xFFF5F7FA);
  static const riskLow = Color(0xFF4CAF50);
  static const riskMid = Color(0xFFFF9800);
  static const riskHigh = Color(0xFFF44336);
  static const textPrimary = Color(0xFF1A237E);
  static const textSub = Color(0xFF546E7A);
  static const divider = Color(0xFFE0E0E0);
}

class SGText {
  SGText._();
  static const h1 = TextStyle(
      fontSize: 24, fontWeight: FontWeight.bold, color: SGColor.textPrimary);
  static const h2 = TextStyle(
      fontSize: 18, fontWeight: FontWeight.bold, color: SGColor.textPrimary);
  static const h3 = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w600, color: SGColor.textPrimary);
  static const body = TextStyle(fontSize: 14, color: SGColor.textSub);
  static const caption = TextStyle(fontSize: 12, color: SGColor.textSub);
  static const label = TextStyle(
      fontSize: 13, fontWeight: FontWeight.w600, color: SGColor.textPrimary);
}

class SGCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  const SGCard(
      {super.key, required this.child, this.padding, this.color, this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        color: color ?? Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
              padding: padding ?? const EdgeInsets.all(16), child: child),
        ),
      );
}

class RiskBadge extends StatelessWidget {
  final String riskLevel;
  const RiskBadge({super.key, required this.riskLevel});

  Color get _color => riskLevel == 'CAO'
      ? SGColor.riskHigh
      : riskLevel == 'TRUNG BÌNH'
          ? SGColor.riskMid
          : SGColor.riskLow;

  IconData get _icon => riskLevel == 'CAO'
      ? Icons.warning_rounded
      : riskLevel == 'TRUNG BÌNH'
          ? Icons.info_rounded
          : Icons.check_circle_rounded;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _color, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_icon, color: _color, size: 16),
          const SizedBox(width: 6),
          Text('Nguy cơ $riskLevel',
              style: TextStyle(
                  color: _color, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      );
}

ThemeData buildAppTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: SGColor.primary),
      scaffoldBackgroundColor: SGColor.bg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: SGColor.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: SGColor.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SGColor.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SGColor.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: SGColor.primary, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
    );
