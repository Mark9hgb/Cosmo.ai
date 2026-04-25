import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:equatable/equatable.dart';
import 'dart:convert';
import '../models/git_models.dart';
import 'terminal_service.dart';

class GitServiceState extends Equatable {
  final List<GitRepository> repositories;
  final List<GitOperation> operations;
  final GitRepository? currentRepository;
  final bool isLoading;
  final String? error;
  
  const GitServiceState({
    this.repositories = const [],
    this.operations = const [],
    this.currentRepository,
    this.isLoading = false,
    this.error,
  });
  
  GitServiceState copyWith({
    List<GitRepository>? repositories,
    List<GitOperation>? operations,
    GitRepository? currentRepository,
    bool? isLoading,
    String? error,
  }) {
    return GitServiceState(
      repositories: repositories ?? this.repositories,
      operations: operations ?? this.operations,
      currentRepository: currentRepository ?? this.currentRepository,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
  
  @override
  List<Object?> get props => [repositories, operations, currentRepository, isLoading, error];
}

class GitService extends StateNotifier<GitServiceState> {
  final TerminalService _terminal;
  final Ref _ref;
  
  GitService(this._terminal, this._ref) : super(const GitServiceState()) {
    _loadSavedRepos();
  }
  
  Future<void> _loadSavedRepos() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRepos = prefs.getStringList('git_repositories');
    
    if (savedRepos != null) {
      final repos = savedRepos.map((json) {
        final parts = json.split('|');
        return GitRepository(
          path: parts[0],
          name: parts[1],
          currentBranch: parts[2],
          lastCommit: DateTime.tryParse(parts[3]) ?? DateTime.now(),
        );
      }).toList();
      
      state = state.copyWith(repositories: repos);
    }
  }
  
  Future<void> _saveRepos() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = state.repositories.map((repo) {
      return '${repo.path}|${repo.name}|${repo.currentBranch}|${repo.lastCommit.toIso8601String()}';
    }).toList();
    
    await prefs.setStringList('git_repositories', serialized);
  }
  
