import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';

class ProjectService {
  static const String _sessionsKey = 'chat_sessions';
  static const String _projectsKey = 'projects';
  static const String _exportPrefix = 'termux_ai_export_';
  
  static ProjectService? _instance;
  static ProjectService get instance => _instance ??= ProjectService._();
  
  ProjectService._();
  
  SharedPreferences? _prefs;
  
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  Future<List<ChatSession>> getSessions() async {
    final sessionsJson = _prefs?.getString(_sessionsKey);
    if (sessionsJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(sessionsJson);
    return decoded.map((e) => ChatSession.fromJson(e)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  
  Future<void> saveSessions(List<ChatSession> sessions) async {
    final json = jsonEncode(sessions.map((e) => e.toJson()).toList());
    await _prefs?.setString(_sessionsKey, json);
  }
  
  Future<ChatSession> createSession({String? name}) async {
    final sessions = await getSessions();
    final now = DateTime.now();
    
    final session = ChatSession(
      id: const Uuid().v4(),
      name: name ?? 'Chat ${sessions.length + 1}',
      createdAt: now,
      updatedAt: now,
      messages: [],
    );
    
    sessions.insert(0, session);
    await saveSessions(sessions);
    
    return session;
  }
  
  Future<void> updateSession(ChatSession session) async {
    final sessions = await getSessions();
    final index = sessions.indexWhere((s) => s.id == session.id);
    
    if (index >= 0) {
      sessions[index] = session.copyWith(updatedAt: DateTime.now());
      await saveSessions(sessions);
    }
  }
  
  Future<void> deleteSession(String sessionId) async {
    final sessions = await getSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await saveSessions(sessions);
  }
  
  Future<String> exportSession(ChatSession session) async {
    final archive = Archive();
    
    final sessionJson = jsonEncode(session.toJson());
    archive.addFile(ArchiveFile(
      'session.json',
      sessionJson.length,
      utf8.encode(sessionJson),
    ));
    
    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);
    
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${_exportPrefix}${session.name.replaceAll(' ', '_')}_$timestamp.zip';
    final exportPath = '${tempDir.path}/$fileName';
    
    final file = File(exportPath);
    await file.writeAsBytes(zipData!);
    
    return exportPath;
  }
  
  Future<ChatSession?> importSession(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final sessionFile = archive.findFile('session.json');
      if (sessionFile == null) {
        throw Exception('Invalid export file: session.json not found');
      }
      
      final sessionJson = utf8.decode(sessionFile.content as List<int>);
      final sessionData = jsonDecode(sessionJson);
      
      final importedSession = ChatSession.fromJson(sessionData);
      
      final newSession = importedSession.copyWith(
        id: const Uuid().v4(),
        name: '${importedSession.name} (imported)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final sessions = await getSessions();
      sessions.insert(0, newSession);
      await saveSessions(sessions);
      
      return newSession;
    } catch (e) {
      rethrow;
    }
  }
  
  Future<List<Project>> getProjects() async {
    final projectsJson = _prefs?.getString(_projectsKey);
    if (projectsJson == null) return [];
    
    final List<dynamic> decoded = jsonDecode(projectsJson);
    return decoded.map((e) => Project.fromJson(e)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  
  Future<void> saveProjects(List<Project> projects) async {
    final json = jsonEncode(projects.map((e) => e.toJson()).toList());
    await _prefs?.setString(_projectsKey, json);
  }
  
  Future<Project> createProject({
    required String name,
    required String rootPath,
    String description = '',
  }) async {
    final projects = await getProjects();
    final now = DateTime.now();
    
    final project = Project(
      id: const Uuid().v4(),
      name: name,
      description: description,
      rootPath: rootPath,
      createdAt: now,
      updatedAt: now,
    );
    
    projects.insert(0, project);
    await saveProjects(projects);
    
    return project;
  }
  
  Future<String> exportProject(Project project) async {
    final archive = Archive();
    
    for (final filePath in project.filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final relativePath = filePath.replaceFirst('${project.rootPath}/', '');
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        }
      } catch (e) {
        continue;
      }
    }
    
    final projectJson = jsonEncode(project.toJson());
    archive.addFile(ArchiveFile(
      'project.json',
      projectJson.length,
      utf8.encode(projectJson),
    ));
    
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = '${_exportPrefix}${project.name.replaceAll(' ', '_')}_$timestamp.zip';
    final exportPath = '${tempDir.path}/$fileName';
    
    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive);
    
    final file = File(exportPath);
    await file.writeAsBytes(zipData!);
    
    return exportPath;
  }
  
  Future<Project?> importProject(String filePath, String targetDirectory) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      final archive = ZipDecoder().decodeBytes(bytes);
      
      final projectFile = archive.findFile('project.json');
      if (projectFile == null) {
        throw Exception('Invalid project file: project.json not found');
      }
      
      final projectJson = utf8.decode(projectFile.content as List<int>);
      final projectData = jsonDecode(projectJson);
      final importedProject = Project.fromJson(projectData);
      
      for (final archiveFile in archive) {
        if (archiveFile.name == 'project.json') continue;
        
        final filePath = '$targetDirectory/${archiveFile.name}';
        final outputFile = File(filePath);
        
        await outputFile.parent.create(recursive: true);
        await outputFile.writeAsBytes(archiveFile.content as List<int>);
      }
      
      final newProject = importedProject.copyWith(
        id: const Uuid().v4(),
        name: '${importedProject.name} (imported)',
        rootPath: targetDirectory,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final projects = await getProjects();
      projects.insert(0, newProject);
      await saveProjects(projects);
      
      return newProject;
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> deleteProject(String projectId) async {
    final projects = await getProjects();
    projects.removeWhere((p) => p.id == projectId);
    await saveProjects(projects);
  }
  
  Future<List<String>> scanDirectory(String path) async {
    final file = File(path);
    if (await file.exists()) return [path];
    
    final directory = Directory(path);
    if (!await directory.exists()) return [];
    
    final files = <String>[];
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        files.add(entity.path);
      }
    }
    
    return files;
  }
  
