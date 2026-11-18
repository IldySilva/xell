# Xell — Product Specification (MVP)

## 1. Vision

Xell is an open-source SSH workspace focused on:

- Minimalism
- Native platform experience
- Fast workflows
- Local-first architecture
- Beautiful terminal UX
- Deep integration with macOS, Linux, iOS, and Android

The goal is to become the most developer-friendly SSH workspace for engineers who care about speed, simplicity, and control — whether they are at their desk or on the move.

Xell should feel:
- fast
- calm
- powerful
- native
- trustworthy

---

# 2. Product Philosophy

## 2.1 Local First

Xell must work fully offline.

No account should be required for:
- SSH connections
- Host management
- Key management
- Terminal sessions

Cloud functionality is optional and future-facing.

---

## 2.2 Native Experience First

Xell must not feel like:
- Electron bloat
- a wrapped website
- a generic cross-platform UI

It should feel deeply integrated with each platform:
- macOS — respects system conventions, Keychain, and native window behavior
- Linux — respects desktop environment norms and Secret Service
- iOS — adapts to touch-first interaction, respects Human Interface Guidelines
- Android — adapts to Material conventions and Android lifecycle

---

## 2.3 Keyboard-Driven UX

The product should optimize for:
- speed
- shortcuts
- command palettes
- fast navigation
- power users

Mouse usage should be optional for advanced workflows.

---

## 2.4 Beautiful Minimalism

The UI should:
- avoid clutter
- prioritize whitespace
- emphasize typography
- reduce visual noise
- feel calm under pressure

Inspired by:
- Linear
- Raycast
- Ghostty
- Warp
- VSCode
- Apple Human Interface Guidelines

---

# 3. Target Users

## Primary Users

- Backend engineers
- DevOps engineers
- Platform engineers
- SREs
- Open-source developers
- Linux/macOS power users
- On-call engineers needing mobile access

## Secondary Users

- Students learning Linux
- Developers managing VPSs
- Small infrastructure teams
- Developers who work across desktop and mobile

---

# 4. MVP Scope

The MVP focuses on:

- SSH connectivity
- Terminal experience
- Host management
- Secure local storage
- Native desktop workflows

Excluded from MVP:
- cloud sync
- collaboration
- AI features
- Kubernetes integrations

---

# 5. Core Features

# 5.1 Host Management

## Description

Users can organize and manage SSH hosts visually.

## Functional Requirements

### Create Host

User can define:
- host name
- hostname/IP
- port
- username
- authentication type
- tags
- notes

### Authentication Methods

Support:
- Password authentication
- Private key authentication
- SSH agent authentication

### Host Organization

Support:
- folders/projects
- tags
- environments

Examples:
- Production
- Staging
- Personal
- Clients

### Search

Instant host search by:
- name
- tag
- hostname

### Favorites

Mark hosts as favorites.

### Recent Connections

Track recently accessed hosts.

---

# 5.2 SSH Terminal

## Description

Integrated terminal for remote sessions.

## Functional Requirements

### Terminal Capabilities

Support:
- ANSI colors
- UTF-8
- resizing
- copy/paste/select-all (platform-native shortcuts: ⌘C/V/A on macOS, Ctrl+C/V/A on Linux)
- keyboard shortcuts

### Session Management

Support:
- tabs (with + button to open new connection directly from tab bar)
- split panes (horizontal and vertical)
- detached windows

### Connection Recovery

Optional reconnect on dropped sessions.

### Metadata

Display:
- host name
- active status
- latency

---

# 5.3 SSH Config Import

## Description

Automatically import existing SSH configurations.

## Functional Requirements

### Import Source

Support:
- `~/.ssh/config`

### Parsed Fields

Support:
- Host
- HostName
- User
- Port
- IdentityFile

### Sync Strategy

Manual refresh in MVP.

---

# 5.4 Secure Credential Storage

## Description

Sensitive information must be encrypted securely.

## Functional Requirements

### macOS

Use:
- Apple Keychain

### Linux

Use:
- Secret Service API
- KWallet support if possible

### Encrypted Data

Encrypt:
- passwords
- tokens
- private keys

### Security Principle

Private keys must never leave the local machine.

---

# 5.5 Command Palette

## Description

Central keyboard-driven interaction layer.

## Functional Requirements

