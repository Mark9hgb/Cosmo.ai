import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/ai_model.dart';
import 'services/nvidia_nim_service.dart';
import 'utils/theme_provider.dart';

final selectedModelProvider = StateProvider<AiModel>((ref) => AiModel.defaultModels.first);

class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedModel = ref.watch(selectedModelProvider);
    final themeState = ref.watch(themeStateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('AI Model', theme),
          const SizedBox(height: 12),
          _buildModelSelector(context, ref, selectedModel),
          const SizedBox(height: 24),
          _buildSectionTitle('Appearance', theme),
          const SizedBox(height: 12),
          _buildThemeSelector(context, ref, themeState),
          const SizedBox(height: 24),
          _buildSectionTitle('API Configuration', theme),
          const SizedBox(height: 12),
          _buildApiConfig(context),
          const SizedBox(height: 24),
          _buildSectionTitle('About', theme),
          const SizedBox(height: 12),
          _buildAbout(context),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
  }

  Widget _buildModelSelector(BuildContext context, WidgetRef ref, AiModel selectedModel) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select AI Model', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6), fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedModel.id,
                isExpanded: true,
                items: AiModel.defaultModels.map((model) {
                  return DropdownMenuItem(
                    value: model.id,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(model.displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(model.description, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    final model = AiModel.defaultModels.firstWhere((m) => m.id == value);
                    ref.read(selectedModelProvider.notifier).state = model;
                    _saveSelectedModel(model);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, WidgetRef ref, ThemeState themeState) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildThemeOption(context, ref, AppThemeMode.light, Icons.light_mode, 'Light', themeState),
              const SizedBox(width: 12),
              _buildThemeOption(context, ref, AppThemeMode.dark, Icons.dark_mode, 'Dark', themeState),
              const SizedBox(width: 12),
              _buildThemeOption(context, ref, AppThemeMode.system, Icons.auto_mode, 'System', themeState),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, WidgetRef ref, AppThemeMode mode, IconData icon, String label, ThemeState themeState) {
    final theme = Theme.of(context);
    final isSelected = themeState.mode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(themeStateProvider.notifier).setMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface.withOpacity(0.6)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: isSelected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface.withOpacity(0.6))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApiConfig(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.key, color: theme.colorScheme.primary),
            title: const Text('API Key'),
            subtitle: const Text('NVIDIA API Key'),
            trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showApiKeyDialog(context, ref)),
          ),
        ],
      ),
    );
  }

  Widget _buildAbout(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.tertiary]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.terminal, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cosmo AI', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Version 1.0.1', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('AI-powered terminal assistant with Nvidia NIM integration.', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  void _showApiKeyDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Key'),
        content: TextField(controller: controller, obscureText: true, decoration: const InputDecoration(labelText: 'NVIDIA API Key')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('nvidia_api_key', controller.text);
                ref.read(apiKeyProvider.notifier).state = controller.text;
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSelectedModel(AiModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_model', model.id);
  }
}

class CommandMemoryView extends StatelessWidget {
  const CommandMemoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Command Memory', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('No commands executed yet', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
            ),
          ),
        ],
      ),
    );
  }
}