  Future<GitRepository?> initRepository(String path, {String? remoteUrl}) async {
    try {
      final initCmd = 'cd "$path" && git init';
      await _terminal.executeCommand(initCmd);
      
      if (remoteUrl != null) {
        final remoteCmd = 'cd "$path" && git remote add origin "$remoteUrl"';
        await _terminal.executeCommand(remoteCmd);
      }
      
      final status = await getRepositoryStatus(path);
      final repo = GitRepository(
        path: path,
        name: path.split('/').last,
        currentBranch: 'main',
        branches: ['main'],
        hasRemote: remoteUrl != null,
        lastCommit: DateTime.now(),
      );
      
      state = state.copyWith(
        repositories: [...state.repositories, repo],
        currentRepository: repo,
      );
      
      await _saveRepos();
      return repo;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
  
  Future<GitRepository?> cloneRepository(String url, String targetPath) async {
    try {
      final cmd = 'git clone "$url" "$targetPath"';
      await _terminal.executeCommand(cmd);
      
      final status = await getRepositoryStatus(targetPath);
      final repo = GitRepository(
        path: targetPath,
        name: targetPath.split('/').last,
        currentBranch: 'main',
        branches: ['main'],
        hasRemote: true,
        lastCommit: DateTime.now(),
      );
      
      state = state.copyWith(
        repositories: [...state.repositories, repo],
        currentRepository: repo,
      );
      
      await _saveRepos();
      return repo;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
  
  Future<GitStatus> getRepositoryStatus(String path) async {
    try {
      final cmd = 'cd "$path" && git status --porcelain';
      final output = await _terminal.executeCommand(cmd);
      
      final modified = <GitFileStatus>[];
      final staged = <GitFileStatus>[];
      final untracked = <GitFileStatus>[];
      final deleted = <GitFileStatus>[];
      
      for (final line in output.split('\n')) {
        if (line.trim().isEmpty) continue;
        
        final indexStatus = line[0];
        final workTreeStatus = line[1];
        final filePath = line.substring(3);
        
        if (indexStatus != ' ' && indexStatus != '?') {
          staged.add(GitFileStatus(
            path: filePath,
            type: _parseFileStatus(indexStatus),
            isStaged: true,
          ));
        }
        
        if (workTreeStatus == '?') {
          untracked.add(GitFileStatus(
            path: filePath,
            type: GitFileStatusType.untracked,
          ));
        } else if (workTreeStatus == 'D') {
          deleted.add(GitFileStatus(
            path: filePath,
            type: GitFileStatusType.deleted,
          ));
        } else if (workTreeStatus == 'M') {
          modified.add(GitFileStatus(
            path: filePath,
            type: GitFileStatusType.modified,
          ));
        }
      }
      
      return GitStatus(
        modified: modified,
        staged: staged,
        untracked: untracked,
        deleted: deleted,
      );
    } catch (e) {
      return const GitStatus();
    }
  }
  
  GitFileStatusType _parseFileStatus(String code) {
    switch (code) {
      case 'A':
        return GitFileStatusType.added;
      case 'D':
        return GitFileStatusType.deleted;
      case 'R':
        return GitFileStatusType.renamed;
      case 'C':
        return GitFileStatusType.copied;
      default:
        return GitFileStatusType.modified;
    }
  }
  
  Future<GitOperation> stageFile(String path, {bool stageAll = false}) async {
    final repo = state.currentRepository;
    if (repo == null) throw Exception('No repository selected');
    
    final cmd = stageAll 
      ? 'cd "${repo.path}" && git add -A'
      : 'cd "${repo.path}" && git add "$path"';
    
    final operation = GitOperation(
      id: const Uuid().v4(),
      type: GitOperationType.add,
      repository: repo.path,
      timestamp: DateTime.now(),
      isRunning: true,
    );
    
    state = state.copyWith(operations: [...state.operations, operation]);
    
    try {
      final output = await _terminal.executeCommand(cmd);
      final updated = operation.copyWith(
        output: output,
        exitCode: 0,
        isRunning: false,
      );
      
      _updateOperation(updated);
      await refreshCurrentRepository();
      
      return updated;
    } catch (e) {
      final updated = operation.copyWith(
        error: e.toString(),
        exitCode: 1,
        isRunning: false,
      );
      _updateOperation(updated);
      return updated;
    }
  }
  
  Future<GitOperation> commit(String message, {String? author}) async {
    final repo = state.currentRepository;
    if (repo == null) throw Exception('No repository selected');
    
    final authorCmd = author != null ? 'GIT_AUTHOR_NAME="$author"' : '';
    final cmd = 'cd "${repo.path}" && git commit -m "$message"';
    
    final operation = GitOperation(
      id: const Uuid().v4(),
      type: GitOperationType.commit,
      repository: repo.path,
      timestamp: DateTime.now(),
      isRunning: true,
    );
    
    state = state.copyWith(operations: [...state.operations, operation]);
    
    try {
      final output = await _terminal.executeCommand(cmd);
      final updated = operation.copyWith(
        output: output,
        exitCode: 0,
        isRunning: false,
      );
      
      _updateOperation(updated);
      await refreshCurrentRepository();
      
      return updated;
    } catch (e) {
      final updated = operation.copyWith(
        error: e.toString(),
        exitCode: 1,
        isRunning: false,
      );
      _updateOperation(updated);
      return updated;
    }
  }
  
  Future<GitOperation> push({String? remote, String? branch}) async {
    final repo = state.currentRepository;
    if (repo == null) throw Exception('No repository selected');
    
    final cmd = 'cd "${repo.path}" && git push ${remote ?? "origin"} ${branch ?? repo.currentBranch}';
    
    final operation = GitOperation(
      id: const Uuid().v4(),
      type: GitOperationType.push,
      repository: repo.path,
      branch: branch ?? repo.currentBranch,
      timestamp: DateTime.now(),
      isRunning: true,
    );
    
    state = state.copyWith(operations: [...state.operations, operation]);
    
    try {
      final output = await _terminal.executeCommand(cmd);
      final updated = operation.copyWith(
        output: output,
        exitCode: 0,
        isRunning: false,
      );
      
      _updateOperation(updated);
      return updated;
    } catch (e) {
      final updated = operation.copyWith(
        error: e.toString(),
        exitCode: 1,
        isRunning: false,
      );
      _updateOperation(updated);
      return updated;
    }
  }
  
  Future<GitOperation> pull({String? remote, String? branch}) async {
    final repo = state.currentRepository;
    if (repo == null) throw Exception('No repository selected');
    
    final cmd = 'cd "${repo.path}" && git pull ${remote ?? "origin"} ${branch ?? repo.currentBranch}';
    
    final operation = GitOperation(
      id: const Uuid().v4(),
      type: GitOperationType.pull,
      repository: repo.path,
      branch: branch ?? repo.currentBranch,
      timestamp: DateTime.now(),
      isRunning: true,
    );
    
    state = state.copyWith(operations: [...state.operations, operation]);
    
    try {
      final output = await _terminal.executeCommand(cmd);
      final updated = operation.copyWith(
        output: output,
        exitCode: 0,
        isRunning: false,
      );
      
      _updateOperation(updated);
      await refreshCurrentRepository();
      
      return updated;
    } catch (e) {
      final updated = operation.copyWith(
        error: e.toString(),
        exitCode: 1,
        isRunning: false,
      );
      _updateOperation(updated);
      return updated;
    }
  }
  
  Future<List<GitBranch>> getBranches(String path) async {
    try {
      final cmd = 'cd "$path" && git branch -a';
      final output = await _terminal.executeCommand(cmd);
      
      final branches = <GitBranch>[];
      for (final line in output.split('\n')) {
        final name = line.trim().replaceAll('* ', '');
        if (name.isEmpty) continue;
        
        branches.add(GitBranch(
          name: name,
          isCurrent: line.contains('*'),
          isRemote: name.startsWith('remotes/'),
        ));
      }
      
      return branches;
    } catch (e) {
      return [];
    }
  }
  
  Future<GitOperation> checkout(String branchName, {bool createNew = false}) async {
    final repo = state.currentRepository;
    if (repo == null) throw Exception('No repository selected');
    
    final flag = createNew ? '-b' : '';
    final cmd = 'cd "${repo.path}" && git checkout $flag "$branchName"';
    
    final operation = GitOperation(
      id: const Uuid().v4(),
      type: GitOperationType.checkout,
      repository: repo.path,
      branch: branchName,
      timestamp: DateTime.now(),
      isRunning: true,
    );
    
    state = state.copyWith(operations: [...state.operations, operation]);
    
    try {
      final output = await _terminal.executeCommand(cmd);
      final updated = operation.copyWith(
        output: output,
        exitCode: 0,
        isRunning: false,
      );
      
      _updateOperation(updated);
      await refreshCurrentRepository();
      
      return updated;
    } catch (e) {
      final updated = operation.copyWith(
        error: e.toString(),
        exitCode: 1,
        isRunning: false,
      );
      _updateOperation(updated);
      return updated;
    }
  }
  
  Future<List<GitCommit>> getCommitHistory(String path, {int limit = 50}) async {
    try {
      final cmd = '''cd "$path" && git log --pretty=format:"%H|%s|%an|%ae|%ai" -n $limit''';
      final output = await _terminal.executeCommand(cmd);
      
      final commits = <GitCommit>[];
      for (final line in output.split('\n')) {
        if (line.trim().isEmpty) continue;
        try {
          commits.add(GitCommit.fromLogLine(line));
        } catch (e) {
          continue;
        }
      }
      
      return commits;
    } catch (e) {
      return [];
    }
  }
  
  Future<String> getDiff(String path, {String? from, String? to, String? file}) async {
    try {
      String cmd = 'cd "$path" && git diff';
      
      if (from != null && to != null) {
        cmd = 'cd "$path" && git diff "$from" "$to"';
      } else if (file != null) {
        cmd = 'cd "$path" && git diff "$file"';
      }
      
      return await _terminal.executeCommand(cmd);
    } catch (e) {
      return '';
    }
  }
  
  Future<List<String>> getRemotes(String path) async {
    try {
      final cmd = 'cd "$path" && git remote -v';
      final output = await _terminal.executeCommand(cmd);
      
      final remotes = <String>{};
      for (final line in output.split('\n')) {
        final parts = line.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          remotes.add(parts[0]);
        }
      }
      
      return remotes.toList();
    } catch (e) {
      return [];
    }
  }
  
  Future<GitOperation> stash({String? message, bool apply = false}) async {
    final repo = state.currentRepository;
    if (repo == null) throw Exception('No repository selected');
    
    final stashCmd = apply ? 'git stash pop' : (message != null ? 'git stash push -m "$message"' : 'git stash');
    
    final operation = GitOperation(
      id: const Uuid().v4(),
      type: GitOperationType.stash,
      repository: repo.path,
      timestamp: DateTime.now(),
      isRunning: true,
    );
    
    state = state.copyWith(operations: [...state.operations, operation]);
    
    try {
      final cmd = 'cd "${repo.path}" && $stashCmd';
      final output = await _terminal.executeCommand(cmd);
      final updated = operation.copyWith(
        output: output,
        exitCode: 0,
        isRunning: false,
      );
      
      _updateOperation(updated);
      return updated;
    } catch (e) {
      final updated = operation.copyWith(
        error: e.toString(),
        exitCode: 1,
        isRunning: false,
      );
      _updateOperation(updated);
      return updated;
    }
  }
  
  void _updateOperation(GitOperation updated) {
    final operations = state.operations.map((op) {
      return op.id == updated.id ? updated : op;
    }).toList();
    
    state = state.copyWith(operations: operations);
  }
  
  void setCurrentRepository(GitRepository repo) {
    state = state.copyWith(currentRepository: repo);
  }
  
  Future<void> refreshCurrentRepository() async {
    if (state.currentRepository == null) return;
    
    try {
      final status = await getRepositoryStatus(state.currentRepository!.path);
      final branches = await getBranches(state.currentRepository!.path);
      final commits = await getCommitHistory(state.currentRepository!.path, limit: 1);
      
      final updated = GitRepository(
        path: state.currentRepository!.path,
        name: state.currentRepository!.name,
        remote: state.currentRepository!.remote,
        currentBranch: branches.firstWhere((b) => b.isCurrent, orElse: () => GitBranch(name: 'main')).name,
        branches: branches.map((b) => b.name).toList(),
        uncommittedChanges: status.modified.length + status.deleted.length,
        stagedChanges: status.staged.length,
        hasRemote: state.currentRepository!.hasRemote,
        lastCommit: commits.isNotEmpty ? commits.first.date : DateTime.now(),
      );
      
      final repos = state.repositories.map((r) {
        return r.path == updated.path ? updated : r;
      }).toList();
      
      state = state.copyWith(
        repositories: repos,
        currentRepository: updated,
      );
    } catch (e) {
      // Ignore refresh errors
    }
  }
  
  void removeRepository(String path) {
    final repos = state.repositories.where((r) => r.path != path).toList();
    state = state.copyWith(
      repositories: repos,
      currentRepository: state.currentRepository?.path == path ? null : state.currentRepository,
    );
    _saveRepos();
  }
}

final gitServiceProvider = StateNotifierProvider<GitService, GitServiceState>((ref) {
  final terminal = TerminalService.instance;
  return GitService(terminal, ref);
});