### Actions

User can:
- search hosts
- connect to hosts
- create hosts
- open recent sessions
- execute snippets

### Shortcuts

Default:
- macOS → `CMD + K`
- Linux → `CTRL + K`
- iOS/Android → floating action button or toolbar tap

---

# 5.6 Command Snippets

## Description

Reusable command library for frequently-used shell commands.

## Functional Requirements

### Features

User can:
- save snippets with title, command, optional description, and tags
- search snippets by title, command, or tag
- run snippets directly into the active SSH terminal session
- copy snippet commands to clipboard
- edit and delete snippets

### Storage

- Persisted locally with SharedPreferences (JSON)
- No cloud sync required

### Variable Support (post-MVP)

Examples:
- `${host}`
- `${user}`

---

# 5.7 Port Forwarding

---

# 5.7 Port Forwarding

## Description

Visual SSH tunnel manager.

## Functional Requirements

### Supported Tunnels

Support:
- local forwarding

### Tunnel Controls

User can:
- create tunnels
- enable/disable tunnels
- inspect active tunnels

---

# 5.8 SFTP File Browser

## Description

Simple remote file explorer with inline editing.

## Functional Requirements

### Operations

Support:
- browse
- upload
- download
- rename
- delete
- edit (opens Remote File Editor overlay)

### Exclusions

MVP excludes:
- file syncing
- diff comparison
- advanced sync strategies

---

# 5.9 Process Monitor

## Description

Live system resource dashboard for the active SSH session.

## Functional Requirements

### System Stats

Display:
- CPU usage percentage with colour-coded progress bar
- Memory used / total (MB) with percentage
- Disk usage per mounted filesystem

### Process List

Display:
- PID, CPU%, MEM%, command name per process
- Sorted by CPU% descending
- Filterable by command, user, or PID
- Auto-refresh every 5 seconds while session is connected

### Colour Coding

- CPU ≥ 50% → red
- CPU ≥ 20% → amber
- Disk ≥ 90% → red
- Disk ≥ 70% → amber

### Data Source

Runs `ps aux`, `free -m`, `df -h` over SSH using `SSHClient.execute`.

---

# 5.10 Remote File Editor

## Description

Lightweight in-app text editor for remote files accessed over SFTP.

## Functional Requirements

### Editing

- Opens a file by reading it fully into memory over SFTP
- Presents a monospace text editor within the app
- Saves changes back to the remote file using SFTP write/truncate

### UX

- Dirty-state indicator (● dot in title bar when unsaved changes exist)
- ⌘S / Ctrl+S to save
- Discard confirmation dialog on close with unsaved changes
- Save success snackbar confirmation

### Integration

- Accessible via "Edit" action on any file in the SFTP browser
- Opens as a dialog on desktop; as a full page on mobile

### Exclusions

MVP excludes:
- syntax highlighting
- multiple open files
- diff/merge views

---

# 6. Non-Functional Requirements

# 6.1 Performance

## Startup Time

Target:
- under 2 seconds

## Memory Usage

Idle target:
- under 250MB

## Responsiveness

Terminal interaction must feel instant.

---

# 6.2 Reliability

Xell should:
- recover gracefully
- avoid crashes
- reconnect safely
- preserve session state when possible

---

# 6.3 Security

## Requirements

- encrypted local storage
- no plaintext credentials
- no telemetry by default
- no mandatory cloud dependency

---

# 6.4 Accessibility

Support:
- keyboard navigation
- scalable UI
- readable contrast

---

# 7. Technical Architecture

# 7.1 Frontend

## Stack

- Flutter (Desktop + Mobile)
- Dart

## Supported Platforms

MVP:
- macOS
- Linux
- iOS
- Android

Post-MVP:
- Windows

Dependency follow-ups:
- Upgrade `flutter_secure_storage` 10 → 11 one release after v0.2.0 ships. v11 deletes support for the v9 Android ciphers, so users must run a v10 build once to migrate their stored credentials first.
- Upgrade `desktop_drop` to 0.9 once `file_picker` accepts `cross_file` 0.4.
- Optional per-host "Allow legacy algorithms" setting for servers that only offer SHA-1 / `ssh-rsa` / CBC (dartssh2 4 disables them by default).

---

# 7.2 SSH Engine

## Library

- `dartssh2`

