# Termux AI Assistant - Setup Guide

A Flutter AI App Builder that uses Nvidia NIM API for intelligence, bridging directly into Termux for command execution.

## Features

### Core Features
- **AI Chat Interface** - Chat with Nvidia NIM-powered AI
- **Live Terminal** - Real-time xterm.dart terminal view
- **File Explorer** - Browse files in Termux home directory
- **Auto Command Execution** - AI commands are automatically executed in Termux

### Enhanced Features

#### Dark Mode
- System, Light, and Dark themes
- 6 accent color options
- Customizable glass opacity
- Smooth theme transitions

#### Git Integration
- Initialize/Clone repositories
- Stage, Commit, Push, Pull operations
- Branch management
- Repository status monitoring
- Operation history

#### Command Memory
- Tracks all executed commands
- Success/error statistics
- Frequently used commands
- Favorite commands
- Searchable history
- Command statistics

#### Multi-Tab Terminal
- Multiple terminal tabs
- Tab management (rename, duplicate, close)
- Tab visibility toggle
- Command execution per tab
- Tab history tracking

#### Import/Export
- Export sessions as ZIP, Markdown, or HTML
- Project directory export/import
- Full backup/restore

#### AI Indicators
- AI thinking indicator
- Typing/streaming text with cursor
- Command execution progress
- Message status tracking

## Prerequisites

1. **Android Device** (Android 7.0+)
2. **Nvidia API Key** - Get from [https://build.nvidia.com](https://build.nvidia.com)
3. **Termux** - From F-Droid (recommended)

## Installation

### Step 1: Install Termux

```bash
# From F-Droid (recommended)
# Download: https://f-droid.org/packages/com.termux/

# Or from Play Store
# Search: "Termux"
```

### Step 2: Configure Termux

```bash
# Open Termux and run:
termux-setup-storage

# Edit properties:
nano ~/.termux/termux.properties

# Add this line:
allow-external-apps = true

# Reload settings:
termux-reload-settings
```

### Step 3: Build the App

```bash
# Clone project
git clone <repo> termux_ai_assistant
cd termux_ai_assistant

# Install dependencies
flutter pub get

# Build debug APK
flutter build apk --debug
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Flutter AI App                     │
│  ┌─────────────────────────────────────────────┐    │
│  │              Nvidia NIM Service              │    │
│  │           (OpenAI-compatible API)           │    │
│  └─────────────────────────────────────────────┘    │
│                        │                             │
│                        ▼                             │
│  ┌─────────────────────────────────────────────┐    │
│  │           AI Brain / Parser                  │    │
│  │    (Detects ```bash code blocks)            │    │
│  └─────────────────────────────────────────────┘    │
│                        │                             │
│                        ▼                             │
│  ┌─────────────────────────────────────────────┐    │
│  │           Terminal Service                   │    │
│  │      (Intent-based communication)            │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

## Tabs Overview

| Tab | Description |
|-----|-------------|
| Chat | AI conversation with auto command execution |
| Terminal | Multi-tab xterm with session management |
| Files | File explorer for Termux directory |
| Git | Git operations and repository management |
| Memory | Command history and statistics |

## Settings

Access settings via the gear icon in the header:

- **Theme Mode**: Light / Dark / System
- **Accent Color**: 6 color options
- **Glass Effect**: Adjustable transparency
- **Command Memory**: View/clear command history

## Suggested Features

### High Priority
- [ ] Voice Input (speech-to-text)
- [ ] Code generation with syntax highlighting
- [ ] Custom keyboard shortcuts
- [ ] SSH/Telnet support
- [ ] Background task notifications

### Medium Priority
- [ ] SFTP file transfer
- [ ] Package manager UI
- [ ] Code diff viewer
- [ ] Terminal color schemes
- [ ] Command templates

### Low Priority
- [ ] Cloud sync (Google Drive)
- [ ] Collaboration features
- [ ] Analytics dashboard
- [ ] Widget support
- [ ] Container support (Docker)

## File Structure

```
lib/
├── main.dart                              # Entry point
├── screens/
│   └── chat_screen.dart                   # Main UI
├── services/
│   ├── terminal_service.dart              # Termux bridge
│   ├── nvidia_nim_service.dart            # NIM API
│   ├── project_service.dart               # Import/Export
│   ├── command_memory_service.dart        # Command tracking
│   └── git_service.dart                   # Git operations
├── models/
│   ├── chat_message.dart                  # Data models
│   └── git_models.dart                    # Git models
├── widgets/
│   ├── glass_container.dart               # Glassmorphism
│   ├── command_block_widget.dart          # Code blocks
│   ├── file_explorer_widget.dart          # File browser
│   ├── typing_indicator.dart              # AI indicators
│   ├── multi_tab_terminal.dart            # Multi-tab terminal
│   └── git_integration_widget.dart       # Git UI
└── utils/
    ├── theme.dart                         # Material 3 theme
    └── theme_provider.dart                # Theme state
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Termux not found | Install from F-Droid |
| Permission denied | Check termux.properties |
| Command timeout | Increase timeout in TerminalService |
| API key invalid | Get fresh key from build.nvidia.com |
| Dark mode not working | Check theme provider state |

## License

MIT License