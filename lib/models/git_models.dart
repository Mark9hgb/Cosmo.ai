import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class GitOperation extends Equatable {
  final String id;
  final GitOperationType type;
  final String repository;
  final String? branch;
  final DateTime timestamp;
  final String? output;
  final int? exitCode;
  final bool isRunning;
  final String? error;
  
  const GitOperation({
    required this.id,
    required this.type,
    required this.repository,
    this.branch,
    required this.timestamp,
    this.output,
    this.exitCode,
    this.isRunning = false,
    this.error,
  });
  
  GitOperation copyWith({
    String? id,
    GitOperationType? type,
    String? repository,
    String? branch,
    DateTime? timestamp,
    String? output,
    int? exitCode,
    bool? isRunning,
    String? error,
  }) {
    return GitOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      repository: repository ?? this.repository,
      branch: branch ?? this.branch,
      timestamp: timestamp ?? this.timestamp,
      output: output ?? this.output,
      exitCode: exitCode ?? this.exitCode,
      isRunning: isRunning ?? this.isRunning,
      error: error ?? this.error,
    );
  }
  
  @override
  List<Object?> get props => [id, type, repository, branch, timestamp, output, exitCode, isRunning, error];
}

enum GitOperationType {
  init,
  clone,
  status,
  add,
  commit,
  push,
  pull,
  checkout,
  branch,
  merge,
  log,
  diff,
  remote,
  fetch,
  stash,
  tag,
  reset,
  revert,
}

extension GitOperationTypeExtension on GitOperationType {
  String get command {
    switch (this) {
      case GitOperationType.init:
        return 'git init';
      case GitOperationType.clone:
        return 'git clone';
      case GitOperationType.status:
        return 'git status';
      case GitOperationType.add:
        return 'git add';
      case GitOperationType.commit:
        return 'git commit';
      case GitOperationType.push:
        return 'git push';
      case GitOperationType.pull:
        return 'git pull';
      case GitOperationType.checkout:
        return 'git checkout';
      case GitOperationType.branch:
        return 'git branch';
      case GitOperationType.merge:
        return 'git merge';
      case GitOperationType.log:
        return 'git log';
      case GitOperationType.diff:
        return 'git diff';
      case GitOperationType.remote:
        return 'git remote';
      case GitOperationType.fetch:
        return 'git fetch';
      case GitOperationType.stash:
        return 'git stash';
      case GitOperationType.tag:
        return 'git tag';
      case GitOperationType.reset:
        return 'git reset';
      case GitOperationType.revert:
        return 'git revert';
    }
  }
  
  String get displayName {
    switch (this) {
      case GitOperationType.init:
        return 'Initialize';
      case GitOperationType.clone:
        return 'Clone';
      case GitOperationType.status:
        return 'Status';
      case GitOperationType.add:
        return 'Stage';
      case GitOperationType.commit:
        return 'Commit';
      case GitOperationType.push:
        return 'Push';
      case GitOperationType.pull:
        return 'Pull';
      case GitOperationType.checkout:
        return 'Checkout';
      case GitOperationType.branch:
        return 'Branch';
      case GitOperationType.merge:
        return 'Merge';
      case GitOperationType.log:
        return 'History';
      case GitOperationType.diff:
        return 'Changes';
      case GitOperationType.remote:
        return 'Remote';
      case GitOperationType.fetch:
        return 'Fetch';
      case GitOperationType.stash:
        return 'Stash';
      case GitOperationType.tag:
        return 'Tag';
      case GitOperationType.reset:
        return 'Reset';
      case GitOperationType.revert:
        return 'Revert';
    }
  }
  
  IconData get icon {
    switch (this) {
      case GitOperationType.init:
        return Icons.create_new_folder;
      case GitOperationType.clone:
        return Icons.download;
      case GitOperationType.status:
        return Icons.info;
      case GitOperationType.add:
        return Icons.add;
      case GitOperationType.commit:
        return Icons.check;
      case GitOperationType.push:
        return Icons.cloud_upload;
      case GitOperationType.pull:
        return Icons.cloud_download;
      case GitOperationType.checkout:
        return Icons.swap_horiz;
      case GitOperationType.branch:
        return Icons.account_tree;
      case GitOperationType.merge:
        return Icons.merge;
      case GitOperationType.log:
        return Icons.history;
      case GitOperationType.diff:
        return Icons.compare;
      case GitOperationType.remote:
        return Icons.cloud;
      case GitOperationType.fetch:
        return Icons.sync;
      case GitOperationType.stash:
        return Icons.archive;
      case GitOperationType.tag:
        return Icons.label;
      case GitOperationType.reset:
        return Icons.restart_alt;
      case GitOperationType.revert:
        return Icons.undo;
    }
  }
}