Responsibilities:
- SSH
- SFTP
- tunneling

---

# 7.3 Terminal Engine

## Library

- `xterm.dart`

Responsibilities:
- terminal rendering
- ANSI support
- keyboard processing

---

# 7.4 Local Database

## Recommendation

SQLite + Drift

Reason:
- mature
- stable
- reliable
- portable

---

# 7.5 State Management

## Recommendation

Riverpod

---

# 7.6 Native Integrations

## macOS

Use:
- Flutter `PlatformMenuBar` for native menu bar

Integrations:
- Keychain (via flutter_secure_storage)
- Native menu bar: File (New Connection, Close Tab, Settings), Window (Toggle Full Screen), Help (Check for Updates, View on GitHub, What's New, Report a Bug)
- Platform-aware keyboard shortcuts (⌘K, ⌘N, ⌘W, ⌘,, ⌘D, ⌘⌃F)

## Linux

Use:
- Flutter `PlatformMenuBar` for native embedded menu bar
- Secret Service APIs (via flutter_secure_storage)

Integrations:
- Native menu bar (same structure as macOS, Ctrl-based shortcuts)

## iOS

Use:
- Flutter platform channels where needed

Integrations:
- Keychain (via flutter_secure_storage)
- Face ID / Touch ID (biometric unlock, post-MVP)
- Background connection handling (foreground-only in MVP due to iOS limitations)

Mobile UX:
- bottom navigation bar instead of sidebar
- touch-optimized host list and terminal controls
- soft keyboard awareness in terminal view

## Android

Use:
- Android Keystore (via flutter_secure_storage)

Integrations:
- Biometric auth (post-MVP)
- Foreground service for background sessions (post-MVP)

Mobile UX:
- bottom navigation bar instead of sidebar
- Material-style navigation
- soft keyboard awareness in terminal view

---

# 8. Design System

# 8.1 Visual Identity

## Style

- Swiss-inspired
- typography-first
- terminal-native

## UX Characteristics

- whitespace-heavy
- clean hierarchy
- subtle animations
- low visual noise

---

# 8.2 Color System

## Base

Dark-first interface.

## Accent

Single configurable accent color.

Examples:
- blue
- orange
- green

---

# 8.3 Typography

## Fonts

Recommended:
- Inter
- JetBrains Mono
- Geist Mono

---

# 9. MVP Milestones

# Milestone 1 — Foundation

- desktop shell
- navigation
- theming
- window management

---

# Milestone 2 — SSH Core

- SSH connectivity
- terminal rendering
- session lifecycle

---

# Milestone 3 — Host Management

- CRUD hosts
- search
- tagging
- favorites

---

# Milestone 4 — Security

- encrypted storage
- Keychain integration
- Secret Service integration

---

# Milestone 5 — Productivity

- command palette
- snippets
- recent sessions

---

# Milestone 6 — Networking

- port forwarding
- tunnel manager

---

# Milestone 7 — File Transfer

- SFTP browser
- uploads/downloads

---

# 10. Future Roadmap

## Collaboration

- encrypted sync
- team workspaces

## Infrastructure

- Docker container management
- Kubernetes cluster access

## AI

- command explanations
- diagnostics
- infrastructure insights
- AI-assisted terminal workflows

## DevOps Tools (post-MVP expansion)

- Log streaming and filtering
- Scheduled command runner
- Multi-host command broadcast

## Plugins

- themes
- integrations
- extensions

## Advanced Terminal

- GPU rendering
- advanced pane orchestration

---

# 11. Competitive Positioning

| Product | Weakness |
|---|---|
| Termius | closed source |
| Warp | web-heavy UX |
| Electerm | cluttered UX |
| PuTTY | outdated UX |
| Tabby | inconsistent design quality |

---

# 12. Success Criteria

Xell succeeds if users:
- prefer it over raw terminal workflows
- trust its security model
- enjoy daily usage
- manage infrastructure faster
- feel productive inside the application

---

# 13. Open Source Strategy

## License

Recommended:
- Apache 2.0
or
- MIT

## Goals

- community trust
- plugin ecosystem
- transparency
- contributor friendliness

---

# 14. Engineering Philosophy

Xell should feel like:

> “A modern SSH workspace designed by developers who deeply care about developer experience, performance, and native platform quality — on every device.”