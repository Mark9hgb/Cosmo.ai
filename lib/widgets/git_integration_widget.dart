import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/git_models.dart';
import '../services/git_service.dart';
import '../services/terminal_service.dart';
import 'glass_container.dart';

class GitIntegrationWidget extends ConsumerStatefulWidget {
  final Function(String)? onCommandGenerated;
  
  const GitIntegrationWidget({
    super.key,
    this.onCommandGenerated,
  });
  
  @override
  ConsumerState<GitIntegrationWidget> createState() => _GitIntegrationWidgetState();
}

class _GitIntegrationWidgetState extends ConsumerState<GitIntegrationWidget> {
  bool _showHistory = false;
  
  @override
  Widget build(BuildContext context) {
    final gitState = ref.watch(gitServiceProvider);
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 16),
          if (gitState.currentRepository == null)
            _buildNoRepoState(theme)
          else ...[
            _buildRepoStatus(gitState.currentRepository!, theme),
            const SizedBox(height: 16),
            _buildQuickActions(gitState.currentRepository!, theme),
            const SizedBox(height: 16),
            _buildBranchSelector(gitState, theme),
            const SizedBox(height: 16),
            _buildStatusPanel(gitState, theme),
          ],
          if (gitState.repositories.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildRepoList(gitState, theme),
          ],
          if (gitState.operations.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildOperationHistory(gitState, theme),
          ],
        ],
      ),
    );
  }
  
  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.source, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          'Git Integration',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(_showHistory ? Icons.history : Icons.history_outlined),
          onPressed: () => setState(() => _showHistory = !_showHistory),
          tooltip: 'Toggle History',
        ),
      ],
    );
  }
  
  Widget _buildNoRepoState(ThemeData theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 16,
      child: Column(
        children: [
          Icon(
            Icons.folder_off,
            size: 48,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No Repository Selected',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Initialize a new repo or clone an existing one',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showInitDialog(),
                icon: const Icon(Icons.create_new_folder),
                label: const Text('Initialize'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showCloneDialog(),
                icon: const Icon(Icons.download),
                label: const Text('Clone'),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRepoStatus(GitRepository repo, ThemeData theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 12,
      child: Row(
        children: [
          Icon(Icons.folder, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  repo.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  repo.path,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildStatusBadge(repo, theme),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
  
  Widget _buildStatusBadge(GitRepository repo, ThemeData theme) {
    final hasChanges = repo.hasUncommittedChanges;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasChanges 
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasChanges ? Icons.edit : Icons.check,
            size: 14,
            color: hasChanges 
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            hasChanges ? 'Changes' : 'Clean',
            style: TextStyle(
              fontSize: 12,
              color: hasChanges 
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions(GitRepository repo, ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _QuickActionButton(
          icon: Icons.add,
          label: 'Stage',
          onPressed: () => _stageAll(repo),
          color: theme.colorScheme.primary,
        ),
        _QuickActionButton(
          icon: Icons.check,
          label: 'Commit',
          onPressed: repo.stagedChanges > 0 ? () => _showCommitDialog(repo) : null,
          color: theme.colorScheme.primary,
        ),
        _QuickActionButton(
          icon: Icons.cloud_upload,
          label: 'Push',
          onPressed: repo.hasRemote ? () => _push(repo) : null,
          color: theme.colorScheme.tertiary,
        ),
        _QuickActionButton(
          icon: Icons.cloud_download,
          label: 'Pull',
          onPressed: repo.hasRemote ? () => _pull(repo) : null,
          color: theme.colorScheme.tertiary,
        ),
        _QuickActionButton(
          icon: Icons.sync,
          label: 'Fetch',
          onPressed: () => _fetch(repo),
          color: theme.colorScheme.secondary,
        ),
        _QuickActionButton(
          icon: Icons.swap_horiz,
          label: 'Checkout',
          onPressed: () => _showCheckoutDialog(repo),
          color: theme.colorScheme.secondary,
        ),
      ],
    );
  }
  
  Widget _buildBranchSelector(GitServiceState state, ThemeData theme) {
    final repo = state.currentRepository;
    if (repo == null) return const SizedBox.shrink();
    
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      borderRadius: 12,
      child: Row(
        children: [
          Icon(Icons.account_tree, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: repo.currentBranch,
                isExpanded: true,
                items: repo.branches.map((branch) {
                  return DropdownMenuItem(
                    value: branch,
                    child: Text(branch),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && value != repo.currentBranch) {
                    _checkout(repo, value);
                  }
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => _showNewBranchDialog(repo),
            tooltip: 'New Branch',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusPanel(GitServiceState state, ThemeData theme) {
    final terminal = TerminalService.instance;
    
    return FutureBuilder<GitStatus>(
      future: state.currentRepository != null 
        ? ref.read(gitServiceProvider.notifier).getRepositoryStatus(state.currentRepository!.path)
        : Future.value(const GitStatus()),
      builder: (context, snapshot) {
        final status = snapshot.data ?? const GitStatus();
        
        return GlassContainer(
          padding: const EdgeInsets.all(12),
          borderRadius: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Changes',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _buildChangeCount('Modified', status.modified.length, Icons.edit, theme),
              _buildChangeCount('Staged', status.staged.length, Icons.add_circle, theme),
              _buildChangeCount('Untracked', status.untracked.length, Icons.help_outline, theme),
              _buildChangeCount('Deleted', status.deleted.length, Icons.remove_circle, theme),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildChangeCount(String label, int count, IconData icon, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: count > 0 ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: count > 0 
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: count > 0 
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRepoList(GitServiceState state, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repositories',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...state.repositories.map((repo) {
          final isActive = state.currentRepository?.path == repo.path;
          
          return ListTile(
            leading: Icon(
              Icons.folder,
              color: isActive ? theme.colorScheme.primary : null,
            ),
            title: Text(repo.name),
            subtitle: Text(repo.currentBranch),
            selected: isActive,
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'set_active',
                  child: const Text('Set Active'),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: const Text('Remove'),
                ),
              ],
              onSelected: (value) {
                if (value == 'set_active') {
                  ref.read(gitServiceProvider.notifier).setCurrentRepository(repo);
                } else if (value == 'remove') {
                  ref.read(gitServiceProvider.notifier).removeRepository(repo.path);
                }
              },
            ),
            onTap: () {
              ref.read(gitServiceProvider.notifier).setCurrentRepository(repo);
            },
          ).animate().fadeIn(delay: (50 * state.repositories.indexOf(repo)).ms);
        }),
      ],
    );
  }
  
  Widget _buildOperationHistory(GitServiceState state, ThemeData theme) {
    if (!_showHistory) return const SizedBox.shrink();
    
    final recentOps = state.operations.take(10).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Operations',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...recentOps.map((op) {
          return ListTile(
            leading: Icon(
              op.isRunning ? Icons.sync : (op.exitCode == 0 ? Icons.check_circle : Icons.error),
              color: op.isRunning 
                ? theme.colorScheme.primary
                : (op.exitCode == 0 ? Colors.green : Colors.red),
            ),
            title: Text(op.type.displayName),
            subtitle: Text(op.output ?? op.error ?? ''),
            trailing: op.isRunning 
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ).animate(onPlay: (c) => c.repeat()).rotate()
              : null,
          );
        }),
      ],
    );
  }
  
  void _showInitDialog() {
    final pathController = TextEditingController();
    final remoteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Initialize Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'Path',
                hintText: '/path/to/repo',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remoteController,
              decoration: const InputDecoration(
                labelText: 'Remote URL (optional)',
                hintText: 'https://github.com/user/repo.git',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (pathController.text.isNotEmpty) {
                ref.read(gitServiceProvider.notifier).initRepository(
                  pathController.text,
                  remoteUrl: remoteController.text.isNotEmpty ? remoteController.text : null,
                );
              }
            },
            child: const Text('Initialize'),
          ),
        ],
      ),
    );
  }
  
  void _showCloneDialog() {
    final urlController = TextEditingController();
    final pathController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clone Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Repository URL',
                hintText: 'https://github.com/user/repo.git',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              decoration: const InputDecoration(
                labelText: 'Target Path',
                hintText: '/path/to/clone',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (urlController.text.isNotEmpty && pathController.text.isNotEmpty) {
                ref.read(gitServiceProvider.notifier).cloneRepository(
                  urlController.text,
                  pathController.text,
                );
              }
            },
            child: const Text('Clone'),
          ),
        ],
      ),
    );
  }
  
  void _showCommitDialog(GitRepository repo) {
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commit Changes'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            labelText: 'Commit Message',
            hintText: 'Your commit message',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (messageController.text.isNotEmpty) {
                ref.read(gitServiceProvider.notifier).commit(messageController.text);
              }
            },
            child: const Text('Commit'),
          ),
        ],
      ),
    );
  }
  
  void _showCheckoutDialog(GitRepository repo) async {
    final branches = await ref.read(gitServiceProvider.notifier).getBranches(repo.path);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Checkout Branch'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: branches.length,
            itemBuilder: (context, index) {
              final branch = branches[index];
              return ListTile(
                leading: Icon(branch.isCurrent ? Icons.check : Icons.account_tree),
                title: Text(branch.name),
                selected: branch.isCurrent,
                onTap: branch.isCurrent ? null : () {
                  Navigator.pop(context);
                  ref.read(gitServiceProvider.notifier).checkout(branch.name);
                },
              );
            },
          ),
        ),
      ),
    );
  }
  
  void _showNewBranchDialog(GitRepository repo) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Branch'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Branch Name',
            hintText: 'feature/new-feature',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (nameController.text.isNotEmpty) {
                ref.read(gitServiceProvider.notifier).checkout(nameController.text, createNew: true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  void _stageAll(GitRepository repo) {
    ref.read(gitServiceProvider.notifier).stageFile(repo.path, stageAll: true);
  }
  
  void _push(GitRepository repo) {
    ref.read(gitServiceProvider.notifier).push();
  }
  
  void _pull(GitRepository repo) {
    ref.read(gitServiceProvider.notifier).pull();
  }
  
  void _fetch(GitRepository repo) {
    ref.read(gitServiceProvider.notifier).stageFile('git fetch', stageAll: true);
  }
  
  void _checkout(GitRepository repo, String branch) {
    ref.read(gitServiceProvider.notifier).checkout(branch);
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  
  const _QuickActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onPressed != null;
    
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Material(
        color: isEnabled ? color.withOpacity(0.1) : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: isEnabled ? color : theme.colorScheme.onSurface.withOpacity(0.4)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isEnabled ? color : theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(target: isEnabled ? 1 : 0).scale(begin: const Offset(0.95, 0.95));
  }
}