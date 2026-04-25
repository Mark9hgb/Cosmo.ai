import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../services/terminal_service.dart';
import '../services/command_memory_service.dart';

class TerminalTab extends Equatable {
  final String id;
  final String name;
  final Terminal terminal;
  final String? workingDirectory;
  final bool isActive;
  final DateTime createdAt;
  final int commandCount;
  
  const TerminalTab({
    required this.id,
    required this.name,
    required this.terminal,
    this.workingDirectory,
    this.isActive = false,
    required this.createdAt,
    this.commandCount = 0,
  });
  
  TerminalTab copyWith({
    String? id,
    String? name,
    Terminal? terminal,
    String? workingDirectory,
    bool? isActive,
    DateTime? createdAt,
    int? commandCount,
  }) {
    return TerminalTab(
      id: id ?? this.id,
      name: name ?? this.name,
      terminal: terminal ?? this.terminal,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      commandCount: commandCount ?? this.commandCount,
    );
  }
  
  @override
  List<Object?> get props => [id, name, workingDirectory, isActive, createdAt, commandCount];
}

class TerminalTabState extends Equatable {
  final List<TerminalTab> tabs;
  final String? activeTabId;
  final bool showTabBar;
  final int maxTabs;
  final int totalCommandCount;
  
  const TerminalTabState({
    this.tabs = const [],
    this.activeTabId,
    this.showTabBar = true,
    this.maxTabs = 10,
    this.totalCommandCount = 0,
  });
  
  TerminalTab? get activeTab {
    if (activeTabId == null) return null;
    try {
      return tabs.firstWhere((t) => t.id == activeTabId);
    } catch (e) {
      return tabs.isNotEmpty ? tabs.first : null;
    }
  }
  
  int get tabCount => tabs.length;
  bool get canAddTab => tabs.length < maxTabs;
  
  TerminalTabState copyWith({
    List<TerminalTab>? tabs,
    String? activeTabId,
    bool? showTabBar,
    int? maxTabs,
    int? totalCommandCount,
  }) {
    return TerminalTabState(
      tabs: tabs ?? this.tabs,
      activeTabId: activeTabId ?? this.activeTabId,
      showTabBar: showTabBar ?? this.showTabBar,
      maxTabs: maxTabs ?? this.maxTabs,
      totalCommandCount: totalCommandCount ?? this.totalCommandCount,
    );
  }
  
  @override
  List<Object?> get props => [tabs, activeTabId, showTabBar, maxTabs, totalCommandCount];
}

class TerminalTabController extends StateNotifier<TerminalTabState> {
  final TerminalService _terminalService;
  final Ref _ref;
  
  TerminalTabController(this._terminalService, this._ref) : super(const TerminalTabState()) {
    addTab();
  }
  
  void addTab({String? name, String? workingDirectory}) {
    if (!state.canAddTab) return;
    
    final id = const Uuid().v4();
    final tabName = name ?? 'Terminal ${state.tabCount + 1}';
    
    final terminal = Terminal(
      maxLines: 10000,
    );
    
    final tab = TerminalTab(
      id: id,
      name: tabName,
      terminal: terminal,
      workingDirectory: workingDirectory,
      createdAt: DateTime.now(),
      isActive: true,
    );
    
    final updatedTabs = state.tabs.map((t) => t.copyWith(isActive: false)).toList();
    updatedTabs.add(tab);
    
    state = state.copyWith(
      tabs: updatedTabs,
      activeTabId: id,
    );
  }
  
  void closeTab(String id) {
    if (state.tabCount <= 1) return;
    
    final tabs = state.tabs.where((t) => t.id != id).toList();
    String? newActiveId = state.activeTabId;
    
    if (state.activeTabId == id) {
      final closedIndex = state.tabs.indexWhere((t) => t.id == id);
      newActiveId = tabs[closedIndex > 0 ? closedIndex - 1 : 0].id;
    }
    
    state = state.copyWith(
      tabs: tabs,
      activeTabId: newActiveId,
    );
  }
  
  void setActiveTab(String id) {
    final tabs = state.tabs.map((t) {
      return t.copyWith(isActive: t.id == id);
    }).toList();
    
    state = state.copyWith(
      tabs: tabs,
      activeTabId: id,
    );
  }
  
  void renameTab(String id, String name) {
    final tabs = state.tabs.map((t) {
      return t.id == id ? t.copyWith(name: name) : t;
    }).toList();
    
    state = state.copyWith(tabs: tabs);
  }
  
  void setWorkingDirectory(String id, String path) {
    final tabs = state.tabs.map((t) {
      return t.id == id ? t.copyWith(workingDirectory: path) : t;
    }).toList();
    
    state = state.copyWith(tabs: tabs);
  }
  
  Future<void> executeInTab(String tabId, String command) async {
    final tab = state.tabs.firstWhere((t) => t.id == tabId);
    tab.terminal.write('\r\n\$ $command\r\n');
    
    final startTime = DateTime.now();
    
    try {
      final output = await _terminalService.executeCommand(
        command,
        workdir: tab.workingDirectory,
      );
      
      tab.terminal.write(output.isEmpty ? '(no output)\r\n' : '$output\r\n');
      
      final duration = DateTime.now().difference(startTime);
      
      _ref.read(commandMemoryProvider.notifier).addCommand(
        command: command,
        output: output,
        exitCode: 0,
        duration: duration,
        workingDirectory: tab.workingDirectory,
      );
      
      _incrementCommandCount(tabId);
    } catch (e) {
      tab.terminal.write('[Error: $e]\r\n');
      
      _ref.read(commandMemoryProvider.notifier).addCommand(
        command: command,
        output: e.toString(),
        exitCode: 1,
        duration: DateTime.now().difference(startTime),
        workingDirectory: tab.workingDirectory,
      );
      
      _incrementCommandCount(tabId);
    }
  }
  
