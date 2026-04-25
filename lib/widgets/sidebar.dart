import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../screens/home_screen.dart';

class CosmoSidebar extends ConsumerWidget {
  const CosmoSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);
    final sidebarExpanded = ref.watch(sidebarExpandedProvider);
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: sidebarExpanded ? 240 : 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          _buildLogo(context, theme),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _NavItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  isSelected: selectedTab == 0,
                  onTap: () => ref.read(selectedTabProvider.notifier).state = 0,
                ),
                _NavItem(
                  icon: Icons.terminal,
                  label: 'Terminal',
                  isSelected: selectedTab == 1,
                  onTap: () => ref.read(selectedTabProvider.notifier).state = 1,
                ),
                _NavItem(
                  icon: Icons.history,
                  label: 'Memory',
                  isSelected: selectedTab == 2,
                  onTap: () => ref.read(selectedTabProvider.notifier).state = 2,
                ),
                _NavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  isSelected: selectedTab == 3,
                  onTap: () => ref.read(selectedTabProvider.notifier).state = 3,
                ),
              ],
            ),
          ),
          _buildUserInfo(context, theme),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context, ThemeData theme) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.terminal, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Cosmo',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: theme.colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest User',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Free Plan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(target: isSelected ? 1 : 0).scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
        );
  }
}