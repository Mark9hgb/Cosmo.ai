import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/chat_screen.dart';
import 'services/nvidia_nim_service.dart';
import 'utils/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(
    ProviderScope(
      overrides: [
        nvidiaNimServiceProvider.overrideWith(
          (ref) => NvidiaNimService.create(
            apiKey: ref.read(apiKeyProvider),
          ),
        ),
      ],
      child: const TermuxAIApp(),
    ),
  );
}

class TermuxAIApp extends ConsumerStatefulWidget {
  const TermuxAIApp({super.key});

  @override
  ConsumerState<TermuxAIApp> createState() => _TermuxAIAppState();
}

class _TermuxAIAppState extends ConsumerState<TermuxAIApp> {
  final _apiKeyController = TextEditingController();
  bool _isConfigured = false;
  
  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }
  
  Future<void> _checkApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString('nvidia_api_key');
    
    if (storedKey != null && storedKey.isNotEmpty) {
      ref.read(apiKeyProvider.notifier).state = storedKey;
      setState(() {
        _isConfigured = true;
      });
    }
  }
  
  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key')),
      );
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nvidia_api_key', key);
    
    ref.read(apiKeyProvider.notifier).state = key;
    
    setState(() {
      _isConfigured = true;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeStateProvider);
    
    final theme = themeState.mode == AppThemeMode.dark
      ? AppTheme.darkTheme(themeState.seedColor, glassOpacity: themeState.glassOpacity)
      : AppTheme.lightTheme(themeState.seedColor, glassOpacity: themeState.glassOpacity);
    
    return MaterialApp(
      title: 'AI Terminal Assistant',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: _isConfigured ? const ChatScreen() : _buildSetupScreen(),
    );
  }
  
  Widget _buildSetupScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.terminal,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'AI Terminal Assistant',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Powered by Nvidia NIM + Termux',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextField(
                    controller: _apiKeyController,
                    decoration: InputDecoration(
                      labelText: 'Nvidia API Key',
                      hintText: 'Enter your Nvidia NIM API key',
                      prefixIcon: const Icon(Icons.key),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveApiKey,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text('Get Started'),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Setup Instructions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionStep(
                    Icons.download,
                    'Install Termux from F-Droid',
                  ),
                  _buildInstructionStep(
                    Icons.settings,
                    'Set allow-external-apps = true in termux.properties',
                  ),
                  _buildInstructionStep(
                    Icons.key,
                    'Get your Nvidia API key from api.nvidia.com',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildInstructionStep(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }
}