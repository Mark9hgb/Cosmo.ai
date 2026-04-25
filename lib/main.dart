import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/ai_model.dart';
import 'screens/home_screen.dart';
import 'services/nvidia_nim_service.dart';
import 'services/terminal_service.dart';
import 'utils/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(
    ProviderScope(
      overrides: [
        nvidiaNimServiceProvider.overrideWith(
          (ref) => NvidiaNimService.create(apiKey: ref.read(apiKeyProvider)),
        ),
        terminalServiceProvider.overrideWith((ref) => TerminalService.instance),
      ],
      child: const CosmoApp(),
    ),
  );
}

class CosmoApp extends ConsumerStatefulWidget {
  const CosmoApp({super.key});

  @override
  ConsumerState<CosmoApp> createState() => _CosmoAppState();
}

class _CosmoAppState extends ConsumerState<CosmoApp> {
  final _apiKeyController = TextEditingController();
  bool _isConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkConfiguration();
  }

  Future<void> _checkConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString('nvidia_api_key');
    if (storedKey != null && storedKey.isNotEmpty) {
      ref.read(apiKeyProvider.notifier).state = storedKey;
      setState(() => _isConfigured = true);
    }
  }

  Future<void> _saveConfiguration() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an API key')));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nvidia_api_key', key);
    ref.read(apiKeyProvider.notifier).state = key;
    setState(() => _isConfigured = true);
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeStateProvider);
    final theme = themeState.mode == AppThemeMode.dark
        ? AppTheme.darkTheme(themeState.seedColor)
        : AppTheme.lightTheme(themeState.seedColor);

    return MaterialApp(
      title: 'Cosmo AI',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: _isConfigured ? const HomeScreen() : _buildSetupScreen(),
    );
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A1A1A)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                _buildLogo(),
                const SizedBox(height: 48),
                _buildInputField(),
                const SizedBox(height: 16),
                _buildGetStartedButton(),
                const SizedBox(height: 32),
                _buildSetupGuide(),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.tertiary],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.terminal, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 20),
        Text('Cosmo AI', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Terminal AI Assistant', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white60)),
      ],
    );
  }

  Widget _buildInputField() {
    return TextField(
      controller: _apiKeyController,
      obscureText: true,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Nvidia API Key',
        hintText: 'Enter your API key',
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: const Icon(Icons.key, color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveConfiguration,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Get Started', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildSetupGuide() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Setup Guide', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildStep(Icons.download, 'Install Termux from F-Droid'),
          _buildStep(Icons.settings, 'Set allow-external-apps = true'),
          _buildStep(Icons.key, 'Get API key from build.nvidia.com'),
        ],
      ),
    );
  }

  Widget _buildStep(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Icon(icon, size: 16, color: Colors.white54), const SizedBox(width: 12), Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13))]),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}