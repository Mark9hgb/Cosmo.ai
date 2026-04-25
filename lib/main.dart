import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/nvidia_nim_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: CosmoApp()));
}

class CosmoApp extends ConsumerStatefulWidget {
  const CosmoApp({super.key});
  @override
  ConsumerState<CosmoApp> createState() => _CosmoAppState();
}

class _CosmoAppState extends ConsumerState<CosmoApp> {
  final _apiKey = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('nvidia_api_key');
    if (key != null && key.isNotEmpty) {
      ref.read(apiKeyProvider).state = key;
      setState(() => _ready = true);
    }
  }

  void _save() async {
    final key = _apiKey.text.trim();
    if (key.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nvidia_api_key', key);
    ref.read(apiKeyProvider).state = key;
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cosmo AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: _ready ? const HomeScreen() : Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.terminal, size: 64), const SizedBox(height: 24), const Text('Cosmo AI', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)), const SizedBox(height: 48), TextField(controller: _apiKey, obscureText: true, decoration: const InputDecoration(labelText: 'API Key', prefixIcon: Icon(Icons.key))), const SizedBox(height: 16), ElevatedButton(onPressed: _save, child: const Text('Continue'))])))),
    );
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }
}