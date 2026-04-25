import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeState {
  final AppThemeMode mode;
  final ColorSeed seedColor;
  final Color? customPrimary;
  final Color? customBackground;
  final double glassOpacity;
  final double glassBlur;
  final bool enableAnimations;
  final double animationSpeed;
  
  const ThemeState({
    this.mode = AppThemeMode.system,
    this.seedColor = ColorSeed.blue,
    this.customPrimary,
    this.customBackground,
    this.glassOpacity = 0.1,
    this.glassBlur = 10,
    this.enableAnimations = true,
    this.animationSpeed = 1.0,
  });
  
  ThemeState copyWith({
    AppThemeMode? mode,
    ColorSeed? seedColor,
    Color? customPrimary,
    Color? customBackground,
    double? glassOpacity,
    double? glassBlur,
    bool? enableAnimations,
    double? animationSpeed,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      seedColor: seedColor ?? this.seedColor,
      customPrimary: customPrimary ?? this.customPrimary,
      customBackground: customBackground ?? this.customBackground,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      glassBlur: glassBlur ?? this.glassBlur,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      animationSpeed: animationSpeed ?? this.animationSpeed,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'seedColor': seedColor.name,
    'customPrimary': customPrimary?.value,
    'customBackground': customBackground?.value,
    'glassOpacity': glassOpacity,
    'glassBlur': glassBlur,
    'enableAnimations': enableAnimations,
    'animationSpeed': animationSpeed,
  };
  
  factory ThemeState.fromJson(Map<String, dynamic> json) => ThemeState(
    mode: AppThemeMode.values.firstWhere(
      (e) => e.name == json['mode'],
      orElse: () => AppThemeMode.system,
    ),
    seedColor: ColorSeed.values.firstWhere(
      (e) => e.name == json['seedColor'],
      orElse: () => ColorSeed.blue,
    ),
    customPrimary: json['customPrimary'] != null 
      ? Color(json['customPrimary'] as int) 
      : null,
    customBackground: json['customBackground'] != null 
      ? Color(json['customBackground'] as int) 
      : null,
    glassOpacity: json['glassOpacity'] as double? ?? 0.1,
    glassBlur: json['glassBlur'] as double? ?? 10,
    enableAnimations: json['enableAnimations'] as bool? ?? true,
    animationSpeed: json['animationSpeed'] as double? ?? 1.0,
  );
}

enum ColorSeed { blue, purple, teal, orange, pink, green }

extension ColorSeedExtension on ColorSeed {
  Color get color {
    switch (this) {
      case ColorSeed.blue:
        return const Color(0xFF2196F3);
      case ColorSeed.purple:
        return const Color(0xFF9C27B0);
      case ColorSeed.teal:
        return const Color(0xFF009688);
      case ColorSeed.orange:
        return const Color(0xFFFF9800);
      case ColorSeed.pink:
        return const Color(0xFFE91E63);
      case ColorSeed.green:
        return const Color(0xFF4CAF50);
    }
  }
}

final themeStateProvider = StateNotifierProvider<ThemeStateNotifier, ThemeState>((ref) {
  return ThemeStateNotifier();
});

class ThemeStateNotifier extends StateNotifier<ThemeState> {
  ThemeStateNotifier() : super(const ThemeState()) {
    _loadTheme();
  }
  
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('theme_mode');
    final seedColorStr = prefs.getString('theme_seed_color');
    final glassOpacity = prefs.getDouble('theme_glass_opacity');
    final glassBlur = prefs.getDouble('theme_glass_blur');
    
    if (modeStr != null) {
      state = state.copyWith(
        mode: AppThemeMode.values.firstWhere(
          (e) => e.name == modeStr,
          orElse: () => AppThemeMode.system,
        ),
      );
    }
    
    if (seedColorStr != null) {
      state = state.copyWith(
        seedColor: ColorSeed.values.firstWhere(
          (e) => e.name == seedColorStr,
          orElse: () => ColorSeed.blue,
        ),
      );
    }
    
    if (glassOpacity != null) {
      state = state.copyWith(glassOpacity: glassOpacity);
    }
    
    if (glassBlur != null) {
      state = state.copyWith(glassBlur: glassBlur);
    }
  }
  
  Future<void> setMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    state = state.copyWith(mode: mode);
  }
  
  Future<void> setSeedColor(ColorSeed seed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_seed_color', seed.name);
    state = state.copyWith(seedColor: seed);
  }
  
  Future<void> setGlassOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('theme_glass_opacity', opacity);
    state = state.copyWith(glassOpacity: opacity);
  }
  
  Future<void> setGlassBlur(double blur) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('theme_glass_blur', blur);
    state = state.copyWith(glassBlur: blur);
  }
  
  Future<void> setCustomPrimary(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_custom_primary', color.value);
    state = state.copyWith(customPrimary: color);
  }
  
  Future<void> toggleAnimations() async {
    state = state.copyWith(enableAnimations: !state.enableAnimations);
  }
  
  Future<void> setAnimationSpeed(double speed) async {
    state = state.copyWith(animationSpeed: speed);
  }
  
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('theme_mode');
    await prefs.remove('theme_seed_color');
    await prefs.remove('theme_glass_opacity');
    await prefs.remove('theme_glass_blur');
    await prefs.remove('theme_custom_primary');
    
    state = const ThemeState();
  }
}

class AppTheme {
  static ThemeData lightTheme(ColorSeed seed, {double glassOpacity = 0.1}) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed.color,
        brightness: Brightness.light,
      ),
    );
    
    return _buildTheme(base, glassOpacity);
  }
  
  static ThemeData darkTheme(ColorSeed seed, {double glassOpacity = 0.1}) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed.color,
        brightness: Brightness.dark,
      ),
    );
    
    return _buildTheme(base, glassOpacity);
  }
  
  static ThemeData _buildTheme(ThemeData base, double glassOpacity) {
    return base.copyWith(
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: base.colorScheme.surfaceContainerHighest.withOpacity(glassOpacity + 0.1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.colorScheme.surfaceContainerHighest.withOpacity(glassOpacity + 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: base.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: base.colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: base.colorScheme.primary,
        unselectedLabelColor: base.colorScheme.onSurface.withOpacity(0.6),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: base.colorScheme.outline.withOpacity(0.2),
        thickness: 1,
      ),
    );
  }
}

class ThemePreviewCard extends StatelessWidget {
  final ColorSeed seed;
  final bool isDark;
  final VoidCallback onTap;
  
  const ThemePreviewCard({
    super.key,
    required this.seed,
    required this.isDark,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = isDark ? darkTheme(seed) : lightTheme(seed);
    final primary = theme.colorScheme.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 70,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary,
              primary.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white24,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            isDark ? 'Dark' : 'Light',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}