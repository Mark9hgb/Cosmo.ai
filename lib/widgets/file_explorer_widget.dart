import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/chat_message.dart';
import '../services/terminal_service.dart';
import 'glass_container.dart';

class FileExplorerWidget extends StatefulWidget {
  final TerminalService terminalService;

  const FileExplorerWidget({
    super.key,
    required this.terminalService,
  });

  @override
  State<FileExplorerWidget> createState() => _FileExplorerWidgetState();
}

class _FileExplorerWidgetState extends State<FileExplorerWidget> {
  String _currentPath = '/data/data/com.termux/files/home';
  List<FileItem> _files = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDirectory(_currentPath);
  }

  Future<void> _loadDirectory(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final output = await widget.terminalService.executeCommand(
        'ls -la "$path"',
      );

      final files = _parseLsOutput(output, path);

      setState(() {
        _currentPath = path;
        _files = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<FileItem> _parseLsOutput(String output, String basePath) {
    final files = <FileItem>[];
    final lines = output.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 9) continue;

      final permissions = parts[0];
      final name = parts.sublist(8).join(' ');

      if (name == '.' || name == '..') continue;

      final isDir = permissions.startsWith('d');
      final isExec = permissions.contains('x');

      files.add(FileItem(
        name: name,
        path: '$basePath/$name',
        type: isDir
            ? FileType.directory
            : (isExec ? FileType.executable : FileType.file),
        size: int.tryParse(parts[4]) ?? 0,
        modifiedAt: DateTime.now(),
        isHidden: name.startsWith('.'),
      ));
    }

    files.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.compareTo(b.name);
    });

    return files;
  }

  void _navigateTo(String path) {
    _loadDirectory(path);
  }

  void _goUp() {
    if (_currentPath == '/data/data/com.termux/files/home') return;

    final parent = Directory(_currentPath).parent.path;
    _navigateTo(parent);
  }

  Future<void> _createNewFile() async {
    final name = await _showNameDialog('Create File');
    if (name == null) return;

    final path = '$_currentPath/$name';
    await widget.terminalService.executeCommand('touch "$path"');
    _loadDirectory(_currentPath);
  }

  Future<void> _createNewDirectory() async {
    final name = await _showNameDialog('Create Directory');
    if (name == null) return;

    final path = '$_currentPath/$name';
    await widget.terminalService.executeCommand('mkdir "$path"');
    _loadDirectory(_currentPath);
  }

  Future<void> _deleteFile(FileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete ${file.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final cmd = file.isDirectory ? 'rmdir' : 'rm';
    await widget.terminalService.executeCommand('$cmd "${file.path}"');
    _loadDirectory(_currentPath);
  }

  Future<String?> _showNameDialog(String title) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        _buildBreadcrumb(),
        Expanded(
          child: _error != null
              ? _buildError()
              : _isLoading
                  ? _buildLoading()
                  : _buildFileList(),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: 0,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: _currentPath != '/data/data/com.termux/files/home'
                ? _goUp
                : null,
            tooltip: 'Go up',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDirectory(_currentPath),
            tooltip: 'Refresh',
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.insert_drive_file_outlined),
            onPressed: _createNewFile,
            tooltip: 'New file',
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _createNewDirectory,
            tooltip: 'New directory',
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    final segments = <Widget>[];

    segments.add(
      InkWell(
        onTap: () => _navigateTo('/data/data/com.termux/files/home'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.home, size: 16),
        ),
      ),
    );

    String path = '';
    for (final part in parts) {
      path += '/$part';
      segments.add(const Icon(Icons.chevron_right, size: 16));
      segments.add(
        InkWell(
          onTap: () => _navigateTo(path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(part),
          ),
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: segments),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          Text(_error ?? 'Unknown error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _loadDirectory(_currentPath),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    final visibleFiles =
        _showHidden ? _files : _files.where((f) => !f.isHidden).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: visibleFiles.length,
      itemBuilder: (context, index) {
        final file = visibleFiles[index];

        return ListTile(
          leading: Icon(
            file.isDirectory
                ? Icons.folder
                : file.isExecutable
                    ? Icons.code
                    : Icons.insert_drive_file,
          ),
          title: Text(file.name),
          subtitle: Text(
            file.isDirectory ? 'Directory' : _formatSize(file.size),
          ),
          trailing: PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'open',
                child: Text('Open'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
            onSelected: (value) {
              if (value == 'open') {
                if (file.isDirectory) {
                  _navigateTo(file.path);
                } else {
                  _showFileContent(file);
                }
              } else if (value == 'delete') {
                _deleteFile(file);
              }
            },
          ),
          onTap: () {
            if (file.isDirectory) {
              _navigateTo(file.path);
            } else {
              _showFileContent(file);
            }
          },
        )
            .animate()
            .fadeIn(delay: (index * 30).ms)
            .slideX(begin: -0.05, delay: (index * 30).ms);
      },
    );
  }

  Future<void> _showFileContent(FileItem file) async {
    final output = await widget.terminalService.executeCommand(
      'cat "${file.path}"',
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(file.name),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: SelectableText(output),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _showHidden = false;

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