  Future<String> backupAllData() async {
    final sessions = await getSessions();
    final projects = await getProjects();
    
    final backupData = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'sessions': sessions.map((e) => e.toJson()).toList(),
      'projects': projects.map((e) => e.toJson()).toList(),
    };
    
    final archive = Archive();
    final jsonStr = jsonEncode(backupData);
    archive.addFile(ArchiveFile('backup.json', jsonStr.length, utf8.encode(jsonStr)));
    
    final encoder = ZipEncoder();
    final zipData = encoder.encode(archive)!;
    
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupPath = '${tempDir.path}/termux_ai_backup_$timestamp.zip';
    
    await File(backupPath).writeAsBytes(zipData);
    return backupPath;
  }
  
  Future<void> restoreFromBackup(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    
    final archive = ZipDecoder().decodeBytes(bytes);
    final backupFile = archive.findFile('backup.json');
    
    if (backupFile == null) {
      throw Exception('Invalid backup file');
    }
    
    final backupJson = utf8.decode(backupFile.content as List<int>);
    final backupData = jsonDecode(backupJson);
    
    if (backupData['sessions'] != null) {
      final sessions = (backupData['sessions'] as List)
          .map((e) => ChatSession.fromJson(e))
          .toList();
      await saveSessions(sessions);
    }
    
    if (backupData['projects'] != null) {
      final projects = (backupData['projects'] as List)
          .map((e) => Project.fromJson(e))
          .toList();
      await saveProjects(projects);
    }
  }
}

enum ExportFormat { json, markdown, html, zip }

class ExportService {
  static String toMarkdown(ChatSession session) {
    final buffer = StringBuffer();
    
    buffer.writeln('# ${session.name}');
    buffer.writeln();
    buffer.writeln('*Created: ${session.createdAt.toIso8601String()}*');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    
    for (final message in session.messages) {
      final role = message.role == UserRole.user ? '**User**' : '**Assistant**';
      buffer.writeln('## $role');
      buffer.writeln();
      buffer.writeln(message.content);
      buffer.writeln();
      
      if (message.commandBlocks != null) {
        for (final cmd in message.commandBlocks!) {
          buffer.writeln('```bash');
          buffer.writeln(cmd.command);
          buffer.writeln('```');
          if (cmd.result != null) {
            buffer.writeln();
            buffer.writeln('Output:');
            buffer.writeln('```');
            buffer.writeln(cmd.result!.output);
            buffer.writeln('```');
          }
        }
      }
      buffer.writeln('---');
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  static String toHtml(ChatSession session) {
    final buffer = StringBuffer();
    
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html><head><meta charset="UTF-8">');
    buffer.writeln('<title>${session.name}</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: system-ui; max-width: 800px; margin: 0 auto; padding: 20px; }');
    buffer.writeln('.message { margin: 20px 0; }');
    buffer.writeln('.user { background: #e3f2fd; padding: 15px; border-radius: 10px; }');
    buffer.writeln('.assistant { background: #f5f5f5; padding: 15px; border-radius: 10px; }');
    buffer.writeln('pre { background: #263238; color: #aed581; padding: 15px; border-radius: 5px; overflow-x: auto; }');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<h1>${session.name}</h1>');
    buffer.writeln('<p><em>Created: ${session.createdAt.toIso8601String()}</em></p>');
    
    for (final message in session.messages) {
      final roleClass = message.role == UserRole.user ? 'user' : 'assistant';
      final roleLabel = message.role == UserRole.user ? 'User' : 'Assistant';
      
      buffer.writeln('<div class="message $roleClass">');
      buffer.writeln('<strong>$roleLabel:</strong>');
      buffer.writeln('<p>${_escapeHtml(message.content)}</p>');
      
      if (message.commandBlocks != null) {
        for (final cmd in message.commandBlocks!) {
          buffer.writeln('<pre><code>${_escapeHtml(cmd.command)}</code></pre>');
          if (cmd.result != null) {
            buffer.writeln('<p><em>Output:</em></p>');
            buffer.writeln('<pre><code>${_escapeHtml(cmd.result!.output)}</code></pre>');
          }
        }
      }
      
      buffer.writeln('</div>');
    }
    
    buffer.writeln('</body></html>');
    return buffer.toString();
  }
  
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}