  void _incrementCommandCount(String tabId) {
    final tabs = state.tabs.map((t) {
      return t.id == tabId ? t.copyWith(commandCount: t.commandCount + 1) : t;
    }).toList();
    
    state = state.copyWith(
      tabs: tabs,
      totalCommandCount: state.totalCommandCount + 1,
    );
  }
  
  void clearTab(String tabId) {
    final tabs = state.tabs.map((t) {
      if (t.id == tabId) {
        final newTerminal = Terminal(maxLines: 10000);
        newTerminal.write('Terminal cleared\r\n');
        return t.copyWith(terminal: newTerminal);
      }
      return t;
    }).toList();
    
    state = state.copyWith(tabs: tabs);
  }
  
  void clearAllTabs() {
    final tabs = state.tabs.map((t) {
      final newTerminal = Terminal(maxLines: 10000);
      newTerminal.write('Terminal cleared\r\n');
      return t.copyWith(terminal: newTerminal);
    }).toList();
    
    state = state.copyWith(tabs: tabs);
  }
  
  void duplicateTab(String id) {
    if (!state.canAddTab) return;
    
    final source = state.tabs.firstWhere((t) => t.id == id);
    addTab(
      name: '${source.name} (copy)',
      workingDirectory: source.workingDirectory,
    );
    
    final newTab = state.activeTab;
    if (newTab != null) {
      for (final line in source.terminal.buffer.lines) {
        newTab.terminal.write(line);
      }
    }
  }
  
  void toggleTabBar() {
    state = state.copyWith(showTabBar: !state.showTabBar);
  }
  
  void reorderTabs(int oldIndex, int newIndex) {
    final tabs = [...state.tabs];
    final tab = tabs.removeAt(oldIndex);
    tabs.insert(newIndex, tab);
    
    state = state.copyWith(tabs: tabs);
  }
}

final terminalTabControllerProvider = StateNotifierProvider<TerminalTabController, TerminalTabState>((ref) {
  final terminal = TerminalService.instance;
  return TerminalTabController(terminal, ref);
});

class MultiTabTerminal extends ConsumerWidget {
  final bool embedded;
  final Function(TerminalTab)? onTabChanged;
  final Function(String)? onCommandExecuted;
  
  const MultiTabTerminal({
    super.key,
    this.embedded = true,
    this.onTabChanged,
    this.onCommandExecuted,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(terminalTabControllerProvider);
    final controller = ref.read(terminalTabControllerProvider.notifier);
    final theme = Theme.of(context);
    
    if (!state.showTabBar) {
      return _buildTerminalView(context, state, controller);
    }
    
    return Column(
      children: [
        _buildTabBar(context, state, controller),
        Expanded(
          child: _buildTerminalView(context, state, controller),
        ),
      ],
    );
  }
  
  Widget _buildTabBar(BuildContext context, TerminalTabState state, TerminalTabController controller) {
    final theme = Theme.of(context);
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.tabs.length,
              itemBuilder: (context, index) {
                final tab = state.tabs[index];
                final isActive = tab.id == state.activeTabId;
                
                return GestureDetector(
                  onTap: () {
                    controller.setActiveTab(tab.id);
                    onTabChanged?.call(tab);
                  },
                  onLongPress: () => _showTabOptions(context, tab, controller),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isActive 
                        ? theme.colorScheme.surface
                        : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: isActive 
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.terminal,
                          size: 14,
                          color: isActive 
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tab.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isActive 
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (state.tabCount > 1) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => controller.closeTab(tab.id),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (state.canAddTab)
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => controller.addTab(),
              tooltip: 'New Tab',
              visualDensity: VisualDensity.compact,
            ),
          IconButton(
            icon: const Icon(Icons.drag_handle, size: 18),
            onPressed: () => controller.toggleTabBar(),
            tooltip: 'Hide Tabs',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTerminalView(BuildContext context, TerminalTabState state, TerminalTabController controller) {
    final activeTab = state.activeTab;
    
    if (activeTab == null) {
      return const Center(
        child: Text('No active terminal'),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TerminalView(
            activeTab.terminal,
            autofocus: true,
            backgroundOpacity: 1,
            theme: TerminalThemes.oneDark,
            textStyle: const TerminalStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 13,
            ),
            onSecondaryTapDown: (details, offset) {
              _showTerminalContextMenu(context, details.globalPosition, activeTab, controller);
            },
          ),
        ),
      ),
    );
  }
  
  void _showTabOptions(BuildContext context, TerminalTab tab, TerminalTabController controller) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, tab, controller);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(context);
                controller.duplicateTab(tab.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Clear'),
              onTap: () {
                Navigator.pop(context);
                controller.clearTab(tab.id);
              },
            ),
            if (state.tabCount > 1)
              ListTile(
                leading: const Icon(Icons.close, color: Colors.red),
                title: const Text('Close', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  controller.closeTab(tab.id);
                },
              ),
          ],
        ),
      ),
    );
  }
  
  void _showRenameDialog(BuildContext context, TerminalTab tab, TerminalTabController controller) {
    final textController = TextEditingController(text: tab.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Tab'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Tab Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.renameTab(tab.id, textController.text);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
  
  void _showTerminalContextMenu(
    BuildContext context,
    Offset position,
    TerminalTab tab,
    TerminalTabController controller,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.clear),
            title: Text('Clear'),
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () => controller.clearTab(tab.id),
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.copy),
            title: Text('Copy All'),
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            // Copy all terminal output
          },
        ),
        PopupMenuItem(
          child: const ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            // Show terminal settings
          },
        ),
      ],
    );
  }
}