class GitRepository {
  final String path;
  final String name;
  final String? remote;
  final String currentBranch;
  final List<String> branches;
  final int uncommittedChanges;
  final int stagedChanges;
  final bool hasRemote;
  final DateTime lastCommit;
  
  const GitRepository({
    required this.path,
    required this.name,
    this.remote,
    required this.currentBranch,
    this.branches = const [],
    this.uncommittedChanges = 0,
    this.stagedChanges = 0,
    this.hasRemote = false,
    required this.lastCommit,
  });
  
  bool get isClean => uncommittedChanges == 0 && stagedChanges == 0;
  bool get hasUncommittedChanges => uncommittedChanges > 0 || stagedChanges > 0;
}

class GitCommit {
  final String hash;
  final String shortHash;
  final String message;
  final String author;
  final String authorEmail;
  final DateTime date;
  
  const GitCommit({
    required this.hash,
    required this.shortHash,
    required this.message,
    required this.author,
    required this.authorEmail,
    required this.date,
  });
  
  factory GitCommit.fromLogLine(String line) {
    final parts = line.split('|');
    if (parts.length < 5) {
      throw FormatException('Invalid git log line: $line');
    }
    
    return GitCommit(
      hash: parts[0].trim(),
      shortHash: parts[0].trim().substring(0, 7),
      message: parts[1].trim(),
      author: parts[2].trim(),
      authorEmail: parts[3].trim(),
      date: DateTime.tryParse(parts[4].trim()) ?? DateTime.now(),
    );
  }
}

class GitBranch {
  final String name;
  final bool isCurrent;
  final bool isRemote;
  final String? tracking;
  
  const GitBranch({
    required this.name,
    this.isCurrent = false,
    this.isRemote = false,
    this.tracking,
  });
}

class GitStatus {
  final List<GitFileStatus> modified;
  final List<GitFileStatus> staged;
  final List<GitFileStatus> untracked;
  final List<GitFileStatus> deleted;
  
  const GitStatus({
    this.modified = const [],
    this.staged = const [],
    this.untracked = const [],
    this.deleted = const [],
  });
  
  int get totalChanges => modified.length + staged.length + untracked.length + deleted.length;
  bool get isClean => totalChanges == 0;
}

class GitFileStatus {
  final String path;
  final GitFileStatusType type;
  final bool isStaged;
  
  const GitFileStatus({
    required this.path,
    required this.type,
    this.isStaged = false,
  });
}

enum GitFileStatusType { modified, added, deleted, renamed, copied, untracked }

extension GitFileStatusTypeExtension on GitFileStatusType {
  String get code {
    switch (this) {
      case GitFileStatusType.modified:
        return 'M';
      case GitFileStatusType.added:
        return 'A';
      case GitFileStatusType.deleted:
        return 'D';
      case GitFileStatusType.renamed:
        return 'R';
      case GitFileStatusType.copied:
        return 'C';
      case GitFileStatusType.untracked:
        return '?';
    }
  }
  
  IconData get icon {
    switch (this) {
      case GitFileStatusType.modified:
        return Icons.edit;
      case GitFileStatusType.added:
        return Icons.add_circle;
      case GitFileStatusType.deleted:
        return Icons.remove_circle;
      case GitFileStatusType.renamed:
        return Icons.drive_file_rename_outline;
      case GitFileStatusType.copied:
        return Icons.copy;
      case GitFileStatusType.untracked:
        return Icons.help_outline;
    }
  }
}

class GitDiff {
  final String from;
  final String to;
  final List<GitDiffHunk> hunks;
  
  const GitDiff({
    required this.from,
    required this.to,
    this.hunks = const [],
  });
}

class GitDiffHunk {
  final int oldStart;
  final int oldCount;
  final int newStart;
  final int newCount;
  final List<GitDiffLine> lines;
  
  const GitDiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    this.lines = const [],
  });
}

class GitDiffLine {
  final GitDiffLineType type;
  final String content;
  final int? oldLineNumber;
  final int? newLineNumber;
  
  const GitDiffLine({
    required this.type,
    required this.content,
    this.oldLineNumber,
    this.newLineNumber,
  });
}

enum GitDiffLineType { context, addition, deletion, header }